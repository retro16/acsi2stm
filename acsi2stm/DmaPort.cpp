/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2021 by Jean-Matthieu Coulon
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with the program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
How CS and A1 signals are handled
=================================

Expected behavior
-----------------

CS is generated by the ST, it signals that an IRQ transfer has been executed.
A1 is generated by the ST, when low it signals that the current transfer is
the beginning of a new command.

Command (ST -> STM32)

         ______________         ________        ___
    IRQ                |_______|        |______|
         __     ___________________________________
    A1     |___|
         ___   _____________   _____________   ____
    CS      |_|             |_|             |_|
    
    DATA    [1]             [2]             [3]


Status (STM32 -> ST)

         __         __
    IRQ    |_______|
         _______   ___
    CS          |_|
    
    DATA   [=======]


STM32 implementation
--------------------

Main issues faced in previous versions:

 * The CS pulse is too fast to be reliably polled.
 * A1 and CS must be read at the same time.
 * Data is guaranteed to be available only when the CS pin is low.

In order to sample CS, A1 and D0-D7 pins all at the same time, a hardware
timer and 2 DMA channels are used. In order to sample both CS and A1, the
timer is set in rotating encoder mode.

In encoder mode 2, A1 gives the rotation direction and CS gives the rotation
pulse. A CS pulse is equivalent to rotating the encoder one step in one
direction, then quickly going back to the starting position.

Overview of the setup:
              __________
          DIR|  Timer4  |Underflow
    A1 ----->|TI1       |------------
             |          |            |
         STEP|          |CH3 CC      |
    CS ----->|TI2       |------------+
             |__________|            |
                                     |Trigger (DMA1 CH5+CH7)
                       _______     __V___     __________
                      |       |   |      |   |          |
                      | GPIOB |-->| DMA1 |-->|  Timer4  |
                      |       |   |      |   |  CH4 CC  |
                      |_______|   |______|   |__________|

A CS pulse with A1 low will pulse the timer counter to 1, then back to 0. This
will trigger CH3 compare event.

A CS pulse with A1 high will pulse the timer counter to -1 (65535), then back
to 0. This will trigger the overflow/underflow event.

Both events will trigger a DMA operation that copies GPIOB to the channel 4 CC
value.

Timer4 CH4 is used as a simple buffer because GPIOB is considered as memory by
the STM32 DMA engine and memory to memory copies cannot be triggered by a
timer, so it has to be a memory to peripheral copy. Any unused peripheral
register can be used for this task.


How ACSI DMA is handled (DRQ/ACK pulses and data sampling)
==========================================================

Expected behavior
-----------------

DRQ is generated by the STM32, it triggers a DMA transfer.
ACK is generated by the ST, it tells the STM32 when the data bus is sampled.
DRQ must go high at most 180ns after ACK goes low. Failing to do that will
abort the DMA transfer by the ST.

DMA reads (STM32 -> ST)

          ___              _________
     DRQ     |____________|
          ______________         ___
     ACK                |_______|
    
    DATA                        S

Data seems to be sampled when ACK goes up (marked "S").
The STM32 keeps the data up for the whole transfer (DRQ+ACK), which avoids
risks of reading invalid data.


DMA writes (ST -> STM32)

          ___              _________
     DRQ     |____________|
          ______________         ___
     ACK                |_______|
    
    DATA               [========]

Data is guaranteed to be available during the whole ACK pulse (marked "[==]").


STM32 implementation
--------------------

DRQ and ACK pulses are too fast to use bit banging, even with direct port
access.

