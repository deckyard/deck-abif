<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Design

## Scope

The deck reads Applied Biosystems ABIF files, the container their capillary
sequencers write: Sanger traces (`.ab1`), fragment-analysis runs (`.fsa`)
and 3500-series HID runs (`.hid`). It has three parts:

- **The container** (`core`): `parse` / `open` check the header and the
  whole directory; `tags`, `entries`, `has`, `entry` and `raw` list and
  look up entries.
- **Values** (`values`): `tag` decodes one entry into a `Value`, and `text`,
  `ints` and `floats` read one whose type is known.
- **The run** (`run`): `rawTrace` and `analysedTrace` per dye, `dyes`,
  `calls` / `editedCalls` (bases, qualities, peak locations of a sequencing
  run) and `info` (sample and run metadata).

It deliberately stops at reading:

- **No writing.** Instruments write ABIF; analysis reads it.
- **No signal analysis.** Baseline correction, peak detection, sizing and
  allele calling belong to the planned fragment-analysis work in
  `@deckyard/forensicgenetics`, which is to build on this deck.
- **No decryption of HID data.** A 3500 HID file stores its traces, peak
  tables, size map and most dye names as element types 28 to 34, which the
  published format does not define and which are encrypted. There is no
  public algorithm (NCBI's OSIRIS, which reads these files, has none either),
  so the deck reads them as `Value.Raw` and its trace readers refuse them;
  the sample and run metadata read as usual.

## Decisions

- **A separate deck.** Both this deck and the planned fragment analysis in
  `@deckyard/forensicgenetics` read ABIF, so the container lives on its own
  rather than inside either.
- **The published specification.** The layout follows Applied Biosystems'
  "ABIF File Format Specification" (2009): a 128-byte header (`ABIF`, a
  version, the directory's own entry), a directory of 28-byte entries, all
  big-endian, data of four bytes or less held inline in the entry. Versions
  1.xx to 3.xx (100 to 399) are read.
- **Strict parsing, checked before any read.** `parse` checks the magic, the
  version, the header's `tdir` entry, the entry count against
  `MAX_ENTRIES`, that every tag name is printable ASCII, the element size
  of every defined type, that `dataSize` equals `count` times the element
  size, that data lies inside the file and past the header, and that no tag
  appears twice. A `pString` must have a length byte of `count - 1`, a
  `cString` exactly one NUL, at its end; text must be UTF-8 (`raw` gives the
  bytes of anything else). A malformed file fails at `parse`, not at some
  later read.
- **The header's own entry is read by hand.** Its data size is the space
  reserved for the directory (3584 bytes for 113 entries in a 310 file), not
  `count` times 28, so the generic entry check would refuse it.
- **Data handles are ignored.** Entry bytes 24 to 27 are reserved by the
  specification and filled by HID files; nothing depends on them.
- **Every element type decoded.** `Value` has one variant per family
  (`Ints`, `Floats`, `Chars`, `Text`, `Dates`, `Times`, `Thumbs`, `Bools`,
  `Raw`). `char` is `Chars` (bytes), not text, because `PCON` is `char`
  holding numbers; `text` decodes it as UTF-8 and `ints` as 0 to 255. Bytes
  and thumb bytes are unsigned, as the specification and seqinr have them.
- **Dates and times are data, not structure.** They are not range-checked:
  a real `.fsa` has a time with 234 hundredths.
- **Lookups take four-character names.** The index key is the name followed
  by the number, so (`DATA1`, 0) would otherwise find `DATA` 10.
- **Tolerant metadata, strict structure.** `info` trims trailing spaces and
  NULs (`MODL` is `"310 "`) where `text` never trims; a non-text
  (encrypted) field is `""`, and `info.lane` and a dye's wavelength are 0
  unless the tag is one integer element. `Dye#` stays strict, since it sets
  the number of dyes. `calls` compares `PCON` and `PLOC` with the byte
  count of `PBAS`, not its character count.
- **Trace numbers.** Raw dye n is `DATA` n for n up to 4, else 100 + n;
  analysed dye n is 8 + n, else 200 + n (the HID sample has 105, 106, 205,
  206).
- **`File` holds plain lists.** The directory is kept as parallel lists
  (`names`, `numbers`, ...), not a `list of Entry`, because a value holding
  the deck's own structs is rebuilt on every call into the deck: one `tag`
  call per entry of an 800 KB `.hid` allocated 63 MB that way and 0.46 MB
  now. `entries` and `entry` build `Entry` values on demand.
- **A topics deck.** `src/abif.j` holds the module docblock and every `use`,
  and includes the three topics, so one import gives the whole surface.

## Errors

Every failure is `Error{kind: "abif"}` with a message that names the entry
and what is wrong, without an `abif: ` prefix (the kind says where it comes
from, so printing both does not repeat it): a file that is not ABIF, a malformed header or entry,
data outside the file, a missing tag, a type that does not fit the reader
asked for (with "3500 HID files encrypt these" for the undefined types),
invalid text. An element-size mismatch is malformed input, so it is kind
`"abif"` too. The one exception is a directory with more than `MAX_ENTRIES`
entries, which is kind `"limit"`, the generic kind for a reached cap. The
deck reads only local bytes, so there is no error struct: there is no
server status or code to carry.

## Security and limits

The deck treats every file as hostile. All offsets, counts and sizes are
checked against the file before anything is read, so a corrupt directory
cannot make a read run past the data or allocate from a forged count. The
directory is capped at `MAX_ENTRIES` (65536) entries. `open` reads the
whole file into memory and there is no file-size cap. No
capability is needed.

## Testing and validation

`src/abif_test.j` includes the topic overlays. Most tests build ABIF files
in code (`build`, with `put` to corrupt a field), so they run from a bare
copy of `src/`, as `jvc` runs overlays; they cover the element types,
every refusal of `parse`, lookups, the readers and the `"limit"` cap.
`src/topics/samples/samples_test.j` reads the files in `testdata/`
(Biopython's `.ab1` / `.fsa` samples under the Biopython License, and one
public-domain OSIRIS GlobalFiler `.hid`) and checks them against
Biopython's expected values; it returns early when `testdata/` is missing.

- **Biopython 1.88** (2026-11-14), nine sample files, 1025 tags: the only
  differences are Biopython's (it reads `byte` and thumb bytes as signed,
  where the specification and seqinr say unsigned, and collapses a
  two-element bool to one) and the deck's refusal of a comment that is not
  UTF-8.
- **Independent review**: an empty-`cString` crash, lookup-key collisions,
  the byte versus character count in `calls`, and `info` / `dyes` failing on
  non-integer fields were found and fixed with tests.
- **Mutation fuzz** (2026-11-13): random bytes written into the header and
  directory of the samples, 900 files through every reader, gave only
  `"abif"` errors.
- **`jennifer-tiny`**: the examples run on it (checked 2026-11-13), though
  the manifest does not declare it.

## Known limitations and open questions

- HID traces and peak tables are encrypted and stay unreadable; for HID
  runs, only metadata is available.
- A file with a comment or other text field that is not UTF-8 is read, but
  `text` on that field throws; `raw` returns its bytes.
- The 0.1.0 tag exists; its registry publish failed on 2026-11-14 (the
  registry did not answer) and is to be retried.

## Dependencies on the interpreter

- The floor is `>=0.26.0`, for the `binary` number readers
  (`binary.readInt`, `binary.readUint`, and the bulk `binary.readInts` and
  `binary.readFloats`).
- Kind `"limit"` for a reached cap follows the error conventions of
  `jennifer` (M28.54, M28.57).
- No capability; the deck uses `fs` only in `open`.
