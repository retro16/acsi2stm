/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019 by Jean-Matthieu Coulon
 *
 * This Library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with the program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <libmaple/libmaple_types.h>
#include <libmaple/util.h>
#include <libmaple/rcc.h>
#include <libmaple/iwdg.h>
#include <boards.h>
#include <wirish.h>
#include <inttypes.h>
#include <SPI.h>
#include "Sd2CardX.h"

// Pin definitions
#define LED PC13
#define SD_CS PA4
#define CS PB7 // Must be on port B
#define IRQ PA12
#define ACK PA8
#define A1 PB6 // Must be on port B
#define DRQ PA11
// Data pins are on PC8-PB15

// Pin masks for direct port access
#define CS_MASK 0b10000000
#define ACK_MASK 0b100000000
#define A1_MASK 0b1000000
#define DRQ_MASK 0b100000000000

// Set to 1 to enable debug output on the serial port
#define ACSI_DEBUG 0

// Set to 1 to enable verbose command output on the serial port
#define ACSI_VERBOSE 0

// ID on the ACSI bus
#define ACSI_ID 0

// Maximum number of blocks on the SD (limits capacity artificially)
//#define SD_MAX_BLOCKS 0x0FFFFF

// Watchdog duration
#define WATCHDOG_MILLIS 500

// Maximum number of retries in case of SD card errors
#define MAXTRIES_SD 5

// Block size
#define BLOCKSIZE 512

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
  'A','C','S','I','2','S','T','M',    /* Product ID 1 */
  ' ','S','D',' ','c','a','r','d',    /* Product ID 2 */
  'v','1','.','0',                    /* Revision */
};

// Globals

static Sd2Card card;
static uint8_t dataBuf[BLOCKSIZE];
static uint8_t cmdBuf[11];
static uint32_t lastBlock = 0;
static bool lastSeek = false;
static int lastErr = 0;
static int cmdLen; // Length of the last command in bytes
static uint32_t sdBlocks = 4000*2048; // Number of blocks on the SD card
static bool sdReady = false; // Set to true when a SD card has been initialized

#define LASTERR_OK 0x00
#define LASTERR_NOSECTOR 0x01
#define LASTERR_WRITEERR 0x03
#define LASTERR_OPCODE 0x20
#define LASTERR_INVADDR 0x21
#define LASTERR_INVARG 0x24
#define LASTERR_INVLUN 0x25

// Debug output functions

#if ACSI_DEBUG
template<typename T>
inline void acsiDbg(T txt) {
  Serial.flush();
  Serial.print(txt);
  Serial.flush();
}
template<typename T, typename F>
inline void acsiDbg(T txt, F fmt) {
  Serial.flush();
  Serial.print(txt, fmt);
  Serial.flush();
}
template<typename T>
inline void acsiDbgln(T txt) {
  Serial.flush();
  Serial.println(txt);
  Serial.flush();
}
template<typename T, typename F>
inline void acsiDbgln(T txt, F fmt) {
  Serial.flush();
  Serial.println(txt, fmt);
  Serial.flush();
}
#else
template<typename T>
inline void acsiDbg(T txt) {
}
template<typename T, typename F>
inline void acsiDbg(T txt, F fmt) {
}
template<typename T>
inline void acsiDbgln(T txt) {
}
template<typename T, typename F>
inline void acsiDbgln(T txt, F fmt) {
}
#endif


// LED control functions

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


// Low level pin control

// Release IRQ and DRQ pins by putting them back to input
static inline void releaseRq() {
  GPIOA->regs->CRH = (GPIOA->regs->CRH & 0xFFF00FFF) | 0x00044000; // Set PORTB[0:7] to input
}

// Release data pins by putting them back to input
static inline void releaseData() {
  GPIOB->regs->CRH = 0x44444444; // Set PORTB[8:15] to input
}

// Release the bus completely
static inline void releaseBus() {
  releaseRq();
  releaseData();
}

// Set data pins as output
static inline void acquireDataBus() {
  GPIOB->regs->CRH = 0x33333333; // Set PORTB[8:15] to 50MHz push-pull output
}

// Write a byte to the data pins
static inline void writeData(uint8_t byte) {
  GPIOB->regs->ODR = (GPIOB->regs->ODR & 0b0000000011111111) | (((int)byte) << 8);
}