The current implementation uses STM32 timers and its DMA engine to process
these signals. Data flow:

               __________
           CLK|          |CH4
    ACK ----->|  Timer1  |-----> PA11 (DRQ)
              |          |
              |          |CH3
              |          |------------
              |__________|            |
                                      |Trigger (DMA1 CH6)
                        _______     __V___     __________
                       |       |   |      |   |          |
                       | GPIOB |-->| DMA1 |-->|  Timer1  |
                       |       |   |      |   |  CH1 CC  |
                       |_______|   |______|   |__________|

 * ACK is used as Timer1 clock.
 * PA11 (DRQ) is used as a PWM output that goes up whenever Timer1 receives a clock tick.
 * Timer1 triggers a STM32 DMA transfer whenever Timer1 receives a clock tick.
 * The STM32 DMA engine copies GPIOB to Timer1 CH1 compare value.
 * Timer1 CH1 is used as a simple buffer because GPIOB is considered as memory
   by the STM32 DMA engine and memory to memory copies cannot be triggered by
   a timer, so it has to be a memory to peripheral copy. Any unused peripheral
   register can be used for this task.
 * If multiple ACK signals are received, this can be detected by having an incorrect
   counter value. This avoids silent data corruption in case of problems. This check is
   only done if ACSI_CAREFUL_DMA is enabled.


DMA read process
----------------

DMA block transfer initialization process:

 * Set Timer1 counter to a high value so DRQ will be high when enabled
 * Enable DRQ in PWM mode (high if Timer1 > 0, low if Timer1 = 0)
 * Enable Timer1

DMA byte read process:

 * Data is put on the data bus.
 * Set Timer1 counter to 0, this will pull DRQ low.
 * When ACK goes low, Timer1 counts to 1.
 * Timer1 counting will set DRQ high.
 * Wait until ACK goes high.

DMA block transfer stop process:

 * Set DRQ pin as input
 * Disable Timer1


DMA write process
-----------------

DMA block transfer initialization process:

 * Set Timer1 counter to a high value so DRQ will be high when enabled
 * Enable DRQ in PWM mode (high if Timer1 > 0, low if Timer1 = 0)
 * Enable Timer1

DMA byte write process:

 * Set Timer1 counter to 0, this will pull DRQ low.
 * When ACK goes low, Timer1 counts to 1.
 * Timer1 counting will set DRQ high.
 * Timer1 counting will trigger the STM32 DMA CH6.
 * The STM32 DMA will copy GPIOB to Timer1 CH1 compare value.
 * Wait until ACK goes high.
 * Read Timer1 CH1 compare value to get the data byte.

DMA block transfer stop process:

 * Set DRQ pin as input
 * Disable Timer1


How RESET is handled
====================

Because the RESET pulse can be short, we have to latch it using hardware.

Using interrupts is out of question because it can disturb the tight loop of
DMA transfers and disabling interrupts during DMA transfers defeats the purpose
of having a RESET line.

Timer2 is used to memorize that the RESET line was going low. It is used in
capture & compare mode.

The timer's counter is locked to 0, the timer's channel 1 is configured to
capture on PA15 falling edge. It's CCR (capture & compare register) is set to 1
so whenever a value is captured on RESET, it captures 0.

To check whether RESET has happened in the past or not, you just have to read
CCR1: if it is 1, RESET didn't happen since last init, if it's 0, RESET
happened.

*/

#include "acsi2stm.h"
#include "Acsi.h"
#include "DmaPort.h"
#include <libmaple/dma.h>

// Timer
#define DMA_TIMER TIMER1_BASE
#define RESET_TIMER TIMER2_BASE
#define TIMEOUT_TIMER TIMER3_BASE
#define CS_TIMER TIMER4_BASE

void DmaPort::waitBusReady() {
  // Setup hardware

  setupGpio();
  setupDrqTimer();
  setupCsTimer();

  Acsi::dbg("Waiting for the ACSI bus ...\n");

  // The bus must output high signals for 100ms to be considered up.
  // Pins are discharged using the pulldown to make sure the high is strong.
  for(int debounce = 0; debounce < 20; ++debounce) {
    delay(5);

    // Pull the bus low with pulldowns for a very brief moment
    // Just enough to discharge the bus if not powered
    // No need to pull it low permanently
    pinMode(CS, INPUT_PULLDOWN);
    pinMode(A1, INPUT_PULLDOWN);
    delayMicroseconds(200);
    pinMode(CS, INPUT);
    pinMode(A1, INPUT);

    while(!idle())
      // Sensed a low line: reset delay
      debounce = 0;
  }

  // Start monitoring the RST line
  setupResetTimer();

  // Get ready to receive an A1 command
  armA1();

  Acsi::dbg("--- Ready to go ---\n");
}

