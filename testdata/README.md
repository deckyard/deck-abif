<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Sample files

`src/topics/samples/samples_test.j` reads these files and checks them against
Biopython's expected values. jvc runs the overlays from a copy of `src/`
alone, where this directory is missing; those tests then return at once, and
the rest build their ABIF files in code.

| File | Instrument, run | From | Licence |
|---|---|---|---|
| `310.ab1` | ABI PRISM 310, Sanger | Biopython `Tests/Abi/` | Biopython License Agreement, in `LICENSE.biopython.rst` |
| `3730.ab1` | 3730xl, Sanger | Biopython `Tests/Abi/` | Biopython License Agreement |
| `test.fsa` | 3100, fragment analysis (AFLP) | Biopython `Tests/Abi/` | Biopython License Agreement |
| `fake.ab1` | not ABIF: 26 bytes of text | Biopython `Tests/Abi/` | Biopython License Agreement |
| `GF_8_FTA_H01_08.hid` | 3500, GlobalFiler HID run | NCBI OSIRIS `docs/TestAnalysis/GlobalFilerHID/` | public domain: OSIRIS is a United States Government Work (NCBI's Public Domain Notice) |

Sources: <https://github.com/biopython/biopython/tree/master/Tests/Abi> and
<https://github.com/ncbi/osiris>, fetched 2026-11-13, unchanged.

SHA-256:

```text
0a395d39520d24a89af4c77dd55fd7fb632e732a6da807ceb6ead0c2465cb887  310.ab1
e4663e4db40232576ccdda5b878dddb01ef80a3d1b032941ba053146ce53f77b  3730.ab1
3c97441fea6d04af4b3aa32b2752f4802f6d508cb8dafd222bdfd8ebacda3763  test.fsa
86d9ee4daee09fdcd74f8bb53b43cf5a3ed48633816f6d25892c193d99caaea6  fake.ab1
b5d317978219aac1954e363bd9e09c877fe5ca7d319c712e7823a4873b71cd85  GF_8_FTA_H01_08.hid
```
