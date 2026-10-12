# zx0-6x09

**zx0-6x09** is a Motorola 6809 and Hitachi 6309 decompressor for the [ZX0](https://github.com/einar-saukas/ZX0) data compression format by Einar Saukas. ZX0 provides a tradeoff between high compression ratio and extremely simple fast decompression.

## Usage

To compress a file, use the command-line compressor from https://github.com/emmanuel-marty/salvador with the "-classic" flag.

_**WARNING**: The ZX0 file format was changed in version 2. This library still uses version 1. There are currently no plans for a version 2 as it offers no benefit on the M6809/H6309 processor. Version 2 only inverts the bits of the offset MSB, so compression ratio is identical and a version 2 decompressor would run at the same speed. Only the M6809 standard version would be slightly larger (2 bytes)._

## Versions

Each processor has three versions trading code size for speed. Speeds are average CPU cycles per decompressed byte, measured with a cycle-counting simulator over a 97K test set of ROMs, binaries and text.

| Version | Size (bytes) | Speed (cycles/byte) |
|---|---|---|
| 6809/zx0_6809_standard.asm | 103-110 | 50.8 |
| 6809/zx0_6809_turbo.asm | 155-167 | 38.2 |
| 6809/zx0_6809_mega.asm | 360-371 | 27.1 |
| 6809/zx0_6809_mega_back.asm | 373-384 | 27.9 (backward) |
| 6309/zx0_6309_standard.asm | 74 | 19.2 (22.9 in 6809 emulation mode) |
| 6309/zx0_6309_turbo.asm | 114 | 16.9 (20.2 in 6809 emulation mode) |
| 6309/zx0_6309_mega.asm | 124 | 15.7 (18.8 in 6809 emulation mode) |

M6809 sizes depend on the assembly options set at the top of each file. H6309 speeds are for native mode unless noted.

The M6809 mega versions copy two bytes at a time. Only their first ~200-220 bytes must stay within one 256-byte page (the assembler reports an error if they cross); the rarely used code after that may be anywhere.

The backward version decompresses from the end of the data toward the start. Compress with salvador's "-classic -b" flags, then call it with reg X = end of compressed data + 1 and reg U = end of decompression buffer + 1.

## Projects using **zx0-6x09**:

* [CAS Tools](http://www.6809.org.uk/dragon/#castools) - A Perl script that converts a raw/DragonDOS/CoCo binary into a .cas or .wav file.

* [Defender CoCo 3](https://github.com/nowhereman999/Defender_CoCo3) - A conversion of the official Williams Defender game from the arcades for the Tandy Color Computer 3 that stores all compressed data using **ZX0** to fit on two 160K floppy disks.

* [Joust CoCo 3](https://github.com/nowhereman999/Joust_CoCo3) - A port of arcade game Joust for the Tandy Color Computer 3, that stores all compressed data using **ZX0** to fit on a single 160K floppy disk.

* [Robotron CoCo 3](https://github.com/nowhereman999/ROBOTRON_CoCo3) - A conversion of the original Robotron for the Tandy Color Computer 3, that uses **ZX0** compression to fit on a single 160K floppy disk.

* [Thomson TO8 Game Engine](https://github.com/wide-dot/thomson-to8-game-engine) - A Thomson TO8 game (sprites, music, etc.) and its generator written in ASM 6809 and Java.