bool DmaPort::checkCommand() {
  return DMA1_BASE->ISR & DMA_ISR_TCIF5;
}

uint8_t DmaPort::readCommand() {
  // Read command
  uint8_t cmd = csData();
  Acsi::verboseHex('[', cmdDeviceId(cmd), ':', cmdCommand(cmd), ']');

  // Get ready to receive the next command
  armA1();

  return cmd;
}

uint8_t DmaPort::waitCommand() {
  do {
    resetTimeout();
  } while(!checkCommand());
  return readCommand();
}

void DmaPort::readIrq(uint8_t *bytes, int count) {
  while(count > 0) {
    *bytes = readIrq();
    ++bytes;
    --count;
  }
}

uint8_t DmaPort::readIrq() {
  resetTimeout();

  Acsi::verbose("[<");

  // Signal that we are ready to read
  armCs();
  pullIrq();
  waitCs();

  // Read the actual byte
  uint8_t byte = csData();

  // Go back to idle state
  releaseRq();
  waitIrqUp();
  armA1();

  Acsi::verboseHex(byte, ']');

  return byte;
}

uint8_t DmaPort::readNoIrq() {
  resetTimeout();

  Acsi::verbose("[{");

  // Signal that we are ready to read
  waitCs();

  // Read the actual byte
  uint8_t byte = csData();

  // Go back to idle state
  releaseRq();
  waitIrqUp();
  armA1();

  Acsi::verboseHex(byte, ']');

  return byte;
}

void DmaPort::sendIrq(uint8_t byte) {
  resetTimeout();

  Acsi::verboseHex("[>", byte);

  // Output data
  acquireDataBus();
  writeData(byte);

  // Signal data is available and wait for the CS signal
  armCs();
  pullIrq();
  waitCs();

  // Go back to the idle state
  releaseRq();
  releaseDataBus();
  waitIrqUp();
  armA1();

  Acsi::verboseHex("]\n");
}

void DmaPort::sendIrqFast(uint8_t *bytes, int count) {
  resetTimeout();

  Acsi::verboseHex("[}");

  // Output data
  acquireDataBus();
  writeData(*bytes);

  armCs();
  pullIrq();
  waitCs();
  releaseRq();

  // Send extra bytes skipping the IRQ pin cycle
  for(int i = 1; i < count; ++i) {
    writeData(bytes[i]);
    armCs();
    waitCs();
  }

  // Go back to the idle state
  releaseDataBus();
  waitIrqUp();
  armA1();

  for(int i = 0; i < count; ++i)
    Acsi::verboseHex(bytes[i], '}');
 
  Acsi::verboseHex("]");
}

void DmaPort::readDma(uint8_t *bytes, int count) {
  resetTimeout();

  Acsi::verbose("DMA read ");

  // Disable systick that introduces jitter.
  systick_disable();

  disableAckFilter();
  enableDmaRead();

  acquireDrq();

  // Unroll for speed
  int i = 0;
#if ACSI_FAST_DMA
#define ACSI_READ_BYTE(b) do { \
      if(!checkDma()) \
        if(!checkDma()) \
        if(!checkDma()) \
        if(!checkDma()) \
        if(!checkDma()) \
          while(!checkDma()) \
            checkReset(); \
      triggerDrq(); \
      bytes[b] = dmaData(); \
      armDma(); \
    } while(0)
  for(i = 0; i <= count - 16; i += 16) {
    armDma();
    triggerDrq();
    ACSI_READ_BYTE(0);
    ACSI_READ_BYTE(1);
    ACSI_READ_BYTE(2);
    ACSI_READ_BYTE(3);
    ACSI_READ_BYTE(4);
    ACSI_READ_BYTE(5);
    ACSI_READ_BYTE(6);
    ACSI_READ_BYTE(7);
    ACSI_READ_BYTE(8);
    ACSI_READ_BYTE(9);
    ACSI_READ_BYTE(10);
    ACSI_READ_BYTE(11);
    ACSI_READ_BYTE(12);
    ACSI_READ_BYTE(13);
    ACSI_READ_BYTE(14);
    if(!checkDma())
      if(!checkDma())
      if(!checkDma())
      if(!checkDma())
      if(!checkDma())
        while(!checkDma())
          checkReset();
    bytes[15] = dmaData();
    bytes += 16;
  }
