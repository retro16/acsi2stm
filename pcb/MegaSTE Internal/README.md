# ACSI2STM-MSTE
 
This a KiCAD (6.0) design to host an [ACSI2STM](https://github.com/retro16/acsi2stm) directly inside an Atari Mega STE using the internal connector. 
The PCB has been designed to accomodate version 2.x and 3.x of ACSI2STM (aka V2) but also the V1 design as sold by @masteries on AtariAge. 
- No external power is required, the 5v is taken directly from the internal ACSI connector, but this has only been tested with a fully recapped PSU. 
- A set of jumper needs to be soldered to configure the board for V1 or V2 as noted on the PCB.


![ACSI2STM Adapter render](./ACSI2STM%20MegaSTE.png)

## BOM
- 100 nF Capacitor
- 10uF Radial Capacitor
- Male 2.54 header (Optional)
- 1N5817 Diode 
- Female 2.54 headers
- Amphenol GSD090012SEU SD Card socket
- STM32F103C8T6 "Blue Pill" (original one is highly recommended!!!). 
- Firmware from [ACSI2STM](https://github.com/retro16/acsi2stm) or from @masteries. 

## Configuration
Configuration is done by simple solder bridges on the pads, instructions are also written on PCB.

### For V1:
- Solder bridge: JP1, JP2, JP3, JP4, JP5, JP6, JP7
- Solder bridge pads 1 and 2 of JP9 (2 leftmost pads)
- Solder bridge pads 1 and 2 of JP10 (2 leftmost pads)

### For V2: 
- Solder bridge pads 2 and 3 of JP9 (2 leftmost pads)
- Solder bridge pads 2 and 3 of JP10 (2 leftmost pads)

### For V3: 
- Solder bridge pads 2 and 3 of JP9 (2 leftmost pads)
- Solder bridge pads 2 and 3 of JP10 (2 leftmost pads)
- Solder bridge JP8 


### Firmware update

A male 3 pin header is optional and only required if you want to program the STM32 without removing it from the Atari.
The RX and TX marking correspond to the STM32 pins A10 an A09, to program the STM32 connect the board's RX to your USB-TTL TX and the board's TX to your USB-TTL-RX:
| USB-TTL | ACSI2STM |
|:---------:|:----------:|
| GND | GND |
| RX | TX |
| TX | RX |

In order to update the STM32:
1. Power-off your MegaSTE
2. Plug the GND, RX and TX to your USB-TTL adapter
3. Move BOOT0 jumper to "1" on the BluePill
3. Plug USB to ACSI2STM
4. Follow the normal update process.
5. Unplug USB, RX, TX and GND
6. Move BOOT0 jumper back to original position
7. Power-on the Mega STE

:warning: Although the diode should avoid USB power from flowing back to the Mega STE, I haven't tested USB plugged-in while the MegaSTE is powered on. :warning: 
