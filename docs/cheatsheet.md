<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# abif cheatsheet

Every export of `@deckyard/abif`. Guides are listed in
[the introduction](index.md).

```jennifer
import "@deckyard/abif/" as abif;
```

Every failure is `Error{kind: "abif"}`, except a directory over `MAX_ENTRIES`
(kind `"limit"`) and what `fs.readBytes` throws in `open`. An `f` argument is a `File`; a tag is a `name` (four
characters, such as `DATA`) and a `number`.

## Constants

| Constant | Value | Meaning |
|---|---|---|
| `MAX_ENTRIES` | `65536` | the most directory entries `parse` accepts; real files have 20 to 200 |

## Files and the directory

| Function | Returns | Does |
|---|---|---|
| `parse(data)` | `File` | check the header and every directory entry against `data`, then index them |
| `open(path)` | `File` | `parse` of a file read from disk |
| `parseWith(data, opts)` | `File` | `parse` with `ParseOptions`; lenient: accept rule-breaking entries, list them in `File.issues` |
| `openWith(path, opts)` | `File` | `parseWith` of a file read from disk |
| `tags(f)` | `list of string` | every tag as `NAME` + number (`DATA9`, `PBAS2`), in file order |
| `has(f, name, number)` | `bool` | whether the directory lists a tag |
| `entries(f)` | `list of Entry` | the directory, in file order |
| `entry(f, name, number)` | `Entry` | a tag's directory entry; throws when it is missing |
| `raw(f, name, number)` | `bytes` | a tag's data, whatever its type |

## Values

| Function | Returns | Does |
|---|---|---|
| `tag(f, name, number)` | `Value` | a tag decoded by its element type |
| `text(f, name, number)` | `string` | a `pString`, `cString` or `char` tag as UTF-8 text, untrimmed |
| `textAs(f, name, number, encoding)` | `string` | the same text decoded with a named `encoding` codec, such as `"macintosh"` (Mac OS Roman, Jennifer 0.28.0 on) |
| `ints(f, name, number)` | `list of int` | a `byte`, `char` (0 to 255), `word`, `short` or `long` tag |
| `floats(f, name, number)` | `list of float` | a `float` or `double` tag |
| `typeName(elementType)` | `string` | `short`, `pString`, `user`, ...; `unknown` for a code the specification does not name |

## The run

| Function | Returns | Does |
|---|---|---|
| `rawTrace(f, dye)` | `list of int` | the raw signal of a dye: `DATA` 1 to 4, then 105 and up |
| `analysedTrace(f, dye)` | `list of int` | the analysed signal: `DATA` 9 to 12, then 205 and up |
| `dyes(f)` | `list of Dye` | the dyes with names and wavelengths (`Dye#`, `DyeN`, `DyeW`) |
| `calls(f)` | `Calls` | bases, qualities and peak locations as called (`PBAS`, `PCON`, `PLOC` 2) |
| `editedCalls(f)` | `Calls` | the same as edited by a user (number 1) |
| `info(f)` | `Info` | sample, well, instrument, run times and other metadata |

## Types

### `File`

The directory is one list per `Entry` field, so a `File` holds none of the
deck's structs and is not rebuilt each time it is passed to the deck;
`entries` and `entry` return `Entry` values.

| Field | Meaning |
|---|---|
| `version as int` | the format version: 101 in `.ab1` and `.fsa`, 300 in 3500 HID files |
| `names as list of string` | each entry's tag name, in file order |
| `numbers as list of int` | each entry's tag number |
| `elementTypes as list of int` | each entry's element type |
| `elementSizes as list of int` | each entry's element size |
| `counts as list of int` | each entry's element count |
| `dataSizes as list of int` | each entry's data size |
| `offsets as list of int` | each entry's data offset |
| `index as map of string to int` | the position of each tag in those lists, keyed `NAME` + number |
| `data as bytes` | the whole file |
| `issues as list of string` | the rules a leniently parsed file breaks, one message each; empty after a strict parse |

