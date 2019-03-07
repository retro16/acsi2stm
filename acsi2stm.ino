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

#define ACSI2STM_VERSION "1.1"

// Pin definitions
static const int sdCs[] = {
  // List of SD card CS pins
  PA4,
  PA3,
  //PA2,
  //PA1,
  //PA0,
  //PA8,
  //PB0,
  //PB1,
};
#define LED PC13
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
#define ACSI_DEBUG 1

// Set to 1 to enable verbose command output on the serial port
#define ACSI_VERBOSE 0

// ID on the ACSI bus
#define ACSI_ID 0

// Maximum number of blocks on the SD (limits capacity artificially)
//#define SD_MAX_BLOCKS 0x0FFFFF

// Watchdog duration
#define WATCHDOG_MILLIS 800

// Maximum number of retries in case of SD card errors
#define MAXTRIES_SD 5

// Block size
#define BLOCKSIZE 512

// Globals

class SD {
public:
  Sd2Card card;
  uint32_t blocks;
  int acsiDevId = -1;
  bool initialized = false;
  bool bootable;
  uint32_t lastBlock;
  bool lastSeek;
  int lastErr;

  bool init();
  bool writeBlock(int block);
  bool writeBlocks(int block, int count);
  bool readBlock(int block);
  bool readBlocks(int block, int count);
  void getId(char *target);
};
#define MAX_SD (sizeof(sdCs)/sizeof(int))
static SD sdCards[MAX_SD];
static SD *sd; // Current SD card
static uint8_t dataBuf[BLOCKSIZE];
static uint8_t cmdBuf[11];
static int cmdLen; // Length of the last command in bytes

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
  } while(((b) >> (8+5)) >= MAX_SD); // Check the device ID
  // At this point we are receiving a command targetted at this device.

  // Select the correct SD card
  sd = &sdCards[b >> (8+5)];

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
  sd->lastErr = LASTERR_OK;
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
  acsiDbgln("Initializing ACSI bus ...");
  delay(1);

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
bool SD::init() {
  if(acsiDevId == -1) {
    acsiDbgln("Invalid ACSI device for SD card");
    initialized = false;
    return false;
  }

  acsiDbg("Initializing SD card ");
  acsiDbgln(acsiDevId);
  IWDG_BASE->KR = IWDG_KR_FEED;
  initialized = card.init(SPI_FULL_SPEED, sdCs[acsiDevId]);

  if(initialized) {
    blocks = card.cardSize();
    acsiDbg("Size: ");
    acsiDbg(blocks / 2048);
    acsiDbg("MB - ");
    acsiDbg(blocks);
    acsiDbg(" blocks");
#if SD_MAX_BLOCKS
    if(blocks > SD_MAX_BLOCKS) {
      blocks = SD_MAX_BLOCKS;
      acsiDbg(" (capped to ");
      acsiDbg(blocks / 2048);
      acsiDbg("MB)");
    }
#endif
    acsiDbgln("");

    // Detect partition type
    readBlock(0);
    int checksum = 0;
    for(int i = 0; i < BLOCKSIZE; i += 2) {
      checksum += dataBuf[i] << 8 + dataBuf[i+1];
    }
    if((checksum & 0xFFFF) == 0x1234) {
      // Valid Atari boot sector
      acsiDbgln("SD card is bootable");
      bootable = true;
    }

  }
  else
    acsiDbgln("Cannot init SD card");

  IWDG_BASE->KR = IWDG_KR_FEED;
  return initialized;
}

// Write a block from dataBuf into the SD card
inline bool SD::writeBlock(int block) {
  int tries = MAXTRIES_SD;
  readDma(BLOCKSIZE); // Receive data to write
  while(!card.writeBlock(block, dataBuf) && tries-- > 0) {
    acsiDbg("Retry write on block ");
    acsiDbgln(block, HEX);
    delay(10); // Wait a bit to leave some recovery time for the SD card
    IWDG_BASE->KR = IWDG_KR_FEED; // Feed the watchdog for retries
    // After a certain amount of retries, reinit the SD card completely
    if(tries <= MAXTRIES_SD / 2 && !init()) {
      return false;
    }
  }
  return tries > 0;
}

// Process a write block command
inline bool SD::writeBlocks(int block, int count) {
  if(block + count - 1 >= blocks) {
    sd->lastErr = LASTERR_INVADDR;
    return false; // Block out of range
  }
  // For each requested block
  for(int b = count; b--; block++) {
    IWDG_BASE->KR = IWDG_KR_FEED; // Feed the watchdog
    // Do the actual write operation
    if(!writeBlock(block)) {
      // SD write error
      return false;
    }
  }
  return true;
}

