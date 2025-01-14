/* ACSI2STM Atari hard drive emulator
 * Copyright (C) 2019-2025 by Jean-Matthieu Coulon
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

#include "FlashFirmware.h"

#include "DmaPort.h"
#include "Monitor.h"

#include <libmaple/dma.h>
#include <libmaple/flash.h>
#include <libmaple/pwr.h>
#include <libmaple/rcc.h>
#include <libmaple/scb.h>

#define DMA_TIMER TIMER1_BASE
#define RESET_TIMER TIMER2_BASE
#define TIMEOUT_TIMER TIMER3_BASE
#define CS_TIMER TIMER4_BASE

static const uint32_t FLASH_START = 0x08000000;

#if ACSI_PIO

// This function runs from RAM. It cannot access flash memory so it's all
// low-level register manipulation.
// Most of this code is copy-paste from DmaPort.
// Because ramfunc seems to be broken, the function is put in the data section.
void __attribute__((section(".data"))) updateFirmwareFromPIO(uint32_t address, uint32_t end_address) {
  // Cache all indirect pointers and values to avoid flash access
  auto *GPIOA_REGS_CRH = &GPIOA->regs->CRH;
  auto *GPIOB_REGS_CRH = &GPIOB->regs->CRH;
  auto *GPIOB_REGS_ODR = &GPIOB->regs->ODR;
#if ACSI_ACTIVITY_LED
  auto *GPIOC_REGS_BSRR = &GPIOC->regs->BSRR;
  auto *GPIOC_REGS_BRR = &GPIOC->regs->BRR;
  *GPIOC_REGS_BSRR = 1 << 13;
#endif

#if ! ACSI_FAKE_FLASH_FIRMWARE
  // Erase flash
  while(FLASH_BASE->SR & FLASH_SR_BSY);
  FLASH_BASE->CR |= FLASH_CR_MER;
  FLASH_BASE->CR |= FLASH_CR_STRT;
  while(FLASH_BASE->SR & FLASH_SR_BSY);
  FLASH_BASE->CR &= ~FLASH_CR_MER;
#endif

#if ACSI_ACTIVITY_LED
  *GPIOC_REGS_BRR = 1 << 13;
#endif

  // Write new flash data
  for(; address < end_address; address += 2) {
    uint16_t data = 0;

#if ACSI_ACTIVITY_LED
    *GPIOC_REGS_BSRR = 1 << 13;
#endif

    // Read first byte

    // armCs
    CS_TIMER->CNT = 0;
    CS_TIMER->CR1 |= TIMER_CR1_OPM | TIMER_CR1_CEN;
    DMA1_BASE->IFCR = DMA_IFCR_CTCIF7;
    // pullIrq
    GPIOA->regs->CRH = 0x84444BB3;
    // waitCs
    while(!(DMA1_BASE->ISR & DMA_ISR_TCIF7));
    // releaseRq
    GPIOA->regs->CRH = 0x84444BB4;
    // csData()
    data = ((CS_TIMER->CCR4) >> 8) & 0xff;

#if ACSI_ACTIVITY_LED
    *GPIOC_REGS_BRR = 1 << 13;
#endif

    // Read second byte

    // armCs
    CS_TIMER->CNT = 0;
    CS_TIMER->CR1 |= TIMER_CR1_OPM | TIMER_CR1_CEN;
    DMA1_BASE->IFCR = DMA_IFCR_CTCIF7;
    // pullIrq
    GPIOA->regs->CRH = 0x84444BB3;
    // waitCs
    while(!(DMA1_BASE->ISR & DMA_ISR_TCIF7));
    // releaseRq
    GPIOA->regs->CRH = 0x84444BB4;
    // csData()
    data |= (CS_TIMER->CCR4) & 0xff00;

#if ! ACSI_FAKE_FLASH_FIRMWARE
    // Write halfword to flash
    FLASH_BASE->CR |= FLASH_CR_PG;
    *(__IO uint16_t*)(address) = data;
    while(FLASH_BASE->SR & FLASH_SR_BSY);
#endif
  }

  // Enable the reset control register access
  RCC_BASE->APB1ENR |= RCC_APB1ENR_PWREN;
  PWR_BASE->CR |= PWR_CR_DBP;
  // Set the system reset bit
  SCB_BASE->AIRCR = 0x05FA0004;
  for(;;);
}

// Flashes firmware from the DMA port, then reset.
// Never returns.
void flashFirmware(uint32_t size) {
  DmaPort::resetTimeout();
  systick_disable();

#if ACSI_ACTIVITY_LED
  GPIOC->regs->CRH |= 0x00300000; // Set PC13 to 50MHz push-pull output
  GPIOC->regs->BRR = 1 << 13;
#endif

#if ! ACSI_FAKE_FLASH_FIRMWARE
  // Unlock flash
  FLASH_BASE->KEYR = 0x45670123;
  FLASH_BASE->KEYR = 0xCDEF89AB;
#else
  Monitor::dbg("FAKING ");
#endif

  Monitor::dbg("Flash ", size, " bytes at ");
  Monitor::dbgHex(FLASH_START, '\n');

  // The rest must be executed from RAM
  updateFirmwareFromPIO(FLASH_START, FLASH_START + size);
}

#else

// This function runs from RAM. It cannot access flash memory so it's all
// low-level register manipulation.
// Most of this code is copy-paste from DmaPort.
// Because ramfunc seems to be broken, the function is put in the data section.
void __attribute__((section(".data"))) updateFirmwareFromDMA(uint32_t address, uint32_t end_address) {
  // Cache all indirect pointers and values to avoid flash access
  auto *GPIOA_REGS_CRH = &GPIOA->regs->CRH;
  auto *GPIOB_REGS_CRH = &GPIOB->regs->CRH;
  auto *GPIOB_REGS_ODR = &GPIOB->regs->ODR;
#if ACSI_ACTIVITY_LED
  auto *GPIOC_REGS_BSRR = &GPIOC->regs->BSRR;
  auto *GPIOC_REGS_BRR = &GPIOC->regs->BRR;
  *GPIOC_REGS_BSRR = 1 << 13;
#endif

#if ! ACSI_FAKE_FLASH_FIRMWARE
  // Erase flash
  while(FLASH_BASE->SR & FLASH_SR_BSY);
  FLASH_BASE->CR |= FLASH_CR_MER;
  FLASH_BASE->CR |= FLASH_CR_STRT;
  while(FLASH_BASE->SR & FLASH_SR_BSY);
  FLASH_BASE->CR &= ~FLASH_CR_MER;
#endif

#if ACSI_ACTIVITY_LED
  *GPIOC_REGS_BRR = 1 << 13;
#endif

  // Write new flash data
  for(; address < end_address; address += 2) {
    uint16_t data = 0;

#if ACSI_ACTIVITY_LED
    *GPIOC_REGS_BSRR = 1 << 13;
#endif

    // Read first byte
    DMA1_BASE->IFCR = DMA_IFCR_CTCIF6; // armDma()
    DMA_TIMER->CNT = 0; // triggerDrq()
    while(!(DMA1_BASE->ISR & DMA_ISR_TCIF6)); // while(!checkDma());
    data = ((DMA_TIMER->CCR1) >> 8) & 0xff; // dmaData()

#if ACSI_ACTIVITY_LED
    *GPIOC_REGS_BRR = 1 << 13;
#endif

    // Read second byte
    DMA1_BASE->IFCR = DMA_IFCR_CTCIF6; // armDma()
    DMA_TIMER->CNT = 0; // triggerDrq()
    while(!(DMA1_BASE->ISR & DMA_ISR_TCIF6)); // while(!checkDma());
    data |= DMA_TIMER->CCR1 & 0xff00; // dmaData()

#if ! ACSI_FAKE_FLASH_FIRMWARE
    // Write halfword to flash
    FLASH_BASE->CR |= FLASH_CR_PG;
    *(__IO uint16_t*)(address) = data;
    while(FLASH_BASE->SR & FLASH_SR_BSY);
#endif
  }

  // Send success byte to the ST and release the DMA port
  *GPIOB_REGS_CRH = 0x33333333; // acquireDataBus()
  *GPIOB_REGS_ODR = 0; // writeData(0)
  CS_TIMER->CNT = 0; // armCs()
  CS_TIMER->CR1 |= TIMER_CR1_OPM | TIMER_CR1_CEN;
  DMA1_BASE->IFCR = DMA_IFCR_CTCIF5 | DMA_IFCR_CTCIF7;
  *GPIOA_REGS_CRH = 0x84444BB3; // pullIrq()
  while(!(DMA1_BASE->ISR & DMA_ISR_TCIF7)); // waitCs()
  *GPIOA_REGS_CRH = 0x84444BB4; // releaseRq()
  *GPIOB_REGS_CRH = 0x44444444; // releaseDataBus()

  // Enable the reset control register access
  RCC_BASE->APB1ENR |= RCC_APB1ENR_PWREN;
  PWR_BASE->CR |= PWR_CR_DBP;
  // Set the system reset bit
  SCB_BASE->AIRCR = 0x05FA0004;
  for(;;);
}

// Flashes firmware from the DMA port, then reset.
// Never returns.
void flashFirmware(uint32_t size) {
  DmaPort::resetTimeout();
  systick_disable();
  DmaPort::disableAckFilter();
  DmaPort::enableDmaRead();
  DmaPort::acquireDrq();

#if ACSI_ACTIVITY_LED
  GPIOC->regs->CRH |= 0x00300000; // Set PC13 to 50MHz push-pull output
  GPIOC->regs->BRR = 1 << 13;
#endif

#if ! ACSI_FAKE_FLASH_FIRMWARE
  // Unlock flash
  FLASH_BASE->KEYR = 0x45670123;
  FLASH_BASE->KEYR = 0xCDEF89AB;
#else
  Monitor::dbg("FAKING ");
#endif

  Monitor::dbg("Flash ", size, " bytes at ");
  Monitor::dbgHex(FLASH_START, '\n');

  // The rest must be executed from RAM
  updateFirmwareFromDMA(FLASH_START, FLASH_START + size);
}

#endif

// vim: ts=2 sw=2 sts=2 et
