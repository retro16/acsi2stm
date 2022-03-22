*Version 2.4: Hardware configuration and asm programming.*

**WARNING**, PA15 was remapped to PB5 since 2.31. It should not impact anyone as this version is recent and PA15 is for SD card 5.


ACSI2STM: Atari ST ACSI hard drive emulator
===========================================

This code provides a hard drive emulator for your Atari ST using an inexpensive STM32 microcontroller and a SD card.

The aim of this project is to be very easy to build, extremely cheap, reliable and safe for your precious vintage machine.

The module supports up to 5 SD card readers, showing them as 5 different ACSI devices plugged in. You can choose the ACSI
ID of each SD card by soldering CS wires on the matching STM32 pin.

It can work in 2 ways:
 * Expose a raw SD card as a hard disk to the Atari.
 * Expose a hard disk image file on a standard SD card to the Atari.

It also supports an UltraSatan compatible real-time clock.

**WARNING**, the pinout has changed since version 1.0. If you built or bought a unit for the 1.0 firmware, you need to make changes.

Documentation
-------------

The doc directory provides documentation for the end-user as well as hardware implementors or curious people.

This is what you can find:

 * [manual.md](doc/manual.md): A brief user manual for people owning a unit. Also explains how to install the ICD PRO driver.
 * [compiling.md](doc/compiling.md): A step-by-step tutorial to compile and upload a new firmware. Also includes how to customize
   the firmware for non-developers by changing compile-time options.
 * [hardware.md](doc/hardware.md): How to build an acsi2stm unit.
 * [debug_output.txt](doc/debug_output.txt): A sample output of the logs you should get when booting a SD card.


To people buying/selling hardware
---------------------------------

There are people building and selling products based on this code. This project is not directly related to any of these people.
There is no official hardware beyond the "blue pill" STM32 board and its variants.

Building and selling units is encouraged, as long as the spirit of free software is preserved and the terms of the license are
respected.

The code here is released under the GPLv3 license (see LICENSE file). This has some implications:

 * If you sell any product based on this code, you **must** provide a link to the source.
 * If you sell any product based on a modified version of this code, or reusing parts of this code, you **must** provide a link to
   the whole source code of the modified version with the product, including any additional features/modules you may have added.
 * If you redistribute binary versions (modified or not), you **must** provide a link to the source code matching exactly the
   binary you redistribute.
 * Any modified version must retain the GPLv3 or a compatible license.
 * The name ACSI2STM is not protected. You can reuse it as you wish. Making a clear distinction between this code and your product
   will be greatly appreciated (most sellers are).
 * If you bought a product that contains code based on this project (modified or not), you can request the source code to the
   firmware contained in your product. The seller/maker of the product is legally required to provide it.


Credits
-------

I would like to thanks the people that put invaluable information online that made this project possible in a finite amount of
time. Without them, this project would have not existed.

 * The http://atari.8bitchip.info website and his author, who also contributes on various forums.
 * The Hatari developpers. I used its source code as a reference for ACSI commands.
 * The UltraSatan project for their documentation and their RTC clock tool.
 * Sr Antonio, Edu Arana, Frederick321, Ulises74, Maciej G., Olivier Gossuin, Marcel Prisi and Tomasz Orczyk for their very
   detailed feedback that helped me a lot for fine tuning the DRQ/ACK signals and other various aspects of the projects.
 * All people contributing on GitHub, for their code, their ideas, the issues they submit, and their patience when things fail !
