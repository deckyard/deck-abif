<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @deckyard/abif

Applied Biosystems™ capillary sequencers write their runs as ABIF files:
Sanger traces (`.ab1`), fragment-analysis runs (`.fsa`) and, from the 3500
series, HID runs (`.hid`). This deck reads them: the directory of tagged
elements, every element type, and the usual contents - raw and analysed
traces per dye, the dyes, base calls with qualities and peak locations, and
the sample and run metadata.

ABIF is a publicly documented file format: Applied Biosystems publishes
the "ABIF File Format Specification" for software that reads its
instruments' files, and this deck implements that specification. What the
specification leaves undocumented - the element types 3500 HID files
encrypt, and user-defined structures (types 1024 and up) - is given as raw
bytes, not interpreted. See [the format](format.md).

- [Reading a file](reading.md): opening, the directory, values and the
  typed readers.
- [The run](run.md): traces, dyes, base calls and metadata.
- [The three file types](files.md): `.ab1`, `.fsa` and `.hid`, what each
  holds and how it differs.
- [The format](format.md): the layout on disk, the element types, the
  common tags, and what 3500 HID files encrypt.
- [Cheatsheet](cheatsheet.md): every export.

## Conventions

Snippets assume this import:

```jennifer
import "@deckyard/abif/" as abif;

def f as abif.File init abif.open("sample.ab1");
io.printf("%s: %d bases\n", abif.info($f).sample, len(abif.calls($f).bases));
```

Input that breaks the format is an error, never repaired: `parse` checks the
header and every directory entry against the file before anything is read,
and a string tag that is malformed or not UTF-8 is refused. Every failure is
`Error{kind: "abif"}`, except a directory over `MAX_ENTRIES` (kind `"limit"`)
and what `fs.readBytes` throws in `open`:

```jennifer
try {
    def f as abif.File init abif.open($path);
} catch (e) {
    io.printf("%s: %s\n", $e.kind, $e.message);
}
```

A `File` holds the whole file, so a 1 MB `.hid` is 1 MB in memory. The deck
has no capabilities.

## Trademarks

Applied Biosystems™, GeneScan™, GlobalFiler™, LIZ™ and POP-7™ are trademarks
of Thermo Fisher Scientific Inc. or its subsidiaries. ABI PRISM™ and other
product, dye and kit names that appear as values in the files this deck
reads (such as `6-FAM` or `GS600LIZ`) may be trademarks of their respective
owners. They are used only to describe those files. This deck is an
independent project, not affiliated with, sponsored or endorsed by Thermo
Fisher Scientific Inc.
