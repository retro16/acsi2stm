Firmware variants in the release package
========================================

Newer ACSI2STM release packages have many variants to choose from.

You can use these firmware files to avoid installing the whole Arduino toolchain
on your computer.

### acsi2stm-XXXX.ino.bin

Standard firmware.

### acsi2stm-XXXX-strict.ino.bin

Reduced firmware with GemDrive permanently disabled, just like if you set BOOT1
to force ACSI mode. All SD cards behave like Atari hard drives.

Compile-time options:

    #define ACSI_STRICT 1

### acsi2stm-XXXX-debug.ino.bin

The standard firmware, with limited debug output. Debug output is on the USART
port of the STM32 (PA9) at 1Mbps.

Compile-time options:

    #define ACSI_DEBUG 1

### acsi2stm-XXXX-verbose.ino.bin

The standard firmware, with verbose debug output. Very slow.

Compile-time options:

    #define ACSI_DEBUG 1
    #define ACSI_VERBOSE 1

### acsi2stm-XXXX-strictverbose.ino.bin

Same as the strict variant, with verbose debug output.

Compile-time options:

    #define ACSI_STRICT 1
    #define ACSI_DEBUG 1
    #define ACSI_VERBOSE 1

### acsi2stm-XXXX-legacy.ino.bin

Same as standard firmware, but for older 2.x units that don't have the necessary
hardware modifications (reset line and read-only switch). Also has more
conservative speeds.

Compile-time options:

    #define ACSI_HAS_RESET 0
    #define ACSI_SD_WRITE_LOCK 0
    #define ACSI_FAST_DMA 1

### acsi2stm-XXXX-pio.ino.bin

Variant that does not use DMA transfers at all. This only supports GemDrive and
it cannot autoboot, so you need to load the driver `GEMDRPIO.PRG` manually.

This firmware does not use the DMA chip of the ST, so it will work even with a
defective chip.

Performance suffers: it runs about 10x slower than DMA, which is still much
better than floppy drives and probably as fast as an old hard drive with a bad
AHDI driver.

**Warning:** This firmware variant cannot be updated with `HDDFLASH.TOS`. You
need to use the serial dongle instead.

Compile-time options:

    #define ACSI_PIO 1

### acsi2stm-XXXX-piodebug.ino.bin

PIO variant with debug output enabled.

**Warning:** This firmware variant cannot be updated with `HDDFLASH.TOS`. You
need to use the serial dongle instead.

Compile-time options:

    #define ACSI_PIO 1
    #define ACSI_DEBUG 1

### acsi2stm-XXXX-pioverbose.ino.bin

PIO variant with verbose output enabled. This mode is **extremely slow**.

**Warning:** This firmware variant cannot be updated with `HDDFLASH.TOS`. You
need to use the serial dongle instead.

Compile-time options:

    #define ACSI_PIO 1
    #define ACSI_DEBUG 1
    #define ACSI_VERBOSE 1


## Which variant should I choose ?

Most users should use the standard firmware.

If you want to use it as an ACSI drive only, you may prefer the strict variant.

If you are building a unit, you may be interested in the debug firmware to
diagnose potential issues with your hardware.

If you found a bug or a strange behavior and wish to do a bug report, verbose
output may be requested: in that case, use the verbose firmware.

If you know you have an old unit without a reset line, use the "legacy" variant.

