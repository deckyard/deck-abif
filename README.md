# @deckyard/abif

[![test](https://github.com/deckyard/deck-abif/actions/workflows/test.yml/badge.svg)](https://github.com/deckyard/deck-abif/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://deckyard.github.io/deck-abif/)
[![release](https://img.shields.io/github/v/release/deckyard/deck-abif)](https://github.com/deckyard/deck-abif/releases/latest)

Read Applied Biosystems ABIF files in a [Jennifer](https://jennifer-lang.dev/)
program: Sanger traces (`.ab1`), fragment-analysis runs (`.fsa`) and 3500
HID runs (`.hid`). Every element type, raw and analysed traces per dye, dyes,
base calls with qualities and peak locations, and the sample and run
metadata. The directory is checked against the file before anything is read.

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

The traces, peak tables and most dye names of a 3500 HID file are encrypted;
the deck reads that file's metadata, not its signal.

## Development

```sh
tools/check-all.sh                   # the full gate, as CI runs it
jennifer test src/abif_test.j        # the test overlay
tools/check-docs.sh                  # docs against the code
tools/pack.sh dist                   # build the release archive
```

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.

`tools/check-headers.sh` checks every source file's SPDX header against
`deck.toml`. The sample files in `testdata/` have their own licences; see
[testdata/README.md](testdata/README.md).