### `ParseOptions`

| Field | Meaning |
|---|---|
| `lenient as bool` | accept entries with an element type or size below 1, an element size their type does not have, a data size other than count x element size, a repeated tag (the first is kept), or a tag name with bytes over 126 (read as ISO 8859-1), and list them in `File.issues`; the header, control characters in names, negative numbers and data ranges are still checked |

### `Entry`

| Field | Meaning |
|---|---|
| `name as string` | the tag name, such as `DATA` |
| `number as int` | the tag number |
| `elementType as int` | the element type code |
| `elementSize as int` | bytes per element |
| `count as int` | the number of elements |
| `dataSize as int` | bytes of data, `count * elementSize` |
| `offset as int` | where the data starts in the file; 4 bytes or less sit in the entry itself |

### `Value`

| Variant | Payload | Holds |
|---|---|---|
| `Ints` | `values` (`list of int`) | `byte`, `word`, `short`, `long` elements |
| `Floats` | `values` (`list of float`) | `float`, `double` elements |
| `Chars` | `data` (`bytes`) | `char` elements: text such as `PBAS`, or numbers such as `PCON` |
| `Text` | `value` (`string`) | a `pString` or `cString` |
| `Dates` | `values` (`list of Date`) | `date` elements |
| `Times` | `values` (`list of Time`) | `time` elements |
| `Thumbs` | `values` (`list of Thumb`) | `thumb` elements |
| `Bools` | `values` (`list of bool`) | `bool` elements |
| `Raw` | `elementType` (`int`), `data` (`bytes`) | any other type: user types, obsolete ones, encrypted HID types |

### `Date`

| Field | Meaning |
|---|---|
| `year as int` | the year |
| `month as int` | the month as stored |
| `day as int` | the day as stored |

### `Time`

| Field | Meaning |
|---|---|
| `hour as int` | the hour as stored |
| `minute as int` | the minute as stored |
| `second as int` | the second as stored |
| `hundredths as int` | hundredths of a second as stored; some instruments write values above 99 |

### `Thumb`

| Field | Meaning |
|---|---|
| `d as int` | the first 32-bit field |
| `u as int` | the second 32-bit field |
| `c as int` | the first byte field |
| `n as int` | the second byte field |

### `Dye`

| Field | Meaning |
|---|---|
| `number as int` | the dye number, also its trace's |
| `name as string` | its name, such as `6-FAM`; `""` when absent or encrypted |
| `wavelength as int` | its emission wavelength in nm; 0 when absent or not one integer |

### `Calls`

| Field | Meaning |
|---|---|
| `bases as string` | the called bases, IUPAC codes |
| `qualities as list of int` | one quality value per base, 0 to 255; empty when the file has none |
| `peaks as list of int` | one peak location (a scan number) per base; empty when the file has none |

### `Info`

Text fields have trailing spaces and NULs removed and are `""` when the file
does not have them as text.

| Field | Meaning |
|---|---|
| `sample as string` | the sample name (`SMPL`) |
| `well as string` | the well, such as `B9` (`TUBE`) |
| `lane as int` | the capillary or lane (`LANE`); 0 when absent or not one integer |
| `instrument as string` | the instrument name and serial number (`MCHN`) |
| `model as string` | the instrument model, such as `3730` (`MODL`) |
| `runName as string` | the run name (`RunN`) |
| `runModule as string` | the run module (`RMdN`) |
| `dyeSet as string` | the dye set (`DySN`) |
| `polymer as string` | the polymer (`GTyp`) |
| `sizeStandard as string` | the size standard of a fragment run (`StdF`) |
| `runStart as string` | `YYYY-MM-DD HH:MM:SS` from `RUND` / `RUNT` 1 |
| `runFinish as string` | from `RUND` / `RUNT` 2 |
| `collectionStart as string` | from `RUND` / `RUNT` 3 |
| `collectionFinish as string` | from `RUND` / `RUNT` 4 |
