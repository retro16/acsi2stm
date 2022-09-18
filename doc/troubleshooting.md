Troubleshooting
===============

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

Writing errors
--------------
The following errors are common with TOS 1.62:
> This disk does not have enough room for this operation.

> Invalid copy operation.

> TOS Error \#6

The workaround is basically to use an alternative TOS version. TOS 2.06 and
[EmuTOS](https://emutos.github.io) are good candidates. EmuTOS offers a
familiar experience with many quality of life improvements and is still under
active development.

To install EmuTOS, see the guide in [emutos.md](emutos.md)
