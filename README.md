ACSI2STM: Atari ST ACSI hard drive emulator
===========================================

This code provides a hard drive emulator for your Atari ST using an inexpensive
STM32 microcontroller and a SD card.

The aim of this project is to be very easy to build, extremely cheap, reliable
and safe for your precious vintage machine.

The PCB has 3 microSD card slots, and the code supports up to 5 SD card readers.

It can work in 3 ways:

* Mount standard FAT32/ExFAT SD cards on the Atari.
* Expose raw SD cards as ACSI hard disks connected to the Atari.
* Expose ACSI hard disk image files as hard disks connected to the Atari.

It also provides an UltraSatan compatible real-time clock if you add a simple
3V lithium battery such as a CR2032.

See [RELEASE NOTES](release_notes.md) for details about the current version.

The hardware is a custom PCB that can be order preassembled directly from
[JLCPCB](https://jlcpcb.com). See [quick_start](doc/quick_start.md) for more
information.

Due to many issues with counterfeit or defective Blue Pill boards online,
building new designs/units based on Blue Pill boards is discouraged.

Legacy hardware based on Blue Pill designs are supported to various degrees. All
units that were built and working between firmware 2.00 and 5.00 are and will
still be supported 100% by newer firmwares.

Documentation
-------------

The *doc* directory provides documentation for the end-user as well as hardware
implementors or curious people.

This is what you can find:

* [quick_start](doc/quick_start.md): A tutorial to order the hardware,
  flash the firmware, using the unit and upgrading the unit.
* [compatibility](doc/compatibility.md): Information about hardware, firmware
  and software compatibility.
* [troubleshooting](doc/troubleshooting.md): Having problems? Have a look
  here.
* [gemdrive](doc/gemdrive.md): Technical details about GemDrive. How to mix
  GemDrive with ACSI. How to install GemDrive for EmuTOS.
* [compiling](doc/compiling.md): A step-by-step tutorial to compile and
  customize a new firmware. Describes compilation options. Also describes
  pre-built firmware variants in the release package.
* [hardware](doc/hardware.md): How to design and build an acsi2stm unit
  from scratch (hand wired, or your own PCB design). Also documents jumper
  configuration.
* [protocols](doc/protocols.md): Technical details about the communication
  protocol between the ACSI2STM unit and the Atari ST.
* [full_pcb_manual](doc/full_pcb_manual.md): Tutorial to build and use the
  full-featured PCB. You should use the compact PCB instead if possible.


To people buying/selling hardware
---------------------------------

There are people building and selling products based on this code. This project
is not directly related to any of these people, there is no official hardware
supplier.

Building and selling units is encouraged, as long as the spirit of free software
is preserved and the terms of the license are respected.

The code here is released under the GPLv3 license (see LICENSE file). This has
some implications:

* If you bought a product that contains code based on this project (modified or
  not), you can request the source code to the firmware contained in your
  product. The seller/maker of the product is legally required to provide it.
* If you sell any product based on this code, you **must** provide a link to
  the source.
* If you sell any product based on a modified version of this code, or reusing
  parts of this code, you **must** provide a link to the whole source code of
  the modified version with the product, including any additional
  features/modules you may have added.
* If you redistribute binary versions (modified or not), you **must** provide a
  link to the source code matching exactly the binary you redistribute.
* Any modified version must retain the GPLv3 or a compatible license.
* The name ACSI2STM is not protected. You can reuse it as you wish. Making a
  clear distinction between this code and your product will be greatly
  appreciated (most sellers do).
* The code is provided without warranty, so hardware troubleshooting is best
  effort. If you bought a unit and you have issues, you should contact the
  seller first. Anyway, constructive feedback (including bug reports) is always
  appreciated.
* If a seller refuses to provide the sources, please open a GitHub issue to let
  me know.

**Note**: the Mega STE PCB is copyrighted by Olivier Jan and is released under
the MIT license so it does not have the same restrictions.

If you sell ACSI2STM units, please consider selling the new compact PCB design
instead of custom designs. If the compact design isn't to your taste, please
open a GitHub issue and talk about possible improvements.


Credits
-------

I would like to thank the people that put invaluable information online that
made this project possible in a finite amount of time. Without them, this
project would have not existed. I would also like to thank people giving
feedback, contributing to make the project better.

* Bill Greiman for the SdFat library. It's really fantastic.
* The http://atari.8bitchip.info website and his author, who also contributes
  on various forums.
* The Hatari developpers. I used its source code as a reference for ACSI
  commands, as well as the excellent GEMDOS drive implementation.
* The people who made the FreeMiNT TOS documentation.
* The EmuTOS developers, again the source code is an excellent reference.
* The UltraSatan project for their documentation and their RTC clock tool.
* Uwe Seimet for his SCSI testing tool.
* Jean-Louis Guérin (DrCoolZic) for his excellent "Atari Hard Disk File Systems
  Reference Guide".
* mamejay, Ben Leggett, S0urceror, Sr Antonio, Edu Arana, Frederick321,
  Ulises74, Maciej G., Olivier Gossuin, Marcel Prisi and Tomasz Orczyk for
  their very detailed feedback that helped me a lot for fine tuning the DRQ/ACK
  signals and other various aspects of the projects.
* All people contributing on GitHub, for their code, their ideas, the issues
  they submit, and their patience when things fail !
* Olivier Jan for the Mega STE PCB.
* Tomasz Orczyk for finding a way to have a much better version of GCC.
* Joe Ceklosky for his feedback and help on fixing RTC issues.
