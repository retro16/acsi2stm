ACSI2STM setup tool (A2SETUP)
=============================

The setup tool can do various tasks such as testing the hardware, formating SD
cards or setting up the clock.


Starting the setup tool
-----------------------

There are many ways to access the setup tool:

 * During boot, press Shift+S before the ACSI2STM boot message appears
 * During boot, send any character to the serial port, the setup tool will run
   through the serial port (it uses VT100 control codes instead of VT52)
 * From GEM, start the provided `A2SETUP.TOS` program
 * Install the setup tool in a boot sector using `a2stboot -s`

Some features can run in emulators or on other hardware. This is not guaranteed
to work, though.


Selecting the ACSI device
-------------------------

When entering the setup tool, you have to select on which device you wish to
work. Simply select the device with keys 0 to 7.

    ACSI2STM 3.0g by Jean-Matthieu Coulon
    GPLv3 license. Source & doc at
     https://github.com/retro16/acsi2stm

     0: ACSI2STM SD0 F32  30G   
     1: ACSI2STM SD1 F16  30G   
     2: 
     3: 
     4: 
     5: 
     6: 
     7: 
    
    Select device (0-7)
    Esc to quit

This screen is 100% hotplug: device names are constantly refreshed so you can
change SD cards or even ACSI devices and the list will refresh.

Pressing Esc will return to GEM if you started from `A2SETUP.TOS` or reboot the
computer if you started from boot.


Main menu
---------

    Selected device:ACSI2STM SD0 F32  30G   

    Main menu:

      T:Test ACSI2STM
      C:Clock setup
      S:Format SD for PC
      I:Create image
      Q:Quick setup
      P:Partition/format tool

    Esc:Back

The main menu offers a selection of tools. Press the matching key to select the
tool. Tools are detailed in other sections later in this page.

 * Test ACSI2STM: Test the communication between the Atari ST and the ACSI2STM
   unit.
 * Clock setup: Read and set date and time on the clock.
 * Format SD for PC: This tool simply reformats a SD card to the standard format
   for PCs (FAT32 or ExFAT depending on its size).
 * Create image: Creates an image file onto a standard SD card to use as a hard
   disk.
 * Quick setup: Formats the image or the SD card for use with the Atari ST.
 * Partition/format tool: Create partitions on the SD card and format for use
   with the Atari ST. This tool only supports FAT12 and FAT16.

This tool supports SD card hot swapping. If the device is disconnected, you will
be sent back to the device selection menu.


Test ACSI2STM
-------------

This tool does a stress test of the ACSI bus. It sends various commands with the
tightest possible timing. If you have a doubt about your ACSI2STM hardware or
your DMA controller inside the ST, just run this self-test.

The test runs with special patterns that will produce the hardest possible
combinations of bit flips on the bus.

The test tool requires a recent ACSI2STM firmware (at least 2.4) and cannot be
done on an ACSI2STM unit running in strict mode.

Here is a sample output of a successful test:

    Testing in read mode
    Test command
    Zero filled command
    Ones filled command
    Testing in write mode
    Test command
    Zero filled command
    Ones filled command
    Fetch buffer size:4096
    Check DMA with data integrity
    Testing DMA with pattern 55AA55AA
    Testing DMA with pattern FF00FF00
    Testing DMA with pattern F00F55AA
    Testing DMA with pattern 55AAF00F
    Testing DMA with pattern 01020408
    Testing DMA with pattern 10204080
    Testing DMA with pattern FEFDFBF7
    Testing DMA with pattern EFDFBF7F
    Testing DMA with pattern FFFFFFFF
    Testing DMA with pattern 00000000
    All tests successful
    Press a key to continue


Clock setup
-----------

**NOTE**: You need a backup battery connected to VBAT to use the clock feature.

    Time settings

         Time:2022-05-14 14:31:07

    Return: set time
    Esc: main menu

This shows the time stored in the real-time clock of the ACSI2STM unit.

To change date and time, press Return and follow the instructions.

Press Esc to go back to the main menu.


Format SD for PC
----------------

This tool will format the SD card for use with a PC. Everything on the SD card
will be erased (partition table and boot sector) and a single partition
formatted as FAT32 ot ExFAT will be created.

**To format the SD card for use on an Atari ST, use the Parition/format tool
instead.**


Create image
------------

If you have a standard FAT32/ExFAT SD card, you can choose to work on an image
file stored inside the SD card instead of working on the SD card itself.

This tool creates a suitable image file for ACSI2STM then calls quick setup.

**WARNING**: Creating an image on the ACSI2STM is very slow (800KB/s) so keep
images small. You can use a PC tool for bigger images.


Quick setup
-----------

This tool partitions and formats the SD card for use with the ST. It creates a
single partition of maximum 256MB with settings that maximize compatibility over
most operating systems.

If an image is present, it will format the image. If there is no image the raw
SD card will be formatted.