// Read a block from the SD card and store it to dataBuf
inline bool SD::readBlock(int block) {
  int tries = MAXTRIES_SD;
  while(!card.readBlock(block, dataBuf) && tries-- > 0) {
    acsiDbg("Retry read on block ");
    acsiDbgln(block, HEX);
    delay(10); // Wait a bit to leave some recovery time for the SD card
    IWDG_BASE->KR = IWDG_KR_FEED; // Feed the watchdog for retries
    // After a certain amount of retries, reinit the SD card completely
    if(tries <= MAXTRIES_SD / 2 && !init()) {
      // SD write error
      sd->lastErr = LASTERR_NOSECTOR;
      return false;
    }
  }
  if(tries == 0)
    return false; // Retried too many times
  
  sendDma(BLOCKSIZE); // Send read data
  return true;
}

// Process a read block command
inline bool SD::readBlocks(int block, int count) {
  if(block + count - 1 >= blocks) {
    sd->lastErr = LASTERR_INVADDR;
    return false; // Block out of range
  }
  // For each requested block
  for(int blocks = count; blocks--; block++) {
    IWDG_BASE->KR = IWDG_KR_FEED; // Feed the watchdog
    // Do the actual read operation
    if(!readBlock(block)) {
      return false;
    }
  }
  return true;
}

void SD::getId(char *target) {
  sprintf(target, "ACSI2STM SD            v" ACSI2STM_VERSION);

  // Write ACSI ID
  target[13] = '0' + acsiDevId;

  // Write SD card size
  if(blocks >= 2048*10240) // Size in GB if size >= 10G
    sprintf(target + 15, "%dGB", blocks / (2048*1024));
  else // Size in MB
    sprintf(target + 15, "%dMB", blocks / 2048);

  // Add the Atari logo at the end if the SD is detected as bootable
  if(bootable) {
    target[22] = 0x0E;
    target[23] = 0x0F;
  }
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

  acsiDbgln("");
  acsiDbgln("");
  acsiDbgln("");
  acsiDbgln("-----------------------");
  acsiDbgln("ACSI2STM SD bridge v" ACSI2STM_VERSION);
  acsiDbgln("-----------------------");
  acsiDbgln("");
  
  // Initialize the ACSI port
  acsiInit();

  // Initialize the watchdog
  iwdg_init(IWDG_PRE_256, WATCHDOG_MILLIS / 8);

  // Initialize SD cards
  int sdCount = 0;
  for(int i = 0; i < MAX_SD; ++i) {
    sdCards[i].acsiDevId = i;
    if(sdCards[i].init())
      sdCount++;
  }
  
  acsiDbg(sdCount);
  acsiDbgln(" SD cards found");

  acsiDbgln("");
  acsiDbgln("--- Ready to go ---");
  acsiDbgln("");
  ledOff();
}

