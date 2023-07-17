How to install EmuTOS with GemDrive
===================================

Since version 4.2, GemDrive is compatible with EmuTOS. Setting it up however is
a bit challenging. This file explains in details how to properly install it.


Setting up boot SD card
-----------------------

You need at least 2 SD cards and 2 slots on your ACSI2STM. EmuTOS cannot boot on
GemDrive, so you need at least 1 Atari-formated SD card.

**Alternative:** Use a floppy disk as boot drive. In that case you need only a
single SD card.

Create a small disk image (`hd0.img`) on the boot SD card. 30MB is recommended.

Partition the image using ICD PRO's `ICDFMT.PRG`. No need to make the disk
bootable. If you want multiple boot disks (such as a different set of `AUTO`
programs or accessories), create multiple partitions.

Copy `GEMDRIVE.TOS` on the boot disk. You can do that from TOS since it will
boot GemDrive and ICD at the same time (see [manual.md](manual.md)).


Installing EmuTOS
-----------------

If you run EmuTOS from ROM, you can skip that section.

Download the PRG version of EmuTOS.

On the GemDrive SD card (**not** the boot disk), copy `EMUTOS.PRG` at the root
of the SD card and rename it `EMUTOS.SYS`.


Setting up GemDrive from within EmuTOS
--------------------------------------

Insert the GemDrive SD card with `EMUTOS.SYS` in the first SD card slot of the
ACSI2STM. Insert the boot SD card in the last slot. If you use a boot floppy
instead, insert the floppy disk.

Reboot the system, EmuTOS should start at boot.

Once EmuTOS is booted, you should see the boot disk as C: (or A: if it is a
floppy disk).

Open the boot disk, then launch `GEMDRIVE.TOS`. GemDrive drives should be
detected starting at L:.

In the menu bar, click *Options/Install devices*. GemDrive drives should appear
on the desktop.

Select `GEMDRIVE.TOS`. In the menu bar, click *Options/Install application...*.

Set *Boot status* to *Auto*. Click *Install* to close the dialog.

Finally, in the menu bar, click *Options/Save desktop...*

**Note:** all your `AUTO` programs and accessories need to be installed on C:

**Note:** `AUTO` programs won't have access to GemDrive. Currently there is no
way around that.