#undef ACSI_READ_BYTE
#endif

  while(i < count) {
    armDma();
    triggerDrq(); // Trigger DRQ
    while(!checkDma()) // Wait for DMA complete
      checkReset();
    *bytes = dmaData(); // Copy data into the buffer
    ++i;
    ++bytes;
  }

  releaseRq();
  disableDmaRead();

  // Restore systick
  systick_enable();

  armA1();

  Acsi::verboseDump(&bytes[-i], i);
  Acsi::verbose(" OK\n");
}

void DmaPort::readDmaString(char *bytes, int count) {
  resetTimeout();

  Acsi::verbose("DMA string read ", '\'');

  // Disable systick that introduces jitter.
  systick_disable();

  disableAckFilter();
  enableDmaRead();

  acquireDrq();

  int i = 0;

  while(i < count) {
    armDma();
    triggerDrq(); // Trigger DRQ
    while(!checkDma()) // Wait for DMA complete
      checkReset();
    if(!(*bytes = (char)dmaData())) // Copy data into the buffer
      break; // Stop if encountered a zero byte
    ++i;
    ++bytes;
  }

  releaseRq();
  disableDmaRead();

  // Restore systick
  systick_enable();

  armA1();

  if(i == count) {
    // Force a NUL terminator
    bytes[-1] = 0;
  }

  Acsi::verbose(&bytes[-i], "'\n");
}

void DmaPort::sendDma(const uint8_t *bytes, int count) {
  Acsi::verbose("DMA send ");
  Acsi::verboseDump(&bytes[0], count);

  resetTimeout();

  // Disable systick that introduces jitter.
  systick_disable();

  enableAckFilter();

  acquireDataBus();
  acquireDrq();

  // Unroll for speed
  int i = 0;
#if ACSI_FAST_DMA
#if ACSI_FAST_DMA == 1
#define ACSI_SEND_BYTE(b) do { \
      writeData(bytes[b]); \
      triggerDrq(); \
      writeData(bytes[b]); \
      if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
          while(!ackReceived()) \
            checkReset(); \
    } while(0)
#elif ACSI_FAST_DMA == 2
#define ACSI_SEND_BYTE(b) do { \
      writeData(bytes[b]); \
      writeData(bytes[b]); \
      triggerDrq(); \
      if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
          while(!ackReceived()) \
            checkReset(); \
    } while(0)
#elif ACSI_FAST_DMA == 3
#define ACSI_SEND_BYTE(b) do { \
      writeData(bytes[b]); \
      triggerDrq(); \
      if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
          while(!ackReceived()) \
            checkReset(); \
    } while(0)
#elif ACSI_FAST_DMA == 4
#define ACSI_SEND_BYTE(b) do { \
      triggerDrq(); \
      writeData(bytes[b]); \
      writeData(bytes[b]); \
      if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
          while(!ackReceived()) \
            checkReset(); \
    } while(0)
#else
#define ACSI_SEND_BYTE(b) do { \
      triggerDrq(); \
      writeData(bytes[b]); \
      if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
          while(!ackReceived()) \
            checkReset(); \
    } while(0)
