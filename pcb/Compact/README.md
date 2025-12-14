ACSI2STM PCB
============

Documentation about how to build and use is located in the doc directory.

REV 2.1 BY SIDECARTRIDGE - PLEASE READ CAREFULLY
================================================

For those following the ACSI2STM issue with the uncalibrated crystal, I previously suggested some design changes. As a result, I’ve developed an improved version of the ACSI2STM with several enhancements I consider important. This version features a castle-like PCB design (aka Castillian), which improves both performance and stability while maintaining full compatibility with the original firmware:

- 4-layer PCB – Reduces crosstalk and noise, improving reliability, especially in older Atari ST systems. I also redesigned some wiring paths.
- High-quality microSD slots – More robust, with an integrated eject mechanism for easier card handling. The model is the same used with the Multidevice. This is the reason for the "castellated" look of the board.
- Optimized crystal oscillator circuit – Addresses the major flaw in the original design, improving boot times and overall stability.
- External LED connector - Allows for the addition of an external activity LED. It's perfect for people who want to use the ACSI2STM in a case without a built-in LED. The connector is a standard 2-pin header located below the currrent activity LED. The LED can be connected directly to it, the default resistor is 220Omh and is R12 in the board (included). If the value is not suitable for your LED, you can remove the resistor and use your own  in the through hole CUSTOM_RESISTOR (not included) instead just above R12. The LED will be powered by the 3V3 line. 

The device is 100% compatible with the existing firmware. It also fits perfectly in the new internal riser boards allow direct installation inside Mega ST/STE, eliminating the need for external cables.

REV 2.2 BY SIDECARTRIGE
=======================

- DB-19 real connector 
