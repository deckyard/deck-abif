<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# The run

## Traces and dyes

Each dye has a raw trace, the detector signal per scan, and an analysed one,
after the instrument software's baseline and spectral correction.
`rawTrace` and `analysedTrace` take the dye number and know where it is
stored: dyes 1 to 4 in `DATA` 1 to 4 and 9 to 12, a fifth and later dye in
`DATA` 105 and up and 205 and up. `DATA` 5 to 8 are instrument readings
(voltage, current, power, temperature), not dyes.

```jennifer
for (def d in abif.dyes($f)) {
    def trace as list of int init abif.rawTrace($f, $d.number);
    io.printf("%s at %d nm: %d scans\n", $d.name, $d.wavelength, len($trace));
}
```

`dyes` counts the dyes from `Dye#` (or the `DyeN` tags when it is missing)
and reads each name and wavelength; one the file lacks, or does not store
as text or one integer (a HID file encrypts most names), is `""` or 0.

## Base calls

A sequencing run (`.ab1`) carries the basecaller's result: the bases
(`PBAS`), a quality value per base (`PCON`) and the scan where each base's
peak is (`PLOC`). `calls` reads them as called (number 2), `editedCalls` as
a user edited them (number 1); in an unedited file the two are equal.

```jennifer
def c as abif.Calls init abif.calls($f);
for (def i in 0..len($c.qualities)) {
    if ($c.qualities[$i] < 20) {
        io.printf("weak call %s at %d\n", $c.bases[$i..$i + 1], $i + 1);
    }
}
```

A fragment run has no base calls, and `calls` says so. Qualities or peaks a
file lacks are an empty list; when they are there, they must have one entry
per base.

## Metadata

`info` collects the sample and run metadata into one `Info`: sample name,
well, lane, instrument, model, run name and module, dye set, polymer, size
standard, and the start and end of the run and of data collection as
`YYYY-MM-DD HH:MM:SS`.

```jennifer
def i as abif.Info init abif.info($f);
io.printf("%s in %s on %s, %s\n", $i.sample, $i.well, $i.model, $i.runStart);
```

Fixed-width fields are padded (`MODL` is `"310 "`, `GTyp` `"POP7"` and 28
spaces), so `info` removes trailing spaces and NULs; `text` returns the
stored value. A field the file lacks, or keeps encrypted, is `""`.

## 3500 HID files

A `.hid` file is ABIF version 3.00. Its sample and run metadata read as
usual, but the traces, the peak tables and most dye names are stored as
element types 28 to 34, which the published format does not define. Their
bytes look random, their sizes are whole 8-byte blocks, and equal plaintexts
give equal blocks: they are encrypted. `tag` returns them as `Raw`, the trace
readers refuse them, and `dyes` and `info` leave their names `""`. Reading
the signal of a HID run needs Applied Biosystems' software.
