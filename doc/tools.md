Documentation for tools provided with ACSI2STM
==============================================


ACSITEST.TOS
------------

Tests sending ACSI commands.

This tool can be used in many situations:

* Test the DMA port of an ST
* Check that ACSI devices conform to usual SCSI commands
* Stress test ACSI2STM hardware
* Surface scan ACSI devices
* Debug / troubleshoot devices without rebooting the ST all the time

### How to use

When launching the tool, input the ACSI device id. Press Esc to leave the tool.

It will perform basic command checks. Results are displayed on screen.

After tests are successful, you can select a few options:

* Buffer load test: the tool will do SCSI buffer read/writes with various bit
  patterns to stress test DMA transfers. This does not touches data on disk.
  Use this to test high speed DMA data integrity. Displays a `X` character each
  time the test fails, displays nothing if everything works. You can hot swap
  devices while the test is running. Press any key to stop the test.
* Command load test: the tool will spam SCSI commands at high speed. This does
  not touch data on disk. Use this to test command protocol data integrity.
  Displays a `X` character each time the test fails, displays nothing if
  everything works. You can hot swap devices while the test is running. Press
  any key to stop the test.
* Surface scan test: the tool will read all sectors of the drive.
* Restart basic test: ask for another ACSI device and redo the basic tests.


### Compatibility with GemDrive

The tool cannot test GemDrive units. Only buffer load test is guaranteed to
work.

You can launch the tool from within GemDrive. Once loaded, the GemDrive unit
must be kept on, because it still hooks console display routines.

To ensure total freedom, start the tool from a floppy disk and boot the ACSI2STM
unit in strict mode.

### Notes

* The tool is not compatible with GemDrive
* The tool supports hot plugging ACSI devices
* The tool embeds its own low level driver and drives the DMA port directly
* You can retry tests as many times as you want, the tool will stay stable
* Tests are not destructive, no disk write/format command is ever issued


CHARGEN.TOS
-----------

Generates a directory with empty files containing every character of the ST
character set.

It asks for a drive letter, then creates a directory named `CHARGEN.OUT` at the
root of that drive. Files are created in that directory.

On the GEM desktop, use list display to see characters more clearly.

It is used to stress test unicode conversion of special characters. It is part
of the release test cycle.


GEMDRIVE.PRG
------------

Loads the GemDrive driver from the GEM desktop or `AUTO` folder. It scans for
all ACSI devices and once it finds a compatible GemDrive unit, it loads the
driver.

### Notes

* This driver associates to the first ACSI2STM device it finds. If you have
  multiple physical GemDrive units connected, only the first one will be loaded.
* This driver loads at higher memory addresses than the boot loader. This may
  have an impact on some games or weird programs.
* GemDrive skips already occupied drive letters, so it may be better to use this
  loader than the boot loader in some ACSI + GemDrive configurations.
* Don't forget to install drive icons after the driver is loaded.


GEMDRPIO.PRG
------------

Loads the GemDrive driver for the PIO firmware. Apart from that, it works
exactly like `GEMDRIVE.PRG`


HDDFLASH.TOS
------------

Flashes hard drive firmware using Seagate SCSI commands. This is compatible with
ACSI2STM both in GemDrive mode and ACSI strict mode.

By default, `HDDFLASH.TOS` searches for `HDDFLASH.BIN`. If you specified a file
on the command-line or installed `HDDFLASH.TOS` to run `BIN` files from GEM, it
will load that file.

After the firmware image is loaded, the tool asks for an ACSI id.

To start flashing, you must enter **upper-case** `Y`.

Once the flashing procedure is finished, the ST will do a cold reboot. ACSI2STM
units also trigger a cold reboot after flashing, so you are ready to go.

Flashing an ACSI2STM unit usually takes around 2 seconds.

**Warning:** The GemDrive protocol changes between versions. If you use
`GEMDRIVE.PRG`, you must update it just before flashing the new firmware so at
next reboot the new driver will be in sync with the ACSI2STM unit.

**Warning:** This tool is not compatible with the PIO variant of the ACSI2STM
firmware.


SWAPTEST.TOS
------------

Stress tests disk swapping. It does a number of weird access patterns to try to
find defects in the operating system routines.

You will need 2 different disks/media for the drive. They must be both
formatted and ready to use.

The tool only accesses a single subdirectory, but it is not excluded that
operating system bugs would corrupt data on the disk.

At startup, enter the drive to test, then follow the instructions. You can run
the test on the same drive as the one you started `SWAPTEST.TOS` from.


TOSTEST.TOS
-----------

Stress tests and checks operating system error codes.

The tool does a lot of weird access patterns, such as accessing non-existing
files or writing to read-only files, and checks that error codes returned by
the operating system  exactly match what TOS 1.04-2.06 returns on a floppy disk.

The tool only accesses a single subdirectory, but it is not excluded that
operating system bugs would corrupt data on the disk.
