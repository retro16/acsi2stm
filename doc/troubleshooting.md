Troubleshooting
===============

If you have an issue, check this place first:


Read-Only SD cards
------------------

You need to solder PB0 to PB5 pins. See [hardware](hardware.md).


Corrupted partitions
--------------------

This is a symptom of certain models of STE and is unfortunately a
[well documented problem](http://joo.kie.sk/?page_id=250). While the DMA chip
is often identified as the culprit, an easy fix is to swap out the 68000
processor for a more modern, less noisy lower power equivalent, such as the
MC68HC000EI16 which is a drop-in replacement. Swapping the chip should require
no soldering, the old chip can be pried out of the socket with a little effort
(be careful not to damage the socket) and the substitute chip dropped in its
place. Be sure to confirm the orientation of the chip is the same as the old
one.

**Update**: [recent research]()
tend to indicate that a software workaround is possible. GemDrive implemented
this workaround, so it may be immune to the issue. Only time will tell ...


Writing errors in ACSI mode
---------------------------

The following errors are common with TOS 1.62:
> This disk does not have enough room for this operation.
> 
> Invalid copy operation.
> 
> TOS Error \#6

The workaround is basically to use an alternative TOS version. TOS 2.06 and [EmuTOS](https://emutos.github.io) are good candidates. EmuTOS offers a familiar experience with many quality of life improvements and is still under active development.

### Boot EmuTOS from SD
Check out [EmuTOS Bootloader](https://github.com/czietz/emutos-bootloader). Installing is as straight-forward as restoring an image file to an SD card. A couple of things to note about this method:

* This will wipe all the data from the card, but the linked website offers other methods of installation.
* This method does not play nice with multiple partitions yet, so is only really suitable if you're happy with a single partition on your card.

### Boot EmuTOS or another TOS from floppy
Check out the [EmuTOS Installation Guide](https://emutos.github.io/manual/#installation) for help on how to set up a floppy to boot straight into EmuTOS.

Alternatively you may find floppy images you can use to boot into original versions of TOS elsewhere online.

To skip booting from the SD card, hold down the **Alternate** key when turning on your computer.

### Physically swap the ROMs
This is a much more advanced solution and involves sourcing and soldering new chips into your machine. This is outwith the scope of this document.


Programs crashing in GemDrive mode
----------------------------------

Unfortunately GemDrive isn't 100% compatible due to the way it works. A rule of
thumb is: if it crashes on Hatari's GEMDOS drives, then there is nothing you
can do about it.

Implementing Pexec (the TOS function that starts programs) is very hard so it
very likely has bugs. Some other functions may have subtle differences in
their implementations compared to the original TOS (including non-existing
bugs).

Please file a bug report if you find a program that should work but doesn't.
Provide a debug trace in any case, it really helps.