#endif
  for(i = 0; i <= count - 16; i += 16) {
    ACSI_SEND_BYTE(0);
    ACSI_SEND_BYTE(1);
    ACSI_SEND_BYTE(2);
    ACSI_SEND_BYTE(3);
    ACSI_SEND_BYTE(4);
    ACSI_SEND_BYTE(5);
    ACSI_SEND_BYTE(6);
    ACSI_SEND_BYTE(7);
    ACSI_SEND_BYTE(8);
    ACSI_SEND_BYTE(9);
    ACSI_SEND_BYTE(10);
    ACSI_SEND_BYTE(11);
    ACSI_SEND_BYTE(12);
    ACSI_SEND_BYTE(13);
    ACSI_SEND_BYTE(14);
    ACSI_SEND_BYTE(15);
    bytes += 16;
    resetTimeout();
  }
#undef ACSI_SEND_BYTE
#endif

  while(i < count) {
    writeData(*bytes); // Put data on the bus
    writeData(*bytes); // Glitch workaround
    triggerDrq(); // Trigger DRQ
    while(!ackReceived()) // Wait for ACK
      checkReset();
    ++i;
    ++bytes;
    resetTimeout();
  }

  releaseRq();
  releaseDataBus();

  // Restore systick
  systick_enable();

  armA1();

  Acsi::verbose(" OK\n");
}

void DmaPort::fillDma(uint8_t byte, int count) {
  Acsi::verboseHex("DMA fill ", count, " bytes with ", byte, '\n');

  resetTimeout();

  // Disable systick that introduces jitter.
  systick_disable();

  enableAckFilter();

  acquireDataBus();
  acquireDrq();

  writeData(byte);

  // Unroll for speed
  int i = 0;
#if ACSI_FAST_DMA
#define ACSI_FILL_BYTE(b) do { \
      triggerDrq(); \
      checkReset(); \
      if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
        if(!ackReceived()) \
          while(!ackReceived()) \
            checkReset(); \
    } while(0)
  for(i = 0; i <= count - 16; i += 16) {
    ACSI_FILL_BYTE(0);
    ACSI_FILL_BYTE(1);
    ACSI_FILL_BYTE(2);
    ACSI_FILL_BYTE(3);
    ACSI_FILL_BYTE(4);
    ACSI_FILL_BYTE(5);
    ACSI_FILL_BYTE(6);
    ACSI_FILL_BYTE(7);
    ACSI_FILL_BYTE(8);
    ACSI_FILL_BYTE(9);
    ACSI_FILL_BYTE(10);
    ACSI_FILL_BYTE(11);
    ACSI_FILL_BYTE(12);
    ACSI_FILL_BYTE(13);
    ACSI_FILL_BYTE(14);
    ACSI_FILL_BYTE(15);
    resetTimeout();
  }
#undef ACSI_FILL_BYTE
#endif

  while(i < count) {
    triggerDrq(); // Trigger DRQ
    while(!ackReceived()) // Wait for ACK
      checkReset();
    ++i;
    resetTimeout();
  }

  releaseRq();
  releaseDataBus();

  // Restore systick
  systick_enable();

  armA1();

  Acsi::verbose(" OK\n");
}

jmp_buf DmaPort::resetJump;

void DmaPort::resetTimeout() {
  // Give 500ms to react
  TIMEOUT_TIMER->CNT = 65535 - PORT_TIMEOUT;

  // Just check if the reset line was already pulled
  checkReset();
}

void DmaPort::checkReset() {
#if ACSI_HAS_RESET
  if(RESET_TIMER->SR & TIMER_SR_TIF)
    quickReset();
#endif
  if(TIMEOUT_TIMER->CNT < 65535 - PORT_TIMEOUT)
    quickReset();
}

void DmaPort::setupGpio() {
  releaseRq();
  releaseDataBus();
  GPIOA->regs->ODR |= RST_MASK | DRQ_MASK; // Set DRQ as pullup when active
}