// Main loop
void loop() {
  waitCommand(); // Wait for the next command arriving in cmdBuf

  if(!sd->initialized) {
    if(!sd->init()) {
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
      sd->lastErr = LASTERR_INVLUN;
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
    sd->lastSeek = false;
    commandError();
    return;
  case 0x0D: // Correction
  case 0x15: // Mode select
  case 0x1B: // Ship
    // Always succeed
    sd->lastSeek = false;
    commandSuccess();
    return;
  case 0x04: // Format drive
  case 0x05: // Verify track
  case 0x06: // Format track
    sd->lastSeek = false;
    // fall through case
  case 0x00: // Test drive ready
    // Reinitialize the SD card
    if(!sd->init()) {
      commandError();
      return;
    }
    else
      commandSuccess();
    return;
  case 0x03: // Request Sense
    // Reinitialize the SD card
    if(!sd->init()) {
      commandError();
      return;
    }
    // Fill the response with zero bytes
    for(int b = 0; b < cmdBuf[4]; ++b) {
      dataBuf[b] = 0;
    }
    if(cmdBuf[4] <= 4) {
      dataBuf[0] = sd->lastErr;
      if(sd->lastSeek) {
        dataBuf[0] |= 0x80;
        dataBuf[1] = (sd->lastBlock >> 16) & 0xFF;
        dataBuf[2] = (sd->lastBlock >> 8) & 0xFF;
        dataBuf[3] = (sd->lastBlock) & 0xFF;
      }
    } else {
      // Build long response in dataBuf
      dataBuf[0] = 0x70;
      if(sd->lastSeek) {
        dataBuf[0] |= 0x80;
        dataBuf[4] = (sd->lastBlock >> 16) & 0xFF;
        dataBuf[5] = (sd->lastBlock >> 8) & 0xFF;
        dataBuf[6] = (sd->lastBlock) & 0xFF;
      }
      switch(sd->lastErr) {
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
      dataBuf[12] = sd->lastErr;
      dataBuf[19] = (sd->lastBlock >> 16) & 0xFF;
      dataBuf[20] = (sd->lastBlock >> 8) & 0xFF;
      dataBuf[21] = (sd->lastBlock) & 0xFF;
    }
    // Send the response
    sendDma(cmdBuf[4]);
    
    commandSuccess();
    return;
  case 0x08: // Read block
    // Compute the block number
    sd->lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    sd->lastSeek = true;

    // Do the actual read operation
    if(sd->readBlocks(sd->lastBlock, cmdBuf[4]))
      commandSuccess();
    else
      commandError();
    return;
  case 0x0A: // Write block
    // Compute the block number
    sd->lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    sd->lastSeek = true;

    // Do the actual write operation
    if(sd->writeBlocks(sd->lastBlock, cmdBuf[4]))
      commandSuccess();
    else
      commandError();
    return;
  case 0x0B: // Seek
    // Reinitialize the SD card
    if(!sd->init()) {
      sd->lastErr = LASTERR_INVADDR;
      commandError();
      return;
    }
    sd->lastBlock = (((int)cmdBuf[1]) << 16) | (((int)cmdBuf[2]) << 8) | (cmdBuf[3]);
    sd->lastSeek = true;
    if(sd->lastBlock >= sd->blocks) {
      sd->lastErr = LASTERR_INVADDR;
      commandError();
    } else
      commandSuccess();
    return;
  case 0x12: // Inquiry
    // Reinitialize the SD card
    if(!sd->init()) {
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
    sd->getId((char *)dataBuf + 8);
    
    sendDma(cmdBuf[4]);

    sd->lastSeek = false;
    commandSuccess();
    return;
  case 0x1A: // Mode sense
    sd->lastSeek = false;
    switch(cmdBuf[2]) { // Sub-command
    case 0x00:
      for(uint8_t b = 0; b < 16; ++b) {
        dataBuf[b] = 0;
      }
      // Values got from the Hatari emulator
      dataBuf[1] = 14;
      dataBuf[3] = 8;
      // Send the number of blocks of the SD card
      dataBuf[5] = (sd->blocks >> 16) & 0xFF;
      dataBuf[6] = (sd->blocks >> 8) & 0xFF;
      dataBuf[7] = (sd->blocks) & 0xFF;
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
      dataBuf[2] = (sd->blocks >> 23) & 0xFF;
      dataBuf[3] = (sd->blocks >> 15) & 0xFF;
      dataBuf[4] = (sd->blocks >> 7) & 0xFF;
      // Hardcode 128 heads
      dataBuf[5] = 128;
      sendDma(24);
      break;
    default:
      if(getLun() == 0)
        sd->lastErr = LASTERR_INVARG;
      commandError();
      return;
    }
    commandSuccess();
    return;
  case 0x1F: // ICD extended command
    switch(cmdBuf[1]) { // Sub-command
    case 0x25: // Read capacity
      // Reinitialize the SD card
      if(!sd->init()) {
        commandError();
        return;
      }
      // Send the number of blocks of the SD card
      dataBuf[0] = (sd->blocks >> 24) & 0xFF;
      dataBuf[1] = (sd->blocks >> 16) & 0xFF;
      dataBuf[2] = (sd->blocks >> 8) & 0xFF;
      dataBuf[3] = (sd->blocks) & 0xFF;
      // Send the block size (which is always 512)
      dataBuf[4] = 0x00;
      dataBuf[5] = 0x00;
      dataBuf[6] = 0x02;
      dataBuf[7] = 0x00;
      
      sendDma(8);
      
      commandSuccess();
      return;
    case 0x28: // Read blocks
      {
        // Compute the block number
        int block = (((int)cmdBuf[3]) << 24) | (((int)cmdBuf[4]) << 16) | (((int)cmdBuf[5]) << 8) | (cmdBuf[6]);
        int count = (((int)cmdBuf[8]) << 8) | (cmdBuf[9]);
  
        // Do the actual read operation
        if(sd->readBlocks(block, count))
          commandSuccess();
        else
          commandError();
      }
      return;
    case 0x2A: // Write blocks
      {
        // Compute the block number
        int block = (((int)cmdBuf[3]) << 24) | (((int)cmdBuf[4]) << 16) | (((int)cmdBuf[5]) << 8) | (cmdBuf[6]);
        int count = (((int)cmdBuf[8]) << 8) | (cmdBuf[9]);
  
        // Do the actual write operation
        if(sd->writeBlocks(block, count))
          commandSuccess();
        else
          commandError();
      }
      return;
    }
  }
}
