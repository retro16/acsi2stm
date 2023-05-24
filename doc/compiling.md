Compiling and installing a new firmware
=======================================

Software needed
---------------

* The Arduino software with the Roger Clark Melbourne STM32 library.
* This is *NOT* compatible with the official STM32duino library: you need
  Clark's variant.
* The SdFat AdaFruit Fork Arduino library.


Installing software
-------------------

Install the [STM32 library](https://github.com/rogerclarkmelbourne/Arduino_STM32/wiki/Installation).
The doc says that it only works on Arduino 1.8.5 but that works with more
recent versions too, including Arduino 2.x.

In the Tools / Manage Libraries menu of the Arduino interface, search for
"SdFat" and install "SdFat - AdaFruit Fork".

In the Tools menu of the Arduino interface, select the following:

* Board: Generic STM32F103C series
* Variant: STM32F103C8
* Upload method: Serial
* CPU speed: 72MHz (normal)
* Optimize: Smallest (default)
* Port: your USB serial dongle

If you have different options in the Tools menu, it may be because you don't
have the correct board installed.

Then, you will be able to upload the program to the STM32.


Programming the STM32
---------------------

Set the USB dongle to 3.3V if you have a jumper for that. Connect TX to PA10, RX
to PA9 and the GND pins together.

On the board itself, set the BOOT0 jumper to 1 to enable the serial flash
bootloader. Reset the STM32 then click Upload.

Once the chip is programmed, switch the BOOT0 jumper back to 0.

**Notes**

The debug output sends data at 2Mbps. Set the serial monitor accordingly.

Programming via anything else than the serial bootloader may require to change
debug output to Serial0 and may consume more RAM. Serial programming is still
the only supported upload method.


Compile-time options
--------------------

The file acsi2stm.h contains a few #define that you can change. They are
described in the source itself.

Settings that you might wish to change:

* ACSI_DEBUG: Enables debug output on the serial port. Moderate performance
  penalty.
* ACSI_VERBOSE: Requires ACSI_DEBUG. Logs all commands on the serial port. High
  performance penalty.
* ACSI_DUMP_LEN: Requires ACSI_VERBOSE. Dumps N bytes for each DMA transfer. It
  helps finding data corruption. Even higher performance penalty.
* ACSI_SERIAL: The serial port used for debug output.
* ACSI_SD_CARDS: Set this to the number of physical SD card slots you have.
* ACSI_STRICT: If set to 1, forces ACSI mode all the time.
* ACSI_READONLY: Make all cards read-only. Acsi2stm becomes strictly unable to
  modify SD cards.
* ACSI_SD_MAX_SPEED: Maximum SD card speed in MHz. If SD communication fails,
  the driver automatically retries at a lower speed.
* ACSI_HAS_RESET: If set to 0, ignores the RST signal on PA15. If set to 1,
  quickly resets the unit when RST is activated.
* ACSI_ACK_FILTER: Enables filtering the ACK line, adding a tiny latency. May
  improve DMA reliability at the expense of speed.
* ACSI_CS_FILTER: Enables filtering on the CS line, adding a tiny latency. This
  is necessary to sample the data bus at the right time. Adjust this if
  commands are corrupt.
* ACSI_FAST_DMA: If set to 1, unroll DMA code for faster performance. Fast
  timings may not be compatible with some ST DMA chips. You can try values
  between 2 and 5 for even faster performance, but this is glitchy.
* ACSI_A1_WORKAROUND: Add a workaround for drivers that retrigger the A1
  line in the middle of a command (including TOS 1.00). Makes commands a
  bit unsafe, especially for fast device.
* ACSI_GEMDRIVE_FIRST_LETTER: Set the first drive letter GemDrive will use.
* ACSI_GEMDRIVE_UPPER_CASE: Convert all names to upper case. If disabled,
  make GemDrive case insensitive.
* ACSI_GEMDRIVE_FALLBACK_CHAR: Replace any incompatible character with this one.
  If disabled, hide any file containing incompatible characters.
* ACSI_GEMDRIVE_HIDE_NON_8_3: Hide any file that don't fit the 8.3 characters
  pattern. No Atari file should be non-8.3 anyway.


Rebuilding ASM code
-------------------

The `build_asm.sh` shell script rebuilds all files in asm subfolders. You need
vasm and xxd installed. This regenerates header files in the acsi2stm folder for
GemDrive.

The script is meant to run in bash under Linux. It may or may not run under
cygwin, git bash or macos (untested).


Building a release package
--------------------------

The `build_release.sh` shell script patches VERSION in all sources, calls
`build_asm.sh` and `build_arduino.sh`, then packages everything into a zip file.
For now, Arduino 1.xx is required.

