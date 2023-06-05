4.01: Small fixes in GemDrive and more tests
============================================

Some small bugs prevented GemDrive from working correctly under TOS 2.06. It may
have impacts in some software too.

Changes since 4.00
------------------

Changes in GemDrive:

* Fixed a buffer overwrite in GemDrive that impacted Fsfirst with absolute
  paths.
* Fixed Fsfirst return value when the path is on an ejected drive.

Changes in tests:

* Added some tests for absolute paths.

Other changes:

* Fixed the stack canary that took too much RAM.
