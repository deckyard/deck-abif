# @deckyard/abif

[![test](https://github.com/deckyard/deck-abif/actions/workflows/test.yml/badge.svg)](https://github.com/deckyard/deck-abif/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://deckyard.github.io/deck-abif/)
[![release](https://img.shields.io/github/v/release/deckyard/deck-abif)](https://github.com/deckyard/deck-abif/releases/latest)

Read Applied Biosystems™ ABIF files in a [Jennifer](https://jennifer-lang.dev/)
program: Sanger traces (`.ab1`), fragment-analysis runs (`.fsa`) and 3500
HID runs (`.hid`). Every element type, raw and analysed traces per dye, dyes,
base calls with qualities and peak locations, and the sample and run
metadata. The directory is checked against the file before anything is read.

ABIF is a publicly documented file format: Applied Biosystems publishes
the "ABIF File Format Specification" for software that reads its
instruments' files, and this deck implements that specification. What the
specification leaves undocumented - the element types 3500 HID files
encrypt, and user-defined structures (types 1024 and up) - is given as raw
bytes, not interpreted.

**[Documentation](https://deckyard.github.io/deck-abif/)**

## Install

```sh
jvc add @deckyard/abif
```

This vendors the deck to `vendor/<scope>/abif/`. Without `jvc`, unpack the
`src/` subtree of a release archive (`<scope>-abif-<version>.tar.gz`) there.

## Usage

```jennifer
import "@deckyard/abif/" as abif;

def f as abif.File init abif.open("sample.ab1");
def i as abif.Info init abif.info($f);
def c as abif.Calls init abif.calls($f);
io.printf("%s (%s): %d bases\n", $i.sample, $i.well, len($c.bases));
```

## Requirements

Jennifer 0.27.0 or newer. No capabilities.

`.ab1` and `.fsa` files read in full: traces, peak tables, base calls and
metadata. A `.hid` file reads in full only where its traces and peak tables
are plain data, element type 4 (`short`), as in an `.fsa`. In the usual 3500
HID file they are encrypted (element types 28 to 34): the deck reads that
file's metadata, not its signal.

## Development

```sh
tools/check-all.sh                   # the full gate, as CI runs it
jennifer test src/abif_test.j        # the test overlay
tools/check-docs.sh                  # docs against the code
tools/pack.sh dist                   # build the release archive
```

## Trademarks

Applied Biosystems™, GeneScan™, GlobalFiler™, LIZ™ and POP-7™ are trademarks
of Thermo Fisher Scientific Inc. or its subsidiaries. ABI PRISM™ and other
product, dye and kit names that appear as values in the files this deck
reads (such as `6-FAM` or `GS600LIZ`) may be trademarks of their respective
owners. They are used only to describe those files. This deck is an
independent project, not affiliated with, sponsored or endorsed by Thermo
Fisher Scientific Inc.

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.

`tools/check-headers.sh` checks every source file's SPDX header against
`deck.toml`. The sample files in `testdata/` have their own licences; see
[testdata/README.md](testdata/README.md).