// Pull IRQ to low
static inline void pullIrq() {
  GPIOA->regs->CRH = (GPIOA->regs->CRH & 0xFFF0FFFF) | 0x00030000; // Set PORTA[8:15] to input except IRQ
}

// Set the DRQ pin to output
static inline void acquireDrq() {
  GPIOA->regs->CRH = (GPIOA->regs->CRH & 0xFFFF0FFF) | 0x00003000;
}

// Returns the value of the CS pin
static inline int getCs() {
  return GPIOB->regs->IDR & CS_MASK;
}

// Returns the value of the ACK pin
static inline int getAck() {
  return GPIOA->regs->IDR & ACK_MASK;
}

// Send a pulse to the DRQ pin just long enough to trigger a read
// from the Atari DMA controller, then wait for acknowledge.
static inline void pulseDrqSend() {
  GPIOA->regs->BRR = DRQ_MASK; // Set to low for a few periods
  GPIOA->regs->BRR = DRQ_MASK;
  GPIOA->regs->BRR = DRQ_MASK;
  GPIOA->regs->BRR = DRQ_MASK;
  GPIOA->regs->BRR = DRQ_MASK;
  GPIOA->regs->BRR = DRQ_MASK;
  GPIOA->regs->BRR = DRQ_MASK;
  GPIOA->regs->BRR = DRQ_MASK;
  GPIOA->regs->BSRR = DRQ_MASK; // Release to high
}


// Send a pulse to the DRQ pin just long enough so data is ready
// to be read on the data pins
static inline void pulseDrqRead() {
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
}

// Return the current LUN for the current command
static inline int getLun() {
  if(cmdBuf[0] == 0x1F)
    return (cmdBuf[2] & 0xE0) >> 5;
  return (cmdBuf[1] & 0xE0) >> 5;
}

// Wait for a new command and put it in cmdBuf
// All commands are always 6 bytes long
// Feeds the watchdog while waiting for a new command
// When this function exits, turns the LED on
static inline void waitCommand() {
  int b;
  noInterrupts();
  do {
    // Read the command on the data pins along with the
    // A1 command start marker and the CS clock signal
    // This is done in a single operation because the
    // CS pulse is fast (250ns)
    while((b = GPIOB->regs->IDR) & (A1_MASK | CS_MASK))
      IWDG_BASE->KR = IWDG_KR_FEED; // Feed the watchdog
  } while(((b) >> (8+5)) != ACSI_ID); // Check the device ID
  // At this point we are receiving a command targetted at this device.

  // Enable activity LED. It will be disabled by the sendStatus function
  ledOn();

  // Put the command ID in the first command buffer byte
  cmdBuf[0] = (b >> 8) & 0b00011111;

  cmdLen = cmdBuf[0] == 0x1F ? 11 : 6;

  // Read the next bytes of the command
  for(int i = 1; i < cmdLen; ++i) {
    pullIrq();
    while((b = GPIOB->regs->IDR) & (CS_MASK)); // Read data and clock at the same time
    releaseRq();
    cmdBuf[i] = b >> 8; // Write the byte
  }
  interrupts();
}

// Send some bytes from dataBuf through the port to the Atari DMA controller
static inline void sendDma(int count) {
  noInterrupts();
  acquireDataBus();
  acquireDrq();
  for(int i = 0; i < count; ++i) {
    writeData(dataBuf[i]);
    pulseDrqSend();
    while(!getAck());
  }
  releaseBus();
  interrupts();
#if ACSI_VERBOSE
  acsiDbg("Send:");
  if(count < 64) {
    for(int i = 0; i < count; ++i) {
      acsiDbg(' ');
      acsiDbg(dataBuf[i], HEX);
    }
  } else {
    acsiDbg(count);
    acsiDbg(" bytes");
  }
  acsiDbgln("");
#endif
}

// Receive some bytes through the port from the Atari DMA controller and store them to dataBuf
static inline void readDma(int count) {
  noInterrupts();
  acquireDrq();
  for(int i = 0; i < count; ++i) {
    pulseDrqRead();
    dataBuf[i] = GPIOB->regs->IDR >> 8; // Read data pins from PB8-PB15
    while(!getAck());
  }
  releaseRq();
  interrupts();
#if ACSI_VERBOSE
  acsiDbg("Read:");
  if(count < 64) {
    for(int i = 0; i < count; ++i) {
      acsiDbg(' ');
      acsiDbg(dataBuf[i], HEX);
    }
  } else {
    acsiDbg(count);
    acsiDbg(" bytes");
  }
  acsiDbgln("");
#endif
}

