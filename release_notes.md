4.10: Clock support and unicode for GemDrive
============================================

Clock support
-------------

Adding clock support for GemDrive was easier than anticipated. One more reason
to add a backup cell to your ACSI2STM !

Here is what it does:

* Hooks all system clock functions into the STM32.
* No need to load any utility: the ST is simply always on time.
* Use `CONTROL.ACC`/`XCONTROL.ACC` or any other standard time setting tools to
  set time and date.
* Sets date/time correctly on created files and folders.

Note: for users of machines with an internal clock, ACSI2STM reads the time from
the Atari clock at boot if its internal clock is not already set.

Unicode support
---------------

Now GemDrive properly translates all file names to unicode. Converting back and
forth is 100% guaranteed. Importing files from other systems might be more
difficult, though. Anyway, the system replaces unknown characters with a macron
so you can spot them easily. A few characters such as the euro sign are
transliterated to visually near-equivalent characters.

Changes since 4.01
------------------

* Implemented clock for Tgettime / Tsettime / Tgetdate / Tsetdate.
* Use clock to set file date correctly.
* Improved performance of Fsnext when some SD slots are empty.
* Added proper unicode translation for special Atari characters.
* Fix for unsupported characters in names.
* Added `CHARGEN.TOS` to produce test file names with unicode characters.