void DmaPort::setupResetTimer() {
#if ACSI_HAS_RESET
  RESET_TIMER->CR1 = 0;

  RESET_TIMER->SMCR = TIMER_SMCR_TS_TI1FP1 | TIMER_SMCR_SMS_RESET;
  RESET_TIMER->CCER = TIMER_CCER_CC1P | TIMER_CCER_CC1E;

  RESET_TIMER->SR = 0;
  RESET_TIMER->CR1 = TIMER_CR1_CEN;
#endif

  // Reset values so CCR1 and CCMR1 can be written to.
  TIMEOUT_TIMER->CCER = 0;
  TIMEOUT_TIMER->CCMR1 = 0;

  // 1ms period.
  TIMEOUT_TIMER->PSC = 36000;

  TIMEOUT_TIMER->ARR = 65535;
  TIMEOUT_TIMER->CNT = 65535 - PORT_TIMEOUT;

  // Update and enable the timer
  TIMEOUT_TIMER->EGR |= TIMER_EGR_UG;
  TIMEOUT_TIMER->CR1 |= TIMER_CR1_CEN;
}

void DmaPort::setupCsTimer() {
  CS_TIMER->CR1 = TIMER_CR1_URS;
  CS_TIMER->SMCR = TIMER_SMCR_SMS_ENCODER2;
  CS_TIMER->CCMR1 = TIMER_CCMR1_CC1S_INPUT_TI1
#if ACSI_CS_FILTER
                    | ((ACSI_CS_FILTER) << 4)
#endif
                    | TIMER_CCMR1_CC2S_INPUT_TI2;
  CS_TIMER->CCMR2 = TIMER_CCMR2_OC3M;
  CS_TIMER->CCER |= TIMER_CCER_CC1P | TIMER_CCER_CC2P;
  CS_TIMER->PSC = 0;
  CS_TIMER->ARR = 65535;
  CS_TIMER->DIER = TIMER_DIER_CC3DE | TIMER_DIER_UDE;
  CS_TIMER->CCR1 = 0;
  CS_TIMER->CCR2 = 0;
  CS_TIMER->CCR3 = 1; // Detects A1
  CS_TIMER->CCR4 = 0; // Receives PORTB on CS pulse
  CS_TIMER->EGR |= TIMER_EGR_UG; // Update the timer

  // Setup DMA to copy PORTB to CCR4 on CS+A1 pulse
  DMA1_BASE->CCR5 &= ~DMA_CCR_EN;
  DMA1_BASE->CPAR5 = (uint32_t)&(CS_TIMER->CCR4);
  DMA1_BASE->CMAR5 = (uint32_t)&(GPIOB->regs->IDR);
  DMA1_BASE->CNDTR5 = 1;
  DMA1_BASE->CCR5 = DMA_CCR_PL_LOW
                    | DMA_CCR_MSIZE_16BITS
                    | DMA_CCR_PSIZE_16BITS
                    | DMA_CCR_CIRC
                    | DMA_CCR_DIR
                    | DMA_CCR_EN;

  // Setup DMA to copy PORTB to CCR4 on CS pulse
  DMA1_BASE->CCR7 &= ~DMA_CCR_EN;
  DMA1_BASE->CPAR7 = (uint32_t)&(CS_TIMER->CCR4);
  DMA1_BASE->CMAR7 = (uint32_t)&(GPIOB->regs->IDR);
  DMA1_BASE->CNDTR7 = 1;
  DMA1_BASE->CCR7 = DMA_CCR_PL_LOW
                    | DMA_CCR_MSIZE_16BITS
                    | DMA_CCR_PSIZE_16BITS
                    | DMA_CCR_CIRC
                    | DMA_CCR_DIR
                    | DMA_CCR_EN;
}