// Send a status code and turn the status LED off
static inline void sendStatus(uint8_t s) {
  ledOff(); // We just finished processing a command: turn off activity LED

  noInterrupts();
  acquireDataBus();
  writeData(s);
  pullIrq();
  while(getCs());
  releaseBus();
  interrupts();
}

// Send a status byte that indicates the command was a success
static inline void commandSuccess() {
#if ACSI_VERBOSE
  acsiDbgln("Success");
#endif
  lastErr = LASTERR_OK;
  sendStatus(0);
}

// Send a status byte that indicates an error happened
static inline void commandError() {
#if ACSI_VERBOSE
  acsiDbgln("Error");
#endif
  sendStatus(2);
}

// Initialize the ACSI port
static inline void acsiInit() {
  acsiDbgln("Initializing the ACSI bus ...");
  digitalWrite(IRQ, 0);
  digitalWrite(DRQ, 1);
  pinMode(CS, INPUT);
  pinMode(ACK, INPUT);
  pinMode(A1, INPUT);

  // Release all bus pins
  releaseBus();

  // Wait until ST is ready
  while(!getCs() || !getAck());
  acsiDbgln("ACSI bus ready");
}

// Initialize the SD card
static bool sdInit() {
  acsiDbgln("Initializing SD card ...");
  sdReady = card.init(SPI_FULL_SPEED, SD_CS);

  if(sdReady) {
    sdBlocks = card.cardSize();
#if SD_MAX_BLOCKS
    if(sdBlocks > SD_MAX_BLOCKS)
      sdBlocks = SD_MAX_BLOCKS;
#endif
    acsiDbg("Size: ");
    acsiDbg(sdBlocks/2048);
    acsiDbg("MB - ");
    acsiDbg(sdBlocks);
    acsiDbgln(" blocks");
  }
  else
    acsiDbgln("Cannot init SD card");

  return sdReady;
}

// Write a block from dataBuf into the SD card
static inline bool sdWriteBlock(int block) {
  int tries = MAXTRIES_SD;
  while(!card.writeBlock(block, dataBuf) && tries-- > 0) {
    acsiDbg("Retry write on block ");
    acsiDbgln(block, HEX);
    delay(10); // Wait a bit to leave some recovery time for the SD card
    IWDG_BASE->KR = IWDG_KR_FEED; // Feed the watchdog for retries
    // After a certain amount of retries, reinit the SD card completely
    if(tries <= MAXTRIES_SD / 2 && !sdInit()) {
      return false;
    }
  }
  return tries > 0;
}

// Process a write block command
static inline bool writeBlock(int block, int count) {
  if(block + count - 1 >= sdBlocks) {
    lastErr = LASTERR_INVADDR;
    return false; // Block out of range
  }
  // For each requested block
  for(int blocks = count; blocks--; block++) {
    IWDG_BASE->KR = IWDG_KR_FEED; // Feed the watchdog
    readDma(BLOCKSIZE); // Receive data to write
    // Do the actual write operation
    if(!sdWriteBlock(block)) {
      // SD write error
      return false;
    }
  }
  return true;
}

// Read a block from the SD card and store it to dataBuf
static inline bool sdReadBlock(int block) {
  int tries = MAXTRIES_SD;
  while(!card.readBlock(block, dataBuf) && tries-- > 0) {
    acsiDbg("Retry read on block ");
    acsiDbgln(block, HEX);
    delay(10); // Wait a bit to leave some recovery time for the SD card
    IWDG_BASE->KR = IWDG_KR_FEED; // Feed the watchdog for retries
    // After a certain amount of retries, reinit the SD card completely
    if(tries <= MAXTRIES_SD / 2 && !sdInit()) {
      // SD write error
      lastErr = LASTERR_WRITEERR;
      return false;
    }
  }
  return tries > 0;
}

// Process a read block command
static inline bool readBlock(int block, int count) {
  if(block + count - 1 >= sdBlocks) {
    lastErr = LASTERR_INVADDR;
    return false; // Block out of range
  }
  // For each requested block
  for(int blocks = count; blocks--; block++) {
    IWDG_BASE->KR = IWDG_KR_FEED; // Feed the watchdog
    int tries = MAXTRIES_SD;
    // Do the actual read operation
    if(!sdReadBlock(block)) {
      // SD read error
      lastErr = LASTERR_NOSECTOR;
      return false;
    }
    sendDma(BLOCKSIZE); // Send read data
  }
  return true;
}

