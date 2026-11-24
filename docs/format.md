<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# The format

ABIF is a publicly documented file format. The layout follows Applied
Biosystems™' "ABIF File Format Specification" (2009), which Applied
Biosystems publishes for developers of software that reads its files.
Every number is big-endian.

The specification documents the container (header, directory, element
types) and the common tags. It does not document the element types 28 to
34 of 3500 HID files (encrypted), the layout of user-defined structures
(types 1024 and up) or every instrument- and software-specific tag; the
deck reads those as raw bytes.

## Header and directory

| Bytes | Holds |
|---|---|
| 0-3 | `ABIF` |
| 4-5 | the version: 101 for 1.01, 300 for 3.00 |
| 6-33 | the directory's own entry: name `tdir`, number 1, type 1023, element size 28, the entry count, the space reserved for the directory, its offset |
| 34-127 | reserved |

The directory's reserved space can be larger than its entries: a 310 file
reserves 3584 bytes for 113 entries. Only the counted entries are read.

Each directory entry is 28 bytes:

| Bytes | Holds |
|---|---|
| 0-3 | the tag name, four ASCII characters |
| 4-7 | the tag number |
| 8-9 | the element type |
| 10-11 | the element size |
| 12-15 | the element count |
| 16-19 | the data size, count times element size |
| 20-23 | the data's offset; data of 4 bytes or less is stored here instead |
| 24-27 | reserved (3500 HID files fill it) |

## Element types

| Code | Type | Size | Read as |
|---|---|---|---|
| 1 | `byte` | 1 | unsigned |
| 2 | `char` | 1 | bytes: text or small numbers |
| 3 | `word` | 2 | unsigned |
| 4 | `short` | 2 | signed |
| 5 | `long` | 4 | signed |
| 7 | `float` | 4 | IEEE 754 |
| 8 | `double` | 8 | IEEE 754 |
| 10 | `date` | 4 | year (signed 16-bit), month, day |
| 11 | `time` | 4 | hour, minute, second, hundredths |
| 12 | `thumb` | 10 | two signed 32-bit fields, two bytes |
| 13 | `bool` | 1 | zero is false |
| 18 | `pString` | 1 | a length byte, then the text |
| 19 | `cString` | 1 | the text, then a NUL |
| 1024 and up | user | any | raw bytes |

Codes 6, 9, 14 to 17, 20, 128, 256 and 384 are obsolete types the
specification names but does not support; they read as raw bytes, as does
any other code.

## Common tags

| Tag | Holds |
|---|---|
| `DATA` 1-4, 105+ | raw traces, one per dye |
| `DATA` 5-8 | electrophoresis voltage, current, laser power and oven temperature during the run |
| `DATA` 9-12, 205+ | analysed traces |
| `Dye#` 1 | the number of dyes |
| `DyeN` n, `DyeW` n | dye n's name and wavelength |
| `PBAS` 1, 2 | bases, as edited and as called |
| `PCON` 1, 2 | quality values, as edited and as called |
| `PLOC` 1, 2 | peak locations, as edited and as called |
| `FWO_` 1 | the base order of the four traces, such as `GATC` |
| `SMPL` 1 | sample name |
| `TUBE` 1 | well |
| `LANE` 1 | lane or capillary |
| `MCHN` 1, `MODL` 1 | instrument name, model |
| `RUND` / `RUNT` 1-4 | run start, run stop, collection start, collection stop |
| `RunN` 1, `RMdN` 1 | run name, run module |
| `DySN` 1, `GTyp` 1 | dye set, polymer |
| `StdF` 1 | size standard (fragment runs) |
| `Scal` 1 | the rescaling divisor of the colour data |

## 3500 HID files

HID files are version 3.00. Beside the usual types they use codes 28 to 34
(element size 1) for the traces, peak tables, size-standard fit, most dye
names and the model: encrypted blocks of 8 bytes, deterministic, so equal
plaintexts give equal ciphertexts. Data handles (bytes 24-27 of an entry)
are filled. The plain tags - sample, well, instrument, run times, size
standard, wavelengths, audit XML - read as in any ABIF file.
