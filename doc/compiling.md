Compiling and installing a new firmware
=======================================

Hardware needed
---------------

 * A STM32F103C8T6 or compatible board. You can find them for a few dollars online. The "blue pill" works out of the box and the
   older "black pill" requires minor modifications.
 * A USB-serial dongle for programming the STM32 chip, with a 3.3V USART.
 * One or more SD card port(s) for your STM32. You can also solder wires on a SD to microSD adapter.
 * One or more SD card(s).
 * A male DB19 port (you can modify a DB25 port to fit) with a ribbon cable.
 * (recommended) A protoboard PCB to solder all the components and wires together.
 * Do *NOT* connect USB data lines on the STM32. Use the +5V or +3.3V pin to power it if you are unsure.

**Notes**

Some people reported problems with STM32 clones. I have many variants of the blue pill STM32, all of them work exactly the same.
Variants I had and that worked: round and rectangle reset buttons, some chips marked STM32F / 103 and other marked STM32 / F103.
If anyone has concrete proof of misbehaving clones and information on how to spot them, feel free to contact me or create an issue
on GitHub to let people know about that.

Please provide feedback if you are trying to make this work with the new STM32F4x1 "black pill" boards. The best configuration is
to have a working blue pill so results can be compared by switching the boards (I believe they are pin compatible).


Software needed
---------------

 * The Arduino software with the Roger Clark Melbourne STM32 library.
  * This is *NOT* compatible with the official STM32duino library: you need Clark's variant.
 * The SdFat Arduino library by Bill Greiman.


Installing software
-------------------

Install the [STM32 library](https://github.com/rogerclarkmelbourne/Arduino_STM32/wiki/Installation). The doc says that it only
works on Arduino 1.8.5 but that works with more recent versions too. Arduino 2.x was not tested.

In the Tools / Manage Libraries menu of the Arduino interface, search for "SdFat" and install "SdFat by Bill Greiman".

In the Tools menu of the Arduino interface, select the following:

 * Board: Generic STM32F103C series
 * Variant: STM32F103C8
 * Upload method: Serial
 * CPU speed: 72MHz (normal)
 * Optimize: Faster (-O2)
 * Port: your USB serial dongle

**Note**: you can use any setting in the "Optimize" menu. O2 is recommended for fastest performance, O3 does not bring any speed
improvement but generates much bigger code.

If you have different options in the Tools menu, it may be because you don't have the correct board installed.

Then, you will be able to upload the program to the STM32.


Programming the STM32
---------------------

Set the USB dongle to 3.3V if you have a jumper for that. Connect TX to PA10, RX to PA9 and the GND pins together.

On the board itself, set the BOOT0 jumper to 1 to enable the serial flash bootloader. Reset the STM32 then click Upload.

Once the chip is programmed, switch the BOOT0 jumper back to 0.

**Notes**

The debug output sends data at 115200bps. Set the serial monitor accordingly.

Programming via anything else than the serial bootloader may require to change debug output to Serial0 and may consume more RAM.
Serial programming is still recommended for best results.


Compile-time options
--------------------

The file acsi2stm.h contains a few #define that you can change. They are described in the source itself.

Settings that you might wish to change:

 * ACSI_DEBUG: Enables debug output on the serial port. Moderate performance penalty.
 * ACSI_VERBOSE: Requires ACSI_DEBUG. Logs all commands on the serial port. High performance penalty.
 * ACSI_DUMP_LEN: Requires ACSI_VERBOSE. Dumps N bytes for each DMA transfer. It helps finding data corruption. Even higher
   performance penalty.
 * ACSI_SERIAL: The serial port used for debug output.
 * ACSI_READONLY: Make all cards read-only. Acsi2stm becomes strictly unable to modify SD cards.
 * ACSI_SD_CARDS: Set this to the number of physical SD card slots you have.
 * ACSI_DUMMY_BOOT_SECTOR: If no SD card is detected, the ACSI2STM will respond to a boot sector read with a dummy boot sector
   displaying a message that no SD card was detected. Very useful but not 100% SCSI-compliant (some drivers may not like it).
   Set it to 0 to disable that feature and restore 100% normal behavior.
   Strict mode jumper must be set to 0 to enable this feature at runtime.
 * ACSI_BOOT_OVERLAY: If set to 1, the boot sector of non-bootable SD cards will be patched with boot code to display a message.
   This way, people that don't know what to do will have a better user experience. Requires ACSI_DUMMY_BOOT_SECTOR.
   Strict mode jumper must be set to 0 to enable this feature at runtime.
 * ACSI_SD_MAX_SPEED: Maximum SD card speed in MHz. If SD communication fails, the driver automatically retries at a lower speed.
 * ACSI_ACK_FILTER: Enables filtering the ACK line, adding a tiny latency. May improve DMA reliability at the expense of speed.
 * ACSI_CS_FILTER: Enables filtering on the CS line, adding a tiny latency. This is necessary to sample the data bus at the right
   time. Adjust this if commands are corrupt.
 * ACSI_FAST_DMA: If set to 1, unroll DMA code for faster performance. Fast timings may not be compatible with some ST DMA chips.
 * ACSI_RTC: Setting this to 1 enables UltraSatan real-time clock compatibility.

The file acsi2stm.ino begins with the CS and lock pin table. You can change pin mapping here.


Rebuilding ASM code
-------------------

The build_asm.sh shell script patches VERSION into asm code, then rebuilds all files in asm subfolders. You need vasm and xxd
installed. This regenerates header files in the acsi2stm folder for boot overlays.

The script is meant to run in bash under Linux. It may or may not run under cygwin, git bash or macos (untested).


Building a release package
--------------------------

The build_release.sh shell script patches VERSION into STM32 code, calls build_asm.sh, builds the arduino firmware then packages
everything into a zip file.

Arduino must be properly configured through the graphical interface before calling this script. See *Installing software* above.