// Main setup function
void setup() {
#ifdef LED
  pinMode(LED, OUTPUT);
  ledOn(); // Enable LED on power up to signal init activity.
#endif
#if ACSI_DEBUG
  Serial.begin(115200); // Init the serial port only if needed
#endif

  acsiDbgln("Retro16 STM32 SD bridge v1.0");
  
  // Initialize the ACSI port
  acsiInit();

  // Initialize the watchdog
  iwdg_init(IWDG_PRE_256, WATCHDOG_MILLIS / 8);

  // Initialize the SD card
  sdInit();

  // Ready to go
  acsiDbgln("Ready to go");
  ledOff();
}

// Main loop
void loop() {
  waitCommand(); // Wait for the next command arriving in cmdBuf

  if(!sdReady) {
    if(!sdInit()) {
      commandError();
      return;
    }
  }

#if ACSI_VERBOSE
  acsiDbg("Command ");
  for(int i = 0; i < cmdLen; ++i) {
    acsiDbg(' ');
    acsiDbg(cmdBuf[i], HEX);
  }
  acsiDbgln("");
#endif

  switch(cmdBuf[0]) {
  default:
    // Check LUN
    if(getLun() > 0) {
      lastErr = LASTERR_INVLUN;
      commandError();
      return;
    }
  case 0x03: // Request Sense
  case 0x12: // Inquiry
    break;
  }

  // Execute the command
  switch(cmdBuf[0]) {
  default: // Unknown command
    acsiDbg("Unknown command ");
    for(int i = 0; i < cmdLen; ++i) {
      acsiDbg(' ');
      acsiDbg(cmdBuf[i], HEX);
    }
    acsiDbgln("");
    lastSeek = false;
    commandError();
    return;
  case 0x0D: // Correction
  case 0x15: // Mode select
  case 0x1B: // Ship
    // Always succeed
    lastSeek = false;
    commandSuccess();
    return;
  case 0x04: // Format drive
  case 0x05: // Verify track
  case 0x06: // Format track
    lastSeek = false;
    // fall through case
  case 0x00: // Test drive ready
    // Reinitialize the SD card
    if(!sdInit()) {
      commandError();
      return;
    }
    else
      commandSuccess();
    return;
  case 0x03: // Request Sense
    // Reinitialize the SD card
    if(!sdInit()) {
      commandError();
      return;
    }
    // Fill the response with zero bytes
    for(int b = 0; b < cmdBuf[4]; ++b) {
      dataBuf[b] = 0;
    }
    if(cmdBuf[4] <= 4) {
      dataBuf[0] = lastErr;
      if(lastSeek) {
        dataBuf[0] |= 0x80;
        dataBuf[1] = (lastBlock >> 16) & 0xFF;
        dataBuf[2] = (lastBlock >> 8) & 0xFF;
        dataBuf[3] = (lastBlock) & 0xFF;
      }
    } else {
      // Build long response in dataBuf
      dataBuf[0] = 0x70;
      if(lastSeek) {
        dataBuf[0] |= 0x80;
        dataBuf[4] = (lastBlock >> 16) & 0xFF;
        dataBuf[5] = (lastBlock >> 8) & 0xFF;
        dataBuf[6] = (lastBlock) & 0xFF;
      }
      switch(lastErr) {
      case LASTERR_OK:
        dataBuf[2] = 0;
        break;
      case LASTERR_OPCODE:
      case LASTERR_INVADDR:
      case LASTERR_INVARG:
      case LASTERR_INVLUN:
        dataBuf[2] = 5;
        break;
      default:
        dataBuf[2] = 4;
        break;
      }
      dataBuf[7] = 14;
      dataBuf[12] = lastErr;
      dataBuf[19] = (lastBlock >> 16) & 0xFF;
      dataBuf[20] = (lastBlock >> 8) & 0xFF;
      dataBuf[21] = (lastBlock) & 0xFF;
    }
    // Send the response
    sendDma(cmdBuf[4]);
    
    commandSuccess();
    return;
  case 0x08: // Read block
    // Compute the block number
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;

    // Do the actual read operation
    if(readBlock(lastBlock, cmdBuf[4]))
      commandSuccess();
    else
      commandError();
    return;
  case 0x0A: // Write block
    // Compute the block number
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;

    // Do the actual write operation
    if(writeBlock(lastBlock, cmdBuf[4]))
      commandSuccess();
    else
      commandError();
    return;
  case 0x0B: // Seek
    // Reinitialize the SD card
    if(!sdInit()) {
      lastErr = LASTERR_INVADDR;
      commandError();
      return;
    }
    lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    lastSeek = true;
    if(lastBlock >= sdBlocks) {
      lastErr = LASTERR_INVADDR;
      commandError();
    } else
      commandSuccess();
    return;
  case 0x12: // Inquiry
    // Reinitialize the SD card
    if(!sdInit()) {
      commandError();
      return;
    }
    for(uint8_t b = 0; b < cmdBuf[4]; ++b) {
      dataBuf[b] = 0;
    }

    if(getLun() > 0)
      dataBuf[0] = 0x7F; // Unsupported LUN
    dataBuf[2] = 1; // ACSI version
    dataBuf[4] = 31; // Data length
    
    // Build the product string with the SD card size
    snprintf((char*)dataBuf + 8, 29, "ACSI2STM SD %7d MB  v1.0", sdBlocks/2048);
    
    sendDma(cmdBuf[4]);

    lastSeek = false;
    commandSuccess();
    return;
  case 0x1A: // Mode sense
    lastSeek = false;
    switch(cmdBuf[2]) { // Sub-command
    case 0x00:
      for(uint8_t b = 0; b < 16; ++b) {
        dataBuf[b] = 0;
      }
      // Values got from the Hatari emulator
      dataBuf[1] = 14;
      dataBuf[3] = 8;
      // Send the number of blocks of the SD card
      dataBuf[5] = (sdBlocks >> 16) & 0xFF;
      dataBuf[6] = (sdBlocks >> 8) & 0xFF;
      dataBuf[7] = (sdBlocks) & 0xFF;
      // Sector size middle byte
      dataBuf[10] = 2;
      sendDma(16);
      break;
    case 0x04:
      for(uint8_t b = 0; b < 24; ++b) {
        dataBuf[b] = 0;
      }
      // Values got from the Hatari emulator
      dataBuf[0] = 4;
      dataBuf[1] = 22;
      // Send the number of blocks in CHS format
      dataBuf[2] = (sdBlocks >> 23) & 0xFF;
      dataBuf[3] = (sdBlocks >> 15) & 0xFF;
      dataBuf[4] = (sdBlocks >> 7) & 0xFF;
      // Hardcode 128 heads
      dataBuf[5] = 128;
      sendDma(24);
      break;
    default:
      if(getLun() == 0)
        lastErr = LASTERR_INVARG;
      commandError();
      return;
    }
    commandSuccess();
    return;
  case 0x1F: // ICD extended command
    switch(cmdBuf[1]) { // Sub-command
    case 0x25: // Read capacity
      // Reinitialize the SD card
      if(!sdInit()) {
        commandError();
        return;
      }
      // Send the number of blocks of the SD card
      dataBuf[0] = (sdBlocks >> 24) & 0xFF;
      dataBuf[1] = (sdBlocks >> 16) & 0xFF;
      dataBuf[2] = (sdBlocks >> 8) & 0xFF;
      dataBuf[3] = (sdBlocks) & 0xFF;
      // Send the block size (which is always 512)
      dataBuf[4] = 0x00;
      dataBuf[5] = 0x00;
      dataBuf[6] = 0x02;
      dataBuf[7] = 0x00;
      
      sendDma(8);
      
      commandSuccess();
      return;
    case 0x28: // Read sector
      {
        // Compute the block number
        int block = (((int)cmdBuf[3]) << 24) | (((int)cmdBuf[4]) << 16) | (((int)cmdBuf[5]) << 8) | (cmdBuf[6]);
        int count = (((int)cmdBuf[8]) << 8) | (cmdBuf[9]);
  
        // Do the actual read operation
        if(readBlock(block, count))
          commandSuccess();
        else
          commandError();
      }
      return;
    case 0x2A: // Write block
      {
        // Compute the block number
        int block = (((int)cmdBuf[3]) << 24) | (((int)cmdBuf[4]) << 16) | (((int)cmdBuf[5]) << 8) | (cmdBuf[6]);
        int count = (((int)cmdBuf[8]) << 8) | (cmdBuf[9]);
  
        // Do the actual write operation
        if(writeBlock(block, count))
          commandSuccess();
        else
          commandError();
      }
      return;
    }
  }
}
