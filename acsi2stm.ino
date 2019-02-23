#include <libmaple/libmaple_types.h>
#include <libmaple/util.h>
#include <libmaple/rcc.h>
#include <libmaple/iwdg.h>
#include <boards.h>
#include <wirish.h>
#include <inttypes.h>

#include <SPI.h>
#include "Sd2CardX.h"

#define AHDI_DEBUG 0
#define LED PC13
#define SD_CS PA4
#define MAXBUF 16
#define BLOCKSIZE 512
#define ACSI_ID 0

#define MAXTRIES_SD 5
#define WATCHDOG_MILLIS 800

#define CS PB7
#define IRQ PA12
#define ACK PA8
#define A1 PB6
#define DRQ PA11

#define CS_MASK 0b10000000
#define A1_MASK 0b1000000
#define ACK_MASK 0b100000000
#define DRQ_MASK 0b100000000000

Sd2Card card;

// Structure provided by the Hatari source code
static unsigned char inquiry_data[] =
{
  0,                /* device type 0 = direct access device */
  0,                /* device type qualifier (nonremovable) */
  1,                /* ACSI/SCSI version */
  0,                /* reserved */
  31,               /* length of the following data */
  0, 0, 0,          /* Vendor specific data */
  'R','e','t','r','o','1','6',' ',    /* Vendor ID */
  'S','T','M','3','2',' ','S','D',    /* Product ID 1 */
  ' ','b','r','i','d','g','e',' ',    /* Product ID 2 */
  'v','1','.','0',                    /* Revision */
};

#if AHDI_DEBUG
template<typename T>
inline void ahdiDbg(T txt) {
  Serial.flush();
  Serial.print(txt);
  Serial.flush();
}
template<typename T, typename F>
inline void ahdiDbg(T txt, F fmt) {
  Serial.flush();
  Serial.print(txt, fmt);
  Serial.flush();
}
template<typename T>
inline void ahdiDbgln(T txt) {
  Serial.flush();
  Serial.println(txt);
  Serial.flush();
}
template<typename T, typename F>
inline void ahdiDbgln(T txt, F fmt) {
  Serial.flush();
  Serial.println(txt, fmt);
  Serial.flush();
}
#else
template<typename T>
inline void ahdiDbg(T txt) {
}
template<typename T, typename F>
inline void ahdiDbg(T txt, F fmt) {
}
template<typename T>
inline void ahdiDbgln(T txt) {
}
template<typename T, typename F>
inline void ahdiDbgln(T txt, F fmt) {
}
#endif

#ifdef LED
static inline void ledOn() {
  digitalWrite(LED, 1);
  pinMode(LED, OUTPUT);
}
static inline void ledOff() {
  pinMode(LED, INPUT);
}
static inline void ledSet(int l) {
  digitalWrite(LED, l);
  pinMode(LED, OUTPUT);
}
#else
static inline void ledOn() {
}
static inline void ledOff() {
}
static inline void ledSet(int l) {
}
#endif

// Call on failure. Displays a blinking pattern on the LED.
static inline void failure(uint8_t blinkPattern) {
#ifdef LED
  pinMode(LED, OUTPUT);
#endif
  for(;;) {
    blinkPattern = (blinkPattern >> 7) | (blinkPattern << 1); // Rotate pattern to the left
    ledSet(blinkPattern & 1); // Display one bit on the LED
    delay(125); // Wait for next bit to display
  }
}

static int curDevice;
static uint8_t cmdBuf[6];
static int cmdBufCnt;

static inline void releaseRq() {
  GPIOA->regs->CRH = (GPIOA->regs->CRH & 0xFFF00FFF) | 0x00044000; // Set PORTB[0:7] to input
}

static inline void releaseData() {
  GPIOB->regs->CRH = 0x44444444; // Set PORTB[8:15] to input
}

static inline void releaseBus() {
  releaseRq();
  releaseData();
}

static inline void getDataBus() {
  GPIOB->regs->CRH = 0x33333333; // Set PORTB[8:15] to 50MHz push-pull output
}

static inline void writeData(uint8_t byte) {
  GPIOB->regs->ODR = (GPIOB->regs->ODR & 0b0000000011111111) | (((int)byte) << 8);
}

static inline void pullIrq() {
  GPIOA->regs->CRH = (GPIOA->regs->CRH & 0xFFF0FFFF) | 0x00030000; // Set PORTA[8:15] to input except IRQ
}

