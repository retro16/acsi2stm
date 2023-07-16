Troubleshooting
===============

If you have an issue, check this place first:


Read-Only SD cards
------------------

You need to solder PB0..PB5 pins. See [hardware](hardware.md).


Programs crashing in GemDrive mode
----------------------------------

Unfortunately GemDrive isn't 100% compatible due to the way it works. A rule of
thumb is: if it crashes on Hatari's GEMDOS drives, then there is nothing you
can do about it.

Please file a bug report if you find a program that should work but doesn't.
Provide a debug trace in any case, it really helps.

See [manual.md](manual.md) for information about software compatibility.


"Bad DMA" chips
---------------

**Update**: [A recent article](https://www.chzsoft.de/site/hardware/new-atari-ste-bad-dma-investigation/)
describes a phenomenon that introduces DMA issues on some ST. It mentions a
possible software workaround. GemDrive implemented this workaround, so it
should be immune to the issue.

For ACSI, if you use a modern driver, contact the developer. If you use an
old legacy driver, there is nothing you can do. Use GemDrive instead.

**Note:** ACSI2STM 3.x and lower had random issues. Many people were confused
by this and thought that they had a bad DMA chip because of this. 4.00 fixed
the issue so it might be worth trying an up to date version.


The problem of STM32 clones / variants
--------------------------------------

Most STM32 clones won't work with ACSI2STM. The DMA code makes very heavy usage
of timers and the STM32 DMA engine, even using undocumented features. All of
this is very specific to the STM32F103 chip.

You really need a quality source of STM32F103 chips, beware of fake chips. Chip
shortage really increased the odds of buying fake chips, so be careful.

CH32F103 chips are known not to work.

Some official STM32 chips are sold as STM32F103C8T6 but in reality they are
STM32F103CBT6. The only difference is that the chip provides 128k flash instead of
64k. Both kinds of chips will work, and only CBT6 (or 128k C8T6) will support
verbose mode (verbose mode requires 128k of flash).

STM32 series other than STM32F103 work differently and won't work without
modifying the code substantially.

**Note:** Some STM32 didn't work with versions 3.x and lower, but this was
caused by a hardware issue in all STM32 (including good ones). A workaround was
implemented in version 4.00 so if you have old non-working ACSI2STM units,
updating to the latest version may fix your issues.