Partition/format tool
---------------------

    Partitioning ACSI2STM SD0 F32  30G   
    Device is 62529536 sectors
    Boot sector type: MBR non bootable


    Partitions:
      Typ      First       Last Size:MB Fmt
     1 06         32    1046527     511 F16
     2 06    1046528    2093023     511 F16
     3 06    2093024    3139519     511 F16
     4 06    3139520    4186015     511 F16

      Q:Quick partition  F:Format whole disk
      N:Create new MBR
    1-4:Edit part 1 to 4 E:Edit partition
      I:Install driver   K:Kill boot sector
      P:Save pending     U:Undo changes
    Esc:Back

Use this tool to create/change/modify partitions and boot sector.

The tool has a few limitations:
 * Extended partitions are not supported
 * The tool only supports MBR partitions
 * Some operations are applied immediately and cannot be undone

### Quick partition

This option simply splits the drive in equally sized partitions. It asks for
how many partitions you would like then formats them automatically.

The tool limits partitions to 511MB to ensure compatibility with TOS.

**Note**: Partitions over 256MB require 8192 bytes logical sectors and are
incompatible with Linux.

Quick partitioning is applied immediatly and cannot be undone.

### Format whole disk

This option starts the formating tool (see below) on the whole disk. The disk
will not have a partition table.

**Note**: You can still install the driver in the boot sector if you leave
enough reserved sectors.

Formating is applied immediatly and cannoy be undone.

### Create new MBR

This option wipes the current boot sector and creates a new MBR with no
partition.

### Edit partition

    Edit partition 1

      N:New partition     D:Delete partition
      F:Format
      S:Set first sector  L:Set last sector
      T:Set type          R:Resize
      P:Save pending      U:Undo changes
    Esc:Back

 * New partition: recreate the partition in another place.
 * Delete partition: delete the partition and go back to partition list.
 * Format: format the partition (see *Formating tool* below).
 * Set first sector: Change the first sector of the partition.
 * Set last sector: Change the last sector of the partition.
 * Set type: Change partition type in the MBR. ACSI2STM doesn't use that field.
 * Resize: Resize the partition. Beware: this does not resize the filesystem.
 * Save pending: Save all pending changes.
 * Undo changes: Undo all pending changes.
 * Esc: go back to the partition list.

### Install driver

This option installs the ACSI2STM driver in the boot sector. This allows using
the driver inside an emulator, on a different device, or on an ACSI2STM in
strict mode.

**Note**: It is much better to keep the device non-bootable and let the ACSI2STM
overlay its driver at boot time, so you are guaranteed to always use the latest
version of the driver.

### Kill boot sector

Disable the boot sector.

It is a good idea to disable the boot sector so that ACSI2STM can overlay its
own driver.

You can use that option on drives that were initialized on ICD PRO or P.Putnik's
driver to go back to the ACSI2STM integrated driver.

**Warning**: This cannot be undone once you saved pending changes.

### Save pending

Save all pending changes.

### Undo changes

Undo all pending changes.

### Back

Go back to the main menu.


Formating tool
--------------

If this tool is accessed from within the main menu of the partition tool, it
will format the whole disk without a partition table (like floppy disks).
If this tool is accessed from within a partition, it will format the partition.

    Parameters:

    FAT type   :FAT16
     Sect.sz[S]:8192
    Clust.sz[C]:2
    Reserved[R]:16
    FAT size   :8
    Root dir[D]:512
    Clusters[X]:32686
      Serial[N]:5A8C5B75
       Label[L]:

      O:Optimize  M:Maximize size
      F:Format
    Esc:Back

To change a value, press the corresponding key in brackets.

Parameters and their meanings:

### FAT type

Indicates which format will be used (FAT12 or FAT16). This is determined
automatically by the cluster count (see Clusters).

### Sect.sz

Logical sector size in bytes. This value is a power of 2 between 512 and 8192.

Linux cannot mount filesystems with sectors bigger than 4096 bytes.

Press S to change this value.

### Clust.sz

Cluster size in logical sectors. This value is a power of 2.

To get the actual cluster size in bytes, multiply `Clust.sz` by `Sect.sz`.

Clusters cannot be more than 32768 bytes.

TOS does not handle filesystems with more than 2 sectors per cluster. This seems
to work, but it starts to misbehave as you fill the filesystem more and more.
Some TOS versions may not have this limitation.

Press C to change this value.

### Reserved

Number of reserved logical sectors. This value must be 1 or more.

Reserved sectors are used to store boot programs.

Press R to change this value.

### FAT size

Number of logical sectors used to store the FAT.

You cannot change this, it is computed automatically.

### Root dir

Number of entries (files) in the root directory.

Defaults to 512 for FAT16 and 64 for FAT12.

Press D to change this value.

### Clusters

Total number of clusters in the filesystem.

Some TOS versions have issues beyond 32767 clusters, some others have a limit
near 32803. This tool caps clusters to 32767 to avoid compatibility issues.

Press X to change this value.

### Serial

Serial number of this filesystem.

Press N to randomize this value.

### Label

Filesystem label. Up to 11 characters.

Press L to change this value.

### Optimize

Press O to recompute all fields to their optimal value.

### Maximize size

Press M to recompute cluster count given the other settings.

### Format

Press F to start formating. This can take a few minutes for big filesystems.