static inline void getDrq() {
  GPIOA->regs->CRH = (GPIOA->regs->CRH & 0xFFFF0FFF) | 0x00003000;
}

static inline int getCs() {
  return GPIOB->regs->IDR & CS_MASK;
}

static inline int getAck() {
  return GPIOA->regs->IDR & ACK_MASK;
}

// Wait for a new command and put it in cmdBuf
static inline void waitCommand() {
  int b;
  noInterrupts();
  do {
    while((b = GPIOB->regs->IDR) & (A1_MASK | CS_MASK))
      IWDG_BASE->KR = IWDG_KR_FEED;
  } while(((b) >> (8+5)) != ACSI_ID);

  cmdBuf[0] = (b >> 8) & 0b00011111;
  for(int i = 1; i < 6; ++i) {
    pullIrq();
    while((b = GPIOB->regs->IDR) & (CS_MASK));
    releaseRq();
    if(!(b & A1_MASK)) {
      failure(0b10101100);
    }
    cmdBuf[i] = b >> 8;
  }
  interrupts();
  ledOn(); // Enable activity LED. It will be disabled by the sendStatus function
}

static inline void sendDma(uint8_t *bytes, int count) {
  noInterrupts();
  getDataBus();
  getDrq();
  for(int i = 0; i < count; ++i) {
    writeData(bytes[i]);
    GPIOA->regs->BSRR = DRQ_MASK; // Stabilize data
    GPIOA->regs->BRR = DRQ_MASK; // Set to low for a few periods
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BSRR = DRQ_MASK; // Release to high
    while(!getAck());
    GPIOA->regs->BSRR = DRQ_MASK; // Add some delay to stabilize data
    GPIOA->regs->BSRR = DRQ_MASK;
  }
  releaseBus();
  interrupts();
}

static inline void readDma(uint8_t *bytes, int count) {
  noInterrupts();
  getDrq();
  for(int i = 0; i < count; ++i) {
    GPIOA->regs->BRR = DRQ_MASK; // Set to low for a few periods
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BRR = DRQ_MASK;
    GPIOA->regs->BSRR = DRQ_MASK; // Release to high
    bytes[i] = GPIOB->regs->IDR >> 8; // Read data pins from PB8-PB15
    while(!getAck());
  }
  releaseRq();
  interrupts();
}

static inline void sendStatus(uint8_t s) {
  ledOff();
  noInterrupts();
  getDataBus();
  writeData(s);
  pullIrq();
  while(getCs());
  releaseBus();
  interrupts();
}

void acsiInit() {
  cmdBufCnt = 0;

  // Set output registers to 0 so pinMode(OUTPUT) brings the output low.
  digitalWrite(IRQ, 0);
  digitalWrite(DRQ, 1);
  pinMode(CS, INPUT);
  pinMode(ACK, INPUT);
  pinMode(A1, INPUT);

  // Release all bus pins
  releaseBus();

  // Wait until ST is ready
  while(!getCs());
}

uint8_t dataBuf[BLOCKSIZE];
uint32_t sdBlocks = 4000*2048; // TODO: Compute real card size - Hardcoding 4G for now.
bool sdReady = false;

bool sdInit() {
  ahdiDbgln("Initializing SD card");
  sdReady = card.init(SPI_FULL_SPEED, SD_CS);

  if(sdReady)
    sdBlocks = card.cardSize();
  else
    ahdiDbgln("Cannot init SD card");

  return sdReady;
}

void setup() {
#ifdef LED
  pinMode(LED, OUTPUT);
  ledOn(); // Enable LED on power up to signal init activity.
#endif
#if AHDI_DEBUG
  Serial.begin(115200);
  delay(100);
#endif

  ahdiDbgln("ACSI-SD bridge - Debug output");
  
  ahdiDbgln("Initializing ACSI bus");
  acsiInit();

  iwdg_init(IWDG_PRE_256, WATCHDOG_MILLIS / 8);

  sdInit();

  ahdiDbgln("Ready");
  ledOff();
}