void DmaPort::setupDrqTimer() {
  DMA_TIMER->CR1 = TIMER_CR1_OPM;
  DMA_TIMER->CR2 = 0;
  DMA_TIMER->SMCR = 
#if ACSI_ACK_FILTER
    ((ACSI_ACK_FILTER) << 8) |
#endif
    TIMER_SMCR_ETP | TIMER_SMCR_TS_ETRF | TIMER_SMCR_SMS_EXTERNAL;
  DMA_TIMER->PSC = 0; // Prescaler
  DMA_TIMER->ARR = 65535; // Overflow (0 = counter stopped)
  DMA_TIMER->DIER = TIMER_DIER_CC3DE;
  DMA_TIMER->CCMR1 = 0;
  DMA_TIMER->CCMR2 = TIMER_CCMR2_OC4M;
  DMA_TIMER->CCER = TIMER_CCER_CC4E; // Enable output
  DMA_TIMER->EGR = TIMER_EGR_UG;
  DMA_TIMER->CCR1 = 0; // Receives PORTB on ACK pulse
  DMA_TIMER->CCR2 = 65535; // Disable unused CC channel
  DMA_TIMER->CCR3 = 1; // Compare value
  DMA_TIMER->CCR4 = 1; // Compare value
  DMA_TIMER->CNT = 2;
  DMA_TIMER->CR1 |= TIMER_CR1_CEN;

  // Initialize DMA engine
  RCC_BASE->AHBENR |= RCC_AHBENR_DMA1EN;
}

void DmaPort::enableDmaRead() {
  // Setup the DMA engine to copy GPIOB to timer 1 CH1 compare value
  DMA1_BASE->CCR6 &= ~DMA_CCR_EN;
  DMA1_BASE->CPAR6 = (uint32_t)&(DMA_TIMER->CCR1);
  DMA1_BASE->CMAR6 = (uint32_t)&(GPIOB->regs->IDR);
  DMA1_BASE->CNDTR6 = 1;
  DMA1_BASE->CCR6 = DMA_CCR_PL_VERY_HIGH
                    | DMA_CCR_MSIZE_16BITS
                    | DMA_CCR_PSIZE_16BITS
                    | DMA_CCR_CIRC
                    | DMA_CCR_DIR
                    | DMA_CCR_EN;
}

void DmaPort::disableDmaRead() {
  // Disable the DMA channel 6
  DMA1_BASE->CCR6 = 0;
  DMA1_BASE->CPAR6 = 0;
  DMA1_BASE->CMAR6 = 0;
  DMA1_BASE->CNDTR6 = 0;
}

void DmaPort::quickReset() {
  // Restore systick
  systick_enable();

  // Disable DMA read
  disableDmaRead();

  // Release all pins to neutral
  setupGpio();

  // Leave some time for pull-ups to do their work
  delayMicroseconds(50);

  // Display a nice message
  Acsi::dbg("\n\n--- Quick reset ---\n\n");

  // Jump back to the main loop
  longjmp(resetJump, 1);
}

bool DmaPort::idle() {
#if ACSI_HAS_RESET
  static const int idleMask = IRQ_MASK | DRQ_MASK | ACK_MASK | RST_MASK;
#else
  static const int idleMask = IRQ_MASK | DRQ_MASK | ACK_MASK;
#endif
  return (GPIOA->regs->IDR & idleMask) == idleMask && csUp();
}

void DmaPort::waitIdle() {
  // Super fast polling
  if(idle())
    return;
  if(idle())
    return;
  if(idle())
    return;
  if(idle())
    return;
  if(idle())
    return;
  if(idle())
    return;

  // Poll in a more controlled fashion
  for(int i = 0; i < 5; ++i) {
    delayMicroseconds(1);
    if(idle())
      return;
  }

  quickReset();
}

void DmaPort::armA1() {
  waitCsUp();
  CS_TIMER->CNT = 0;
  CS_TIMER->CR1 = (CS_TIMER->CR1 & ~TIMER_CR1_OPM) | TIMER_CR1_CEN;
  DMA1_BASE->IFCR = DMA_IFCR_CTCIF5 | DMA_IFCR_CTCIF7; // Clear A1+CS received flags
}

void DmaPort::armCs() {
  waitCsUp();
  CS_TIMER->CNT = 0;
  CS_TIMER->CR1 |= TIMER_CR1_OPM | TIMER_CR1_CEN;
#if ACSI_A1_WORKAROUND
  DMA1_BASE->IFCR = DMA_IFCR_CTCIF5 | DMA_IFCR_CTCIF7; // Clear A1+CS received flags
#else
  DMA1_BASE->IFCR = DMA_IFCR_CTCIF7; // Clear CS received flag
#endif
}

