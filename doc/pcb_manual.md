ACSI2STM PCB user manual
========================

This document describes how to install the official ACSI2STM PCB on an Atari ST.

For instructions to build this PCB, see [build_pcb.md](build_pcb.md).

For instructions on how to use the ACSI2STM, see [manual.md](manual.md).

![Picture of a fully installed unit](images/unit_installed.jpg)


Installing the PCB
==================

Installing the PCB can be a bit tricky, especially inserting floppy pins.

 * Plug the unit on the back of the ST. The mounting holes of the Hard Disk
   socket should be aligned.

 * Put some screws to hold the unit in place.
   If you need screws, you can unscrew the hex screws of the Modem or Printer
   socket.


Powering the PCB
================

**WARNING**: Never plug 2 power sources at the same time.

You have several options to power the PCB.

 * Use a 5V DC jack, center pin positive.
 * Use a standard PC floppy power cable plugged in J1, red wire up.
 * Use a compatible USB TO TTL USART adapter. You need to put a jumper on J4 to
   use power from the USB converter.
 * Power via the onboard USB jack of the blue pill. For this you need to make
   some modifications on the blue pill itself, see [hardware.md](hardware.md)


Installing a PC floppy drive
============================

You can optionally install a standard PC floppy drive or a floppy emulator on
the standard 34-pin connector. This will appear as drive B on the ST.

To use this floppy as drive A, a hardware modification of the ST is required.

The PCB supports both straight and twisted ribbon cables by setting S1
accordingly.


Flashing firmware
=================

To upgrade the ACSI2STM firmware, you need a compatible USB to USART converter.

![Compatible USART adapter](images/usb_serial.jpg)

The PCB offers a slot to directly plug the adapter.

If you power the ACSI2STM from the adapter, unplug all other power sources and
put a jumper on J4. If you power the ACSI2STM from an external source, make sure
that J4 is removed.

Set the Blue Pill jumpers to the firmware flash position, then press reset:

     _______________________________
    |                     _         |
    |    o [==]       /\ | |       -|--
    |   [==] o       /  \| |       -|--
    |                \  /| |       -|--
    |     (o)         \/ |_|       -|--
    |_______________________________|


Now, the STM32 is in firmware flash mode. Use the *stm32flash* command to upload
the new firmware:

    stm32flash -w acsi2stm-3.00.ino.bin /dev/ttyUSB0

`acsi2stm-3.00.ino.bin` is the firmware to flash and `/dev/ttyUSB0` is the
serial device connected to the blue pill.

You can also use the Arduino IDE if it is properly set up. See
[compiling.md](compiling.md) for  more information.