void loop() {
  waitCommand();

  if(!sdReady) {
    if(!sdInit()) {
      sendStatus(2);
      return;
    }
  }

  // Implement commands
  switch(cmdBuf[0]) {
  case 0x00: // Test drive ready
    if(!sdInit()) {
      sendStatus(2);
      break;
    }
    else
      sendStatus(0);
    break;
  case 0x03: // Request Sense
    if(!sdInit()) {
      sendStatus(2);
      break;
    }
    dataBuf[0] = 0x80;
    dataBuf[1] = (sdBlocks >> 16) & 0xFF;
    dataBuf[2] = (sdBlocks >> 8) & 0xFF;
    dataBuf[3] = (sdBlocks) & 0xFF;
    for(uint8_t b = 4; b < cmdBuf[4]; ++b) {
      dataBuf[b] = 0;
    }
    sendDma(dataBuf, cmdBuf[4]);
    
    sendStatus(0);
    break;
  case 0x04: // Format drive
  case 0x05: // Verify track
  case 0x06: // Format track
    sendStatus(0);
    break;
  case 0x08: // Read block
    {
      int block = (((int)cmdBuf[1])<<16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
      for(int blocks = cmdBuf[4]; blocks--; block++) {
        int tries = MAXTRIES_SD;
        IWDG_BASE->KR = IWDG_KR_FEED;
        while(!card.readBlock(block, dataBuf) && tries-- > 0) {
          ahdiDbg("Retry read on block ");
          ahdiDbgln(block, HEX);
          delay(30);
          IWDG_BASE->KR = IWDG_KR_FEED;
          if(tries < 3 && !sdInit()) {
            sendStatus(2);
            break;
          }
        }
        if(!tries) {
          sendStatus(2);
          break;
        }
        sendDma(dataBuf, BLOCKSIZE);
      }
      sendStatus(0);
    }
    break;
  case 0x0A: // Write block
    {
      int block = (((int)cmdBuf[1])<<16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
      for(int blocks = cmdBuf[4]; blocks--; block++) {
        readDma(dataBuf, BLOCKSIZE);
        IWDG_BASE->KR = IWDG_KR_FEED;
        int tries = MAXTRIES_SD;
        while(!card.writeBlock(block, dataBuf) && tries-- > 0) {
          ahdiDbg("Retry write on block ");
          ahdiDbgln(block, HEX);
          delay(30);
          IWDG_BASE->KR = IWDG_KR_FEED;
          if(tries < 3 && !sdInit()) {
            sendStatus(2);
            break;
          }
        }
        if(!tries) {
          sendStatus(2);
          break;
        }
        ++block;
      }
      sendStatus(0);
    }
    break;
  case 0x0B: // Seek
  case 0x0D: // Correction
    sendStatus(0);
    break;
  case 0x12: // Inquiry
    for(uint8_t b = 0; b < cmdBuf[4]; ++b) {
      if(b < sizeof(inquiry_data))
        dataBuf[b] = inquiry_data[b];
      else
        dataBuf[b] = 0;
    }
    sendDma(dataBuf, cmdBuf[4]);
    
    sendStatus(0);
    break;
  case 0x15: // Mode select
    sendStatus(0);
    break;
  case 0x1A: // Mode sense
    switch(cmdBuf[2]) {
    case 0x00:
      for(uint8_t b = 0; b < 16; ++b) {
        dataBuf[b] = 0;
      }
      // Values got from the Hatari emulator
      dataBuf[1] = 14;
      dataBuf[3] = 8;
      dataBuf[5] = (sdBlocks >> 16) & 0xFF;
      dataBuf[6] = (sdBlocks >> 8) & 0xFF;
      dataBuf[7] = (sdBlocks) & 0xFF;
      dataBuf[10] = 2; // Sector size middle byte
      sendDma(dataBuf, 16);
      break;
    case 0x04:
      // Values got from the Hatari emulator
      dataBuf[0] = 4;
      dataBuf[1] = 22;
      dataBuf[2] = (sdBlocks >> 23) & 0xFF;
      dataBuf[3] = (sdBlocks >> 15) & 0xFF;
      dataBuf[4] = (sdBlocks >> 7) & 0xFF;
      dataBuf[5] = 128;
      for(uint8_t b = 0; b < 24; ++b) {
        dataBuf[b] = 0;
      }
      sendDma(dataBuf, 24);
      break;
    }
    sendStatus(0);
    break;
  case 0x1B: // Ship
    sendStatus(0);
    break;
  default:
    sendStatus(2);
  }
}