void DmaPort::pullIrq() {
  GPIOA->regs->CRH = 0x84444BB3;
}

void DmaPort::releaseRq() {
  GPIOA->regs->CRH = 0x84444BB4; // Set ACK, IRQ and DRQ as inputs
}

bool DmaPort::irqUp() {
  return (GPIOA->regs->IDR & IRQ_MASK) == IRQ_MASK;
}

void DmaPort::waitIrqUp() {
  // Quick check
  if(irqUp())
    return;
  if(irqUp())
    return;
  if(irqUp())
    return;
  if(irqUp())
    return;
  if(irqUp())
    return;

  // Poll in a more controlled fashion
  for(int i = 0; i < 5; ++i) {
    delayMicroseconds(1);
    checkReset();
    if(irqUp())
      return;
  }

  quickReset();
}

bool DmaPort::csUp() {
  static const int csMask = A1_MASK | CS_MASK;
  return (GPIOB->regs->IDR & csMask) == csMask;
}

void DmaPort::waitCsUp() {
  // Quick check
  if(csUp())
    return;
  if(csUp())
    return;
  if(csUp())
    return;

  // Poll in a more controlled fashion
  resetTimeout();
  for(int i = 0; i < 5; ++i) {
    delayMicroseconds(1);
    checkReset();
    if(csUp())
      return;
  }

  quickReset();
}

bool DmaPort::checkCs() {
#if ACSI_A1_WORKAROUND
  return DMA1_BASE->ISR & (DMA_ISR_TCIF5 | DMA_ISR_TCIF7);
#else
  if(checkCommand())
    // Spurious A1 pulse: reset
    quickReset();

  return DMA1_BASE->ISR & DMA_ISR_TCIF7;
#endif
}

void DmaPort::waitCs() {
  while(!checkCs())
    checkReset();
}

uint8_t DmaPort::csData() {
  return (CS_TIMER->CCR4) >> 8;
} 

void DmaPort::armDma() {
  DMA1_BASE->IFCR = DMA_IFCR_CTCIF6; // Reset DMA transfer flag
}

void DmaPort::acquireDrq() {
  // Set DRQ to high using timer PWM
  DMA_TIMER->CNT = 2;

  // Transition through input pullup to avoid a hardware glitch
  GPIOA->regs->CRH = 0x84448BB4;

  // Enable timer PWM output to DRQ
  GPIOA->regs->CRH = 0x8444BBB4;
}

void DmaPort::triggerDrq() {
  DMA_TIMER->CNT = 0;
}

bool DmaPort::checkDma() {
  return DMA1_BASE->ISR & DMA_ISR_TCIF6;
}

uint8_t DmaPort::dmaData() {
  return (DMA_TIMER->CCR1) >> 8;
} 

bool DmaPort::ackReceived() {
  return DMA_TIMER->CNT;
}

void DmaPort::disableAckFilter() {
  DMA_TIMER->SMCR = TIMER_SMCR_ETP | TIMER_SMCR_TS_ETRF | TIMER_SMCR_SMS_EXTERNAL;
}

void DmaPort::enableAckFilter() {
  DMA_TIMER->SMCR = 
#if ACSI_ACK_FILTER
    ((ACSI_ACK_FILTER) << 8) |
#endif
    TIMER_SMCR_ETP | TIMER_SMCR_TS_ETRF | TIMER_SMCR_SMS_EXTERNAL;
}

void DmaPort::acquireDataBus() {
  GPIOB->regs->CRH = 0x33333333; // Set PORTB[8:15] to 50MHz push-pull output
}

void DmaPort::writeData(uint8_t byte) {
  GPIOB->regs->ODR = ((int)byte) << 8;
}

void DmaPort::releaseDataBus() {
  GPIOB->regs->CRH = 0x44444444; // Set PORTB[8:15] to input
}

// vim: ts=2 sw=2 sts=2 et
