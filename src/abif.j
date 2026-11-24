# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * Read Applied Biosystems™ ABIF files, the container their capillary
 * sequencers write: Sanger traces (`.ab1`), fragment-analysis runs (`.fsa`)
 * and 3500-series HID runs (`.hid`). The layout follows Applied Biosystems'
 * "ABIF File Format Specification" (2009).
 *
 * An ABIF file is a directory of tagged elements: each entry names a tag
 * (four characters, such as `DATA` or `PBAS`) and a number, and holds an
 * array of one element type. `parse` checks the whole directory against the
 * file before anything is read; `tag` decodes one entry into a `Value`, and
 * `text`, `ints` and `floats` read one when its type is known. The usual
 * contents have their own readers: `rawTrace` and `analysedTrace` (the
 * detector signal per dye), `dyes`, `calls` (bases, qualities and peak
 * locations of a sequencing run) and `info` (sample and run metadata).
 *
 * A 3500 HID file stores its traces, peak tables and most dye names as
 * element types 28 to 34, which the published format does not define and
 * which are encrypted; they read as `Value.Raw`, and the trace readers
 * refuse them. Its sample and run metadata read as usual.
 *
 * Every failure is `Error{kind: "abif"}`, except a directory with more than
 * `MAX_ENTRIES` entries, which is kind `"limit"`.
 *
 * | topic | covers |
 * | --- | --- |
 * | `core` | `File`, `Entry`, `parse`, `open`, the directory |
 * | `values` | element types, `Value`, `tag`, `text`, `ints`, `floats`, `raw` |
 * | `run` | traces, dyes, base calls, run metadata |
 *
 * @module abif
 * @example
 *   import "@deckyard/abif/" as abif;
 *
 *   def f as abif.File init abif.open("sample.ab1");
 *   def c as abif.Calls init abif.calls($f);
 *   io.printf("%s: %d bases\n", abif.info($f).sample, len($c.bases));
 */
use binary;
use convert;
use encoding;
use fs;
use io;
use maps;

include "topics/core.j";
include "topics/values.j";
include "topics/run.j";
