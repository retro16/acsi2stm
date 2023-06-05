ACSI2STM: Atari ST ACSI hard drive emulator
===========================================

This code provides a hard drive emulator for your Atari ST using an inexpensive
STM32 microcontroller and a SD card.

The aim of this project is to be very easy to build, extremely cheap, reliable
and safe for your precious vintage machine.

The module supports up to 5 SD card readers, showing them as 5 different ACSI
devices plugged in.

It can work in 3 ways:

* Expose a raw SD card as a hard disk to the Atari.
* Expose a floppy or hard disk image file on a standard SD card to the Atari.
* Mount a standard SD card on the Atari.

It also provides an UltraSatan compatible real-time clock if you add a simple
3V lithium battery such as a CR2032.

See [RELEASE NOTES](release_notes.md) for details about the current version.

**WARNING**, the pinout has changed for version 3.xx and above. If you built or
bought a unit for older 1.xx, you need to make changes. If you have a 2.xx unit,
use the "legacy" firmware image or make hardware changes. See the last section
of [hardware.md](doc/hardware.md) for more information.


Documentation
-------------

The *doc* directory provides documentation for the end-user as well as hardware
implementors or curious people.

This is what you can find:

* [manual.md](doc/manual.md): A brief user manual for people owning a unit.
* [flashing.md](doc/flashing.md): A tutorial on how to download and flash a
  firmware into a STM32. For first time users or for upgrading a pre-built
  unit.
* [compiling.md](doc/compiling.md): A step-by-step tutorial to compile and
  customize a new firmware. Describes compilation options.
* [pcb_manual.md](doc/pcb_manual.md): User manual for the official PCB.
* [build_pcb.md](doc/build_pcb.md): Instructions for building a unit using
  the official PCB.
* [hardware.md](doc/hardware.md): How to design and build an acsi2stm unit
  from scratch (hand wired, or your own PCB design).
* [gemdrive.md](doc/gemdrive.md): Technical details about GemDrive.
* [protocols.md](doc/protocols.md): Technical details about the communication
  protocol between the ACSI2STM unit and the Atari ST.
* [troubleshooting.md](doc/troubleshooting.md): Having problems? Have a look
  in here.


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

**Note**: the Mega STE PCB is copyrighted by Olivier Jan and is released under
the MIT license so it does not have the same restrictions.


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
