# zx0-6x09

**zx0-6x09** is a Motorola 6809 and Hitachi 6309 decompressor for the [ZX0](https://github.com/einar-saukas/ZX0) data compression format by Einar Saukas. ZX0 provides a tradeoff between high compression ratio and extremely simple fast decompression.

## Usage

To compress a file, use the command-line compressor from https://github.com/emmanuel-marty/salvador with the "-classic" flag.

_**WARNING**: The ZX0 file format was changed in version 2. This library still uses version 1. There are currently no plans for a version 2 as the version 1 format is optimal for the M6809/H6309 processor. A version 2 decompressor would be both slower and use slightly more space._

## Projects using **zx0-6x09**:

* [CAS Tools](http://www.6809.org.uk/dragon/#castools) - A Perl script that converts a raw/DragonDOS/CoCo binary into a .cas or .wav file.

* [Defender CoCo 3](https://github.com/nowhereman999/Defender_CoCo3) - A conversion of the official Williams Defender game from the arcades for the Tandy Color Computer 3 that stores all compressed data using **ZX0** to fit on two 160K floppy disks.

* [Joust CoCo 3](https://github.com/nowhereman999/Joust_CoCo3) - A port of arcade game Joust for the Tandy Color Computer 3, that stores all compressed data using **ZX0** to fit on a single 160K floppy disk.

* [Robotron CoCo 3](https://github.com/nowhereman999/ROBOTRON_CoCo3) - A conversion of the original Robotron for the Tandy Color Computer 3, that uses **ZX0** compression to fit on a single 160K floppy disk.

* [Thomson TO8 Game Engine](https://github.com/wide-dot/thomson-to8-game-engine) - A Thomson TO8 game (sprites, music, etc.) and its generator written in ASM 6809 and Java.