If your SD card is stuck in read-only mode, you need to do hardware
modifications. If you cannot do that (or don't want to), use the legacy variant.

If you have a faulty DMA chip (common problem), you will have to use the PIO
variant.


Compiling and installing a new firmware
=======================================


Software needed
---------------

* The [Arduino IDE](https://www.arduino.cc/en/software). Version 2 is preferred.
* The [Roger Clark Melbourne STM32 library](https://github.com/rogerclarkmelbourne/arduino_stm32).
  * This is *NOT* compatible with the official STM32duino library: you need
    Clark's variant.
* The SdFat AdaFruit Fork Arduino library.


Installing software
-------------------

Download and install the [Arduino IDE](https://www.arduino.cc/en/software).

Start the Arduino IDE once to create the Arduino folder in your home folder.

Clone/download the Arduino_STM32 library to the `Arduino/hardware/Arduino_STM32`
folder.
Use the [master](https://github.com/rogerclarkmelbourne/arduino_stm32/tree/master)
branch of the project for the most up to date version.

Start the Arduino IDE.

In the menu, select Tools / Board / Board manager.

Search and install `Arduino Mbed OS RP2040`.
Thanks to Tomasz Orczyk for finding that this board provides a much better
compiler than the recommended Arduino SAM boards.

In the menu, click Tools / Manage Libraries.
Search for "SdFat" and install `SdFat - AdaFruit Fork`.

In the board selection dropdown, click *Select Other Board and Port* and search
for `STM32F103C`. Select *Generic STM32F103C series*.

In the Tools menu of the Arduino interface, select the following:

* CPU speed: 72MHz (normal)
* Variant: STM32F103C8
* Optimize: Smallest (default)
* Upload method: Serial
* Port: your USB serial dongle

If you have different options in the Tools menu, it may be because you don't
have the correct board installed.

Then, you will be able to upload the program to the STM32.

**Note:** Instructions are a bit different for Arduino 1.x, but it's basically
the same idea. Arduino 1.x is not officially supported anymore, but efforts
will be done to avoid breaking compatibility.

**Warning:** ST-Link is **not** supported. When compiling with ST-Link enabled,
it injects some extra code and generates broken firmware. UART is the only
supported way of programming/debugging ACSI2STM.


Programming the STM32
---------------------

### Programming the Compact board

Connect the board to the USB UART dongle, as explained in
[quick_start](quick_start.md).

You can now upload the firmware from within Arduino IDE.

### Programming the Blue Pill board

Set the USB dongle to 3.3V if you have a jumper for that. Connect TX to PA10, RX
to PA9 and the GND pins together.

On the board itself, set the BOOT0 jumper to 1 to enable the serial flash
bootloader. Reset the STM32 then click Upload.

Once the chip is programmed, switch the BOOT0 jumper back to 0.

**Warning:** Programming via anything else than the serial bootloader may
require to change debug output to Serial0 and may consume more memory. Serial
programming is the only supported upload method.

**Note:** The debug output sends data at 1Mbps. Set the serial monitor
accordingly.


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

Feel free to experiment with other settings as well.

**Note:** any combination of settings should work. If you find a setting that
works by itself, but stop working when combined with another setting, please
file a GitHub issue.


Rebuilding ASM code
-------------------

The `build_asm.sh` shell script rebuilds all files in asm subfolders. You need
[vasm](http://www.compilers.de/vasm.html) and xxd (packaged with vim) installed.
This regenerates header files in the acsi2stm folder for GemDrive.

The script is meant to run in bash under Linux. It may or may not run under
cygwin, git bash or macos (untested).


Building a release package
==========================

You need to install [arduino-cli](https://arduino.github.io/arduino-cli) to
build the Arduino sketch.

You also need to setup the Arduino environment from the IDE: install all
dependencies from there. You don't need to select the correct board from within
the IDE as the build script will automatically select the correct board.

The `build_release.sh` shell script patches VERSION in all sources, calls
`build_asm.sh` and `build_arduino.sh`, then packages everything into a zip file.


Release package test procedure
------------------------------

Test procedure that must be done when releasing a new major version.

The hardware must be flashed with the previous stable version.

### Needed programs / files

* The ACSI2STM release package
* ICD Pro files
* `CONTROL.ACC` from a language disk
* `GENST2.PRG` from Devpac 2.x
* `SYSINFO.PRG`
* A few big desktop apps, at least one that runs correctly under EmuTOS
* A disk image with the PP driver installed (bootable)
* A disk image with the Atari AHDI 6.061 driver installed (bootable)
* A file between 5MB and 30MB to use as a disk image (content doesn't matter)
* The latest EmuTOS in PRG format: `EMUTOS.PRG`

### Needed hardware

* An ACSI2STM unit flashed with the previous version of the firmware
* A secondary ACSI2STM unit with the latest firmware and strict mode jumper set
* 1 empty FAT32 card
* 1 empty ExFAT card
* 1 unformatted SD card (no partition table)
* 1 formatted floppy disk

### FAT32 SD card preparation

* Unzip the release package to the SD card
* Rename the standard firmware to `HDDFLASH.BIN`
* Rename the strict firmware to `STRICT.BIN`
* Copy ICD drivers package
* Copy `CONTROL.ACC`
* Copy desktop apps
* Copy `EMUTOS.PRG`
* Copy `SYSINFO.PRG`

### ExFAT SD card preparation

* Create a directory named `acsi2stm`
* Copy the PP image into `acsi2stm`
* Copy the AHDI image into `acsi2stm`
* Copy the 5-30MB file into `acsi2stm`
* Make sure no disk image is named `hd0.img`

### On a single TOS version (either 1.04, 1.62 or 2.06)

* Reset the RTC by removing the backup battery and emptying capacitors
* Boot the ST with the FAT32 and ExFAT cards
* Upgrade the firmware with `HDDFLASH.TOS`
  * Check version number on the splash screen
* Test setting date via `CONTROL.ACC` then power cycle the ST to test RTC
* Run `SWAPTEST.TOS` on GemDrive cards
  * Use the FAT32 card as SD card 1
  * Use the ExFAT card as SD card 2
* Run `CHARGEN.TOS` and check the result on the ST and on a PC
* Copy `GEMDRIVE.PRG` to the floppy disk
* Check hotplug card type change
  * Eject the ExFAT card
  * Rename the 5-30MB disk image to `hd0.img`
  * Re-insert the ExFAT card
  * Check that the card cannot be accessed anymore
* Reboot the ST with the 3 cards inserted
* Open ICD folder
  * Run `ICDBOOT.PRG`
  * Run `ICDFMT.PRG`
  * On both the unformatted SD card and the ExFAT card with the image
    * Create 1 partition, size does not matter
    * Reboot the ST
    * Make the raw SD card bootable with `HDUTIL.PRG`
* Test ICD hot swapping (must indicate "media change")
* Test ICD `IDCHECK.PRG`
* Test ICD `RATEHD.PRG`
* Run `ACSITEST.TOS` on an ICD card
* Copy the release package onto one ICD card
* Copy the release package between the 2 ICD cards
* Copy the release package back to another folder of the GemDrive card. Check
  the result on a PC with diff.
* Reboot with no ACSI2STM, then hot plug it and run `GEMDRIVE.PRG` from floppy
* On the ExFAT card, rename the PP driver to `hd0.img` and boot the PP driver
  along with GemDrive. Do a few file operations from the desktop to test it.
* Follow the doc to setup and test EmuTOS
* Run a compatible desktop app under EmuTOS on GemDrive
* If any ASM file was changed, check that the program still assembles with GenST
  2.x and runs fine.
* Enable ACSI strict mode via jumper and check that GemDrive doesn't boot but
  ICD does.
* Turn power off.
* Set the ACSI2STM id offset to 3 with a jumper.
* Plug the secondary ACSI2STM unit.
* Insert the Atari AHDI SD card in the first slot of the secondary unit.
* On the main ACSI2STM unit, insert only the GemDrive card.
* Boot the ST and run `GEMDRIVE.PRG` from floppy.
* Check that both C: (AHDI) and F: (GemDrive) are available.
* Check that available RAM is reasonable by running `SYSINFO.PRG`
* Copy `EMUTOS.PRG` from F: to C:.
* On F: copy `EMUTOS.PRG` to `EMUTOS.SYS`
* Reboot on the GemDrive card, EmuTOS should boot
* Delete `EMUTOS.SYS` from the GemDrive card

### On 3 TOS versions (1.04, 1.62, 2.06)

* Boot an ICD + GemDrive combination
* Copy files from GemDrive to ICD, at least one file must be over 1M
* Create a directory on GemDrive
* Copy files back from ICD to GemDrive
* On a PC, check that the 2 copies are identical
* On the ST, delete the directory
* Run `TOSTEST.TOS` on a floppy disk if it changed since the last release
* Run `TOSTEST.TOS` on a GemDrive card
* Run a few big desktop programs on GemDrive, use the file selector
* Eject the GemDrive SD card and try to open it

### Multi-device test matrix

For each combination in the table, just do a simple directory browse test.
Check that drive letters are all available.

ACSI2STM device 1 has id 0-2 and device 2 has id 3-5 (ID_SHIFT set).

* SD cards:
  * FAT: A normal FAT32 SD card
  * HD0: The hd0.img provided in the release package
  * ICD: An ACSI bootable SD card with ICD pro and 4 Atari partitions. The boot
    `AUTO` folder must contain the latest GemDrive drivers (both normal and PIO)
  * EMU: A normal FAT32 SD card with EMUTOS.SYS at its root. EmuTOS must boot
* Floppy:
  * Blank: A non-bootable blank floppy
  * ACSI2STM: The floppy provided in the release package
* Drives: A list of expected drives. Upper case are GemDrive, lower case are
  ACSI

| TOS  | Device 1 | SD cards | Device 2 | SD cards | Floppy   | Drives  |
|------|----------|----------|----------|----------|----------|---------|
| EMU  | Normal   | FAT,HD0  | None     |          | Blank    | cLMN    |
| 1.62 | Normal   | FAT      | Normal   | FAT      | Blank    | CDEFGH  |
| EMU  | Normal   | FAT      | Normal   | FAT      | ACSI2STM | CDEFGH  |
| 1.62 | Normal   | FAT      | PIO      | FAT      | ACSI2STM | CDEFGH  |
| 2.06 | Normal   | FAT      | PIO      | FAT      | ACSI2STM | CDEFGH  |
| 2.06 | Strict   | HD0      | Normal   | EMU      | Blank    | cDEF    |
| 2.06 | Strict   | HD0      | Normal   | ICD,EMU  | Blank    | cdefgLN |
| 1.04 | Strict   | ICD      | PIO      | FAT      | Blank    | cdefGHI |
| 1.04 | PIO      | FAT      | PIO      | FAT      | ACSI2STM | CDEFGH  |
