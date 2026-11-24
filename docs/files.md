<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# The three file types

`.ab1`, `.fsa` and `.hid` are one container, ABIF (see
[The format](format.md)): a 128-byte header, a directory of tagged entries,
and their data. What differs is the version, which tags an instrument
writes, and in a `.hid` file what it encrypts. The deck reads all three with
the same `open`; nothing depends on the file name.

The tag lists below are what the sample files in `testdata/` hold (a 310
and a 3730 `.ab1`, a 3100 `.fsa`, a 3500 `.hid`). Other instruments and
software versions add or drop tags, so test for a tag with `has` rather than
from the extension.

| | `.ab1` | `.fsa` | `.hid` |
|---|---|---|---|
| Run | Sanger sequencing | fragment analysis | fragment analysis, human identification |
| Version | 101 | 101 | 300 |
| Dyes | 4 | 4 to 6 | 6 in the sample |
| Base calls | `PBAS`, `PCON`, `PLOC` | none | none |
| Traces | raw and analysed | raw (analysed once analysed) | raw and analysed, encrypted |
| Size in the samples | 220 to 300 KB, 113 to 123 tags | 78 KB, 83 tags | 800 KB, 174 tags |

## What all three carry

Every sample has the raw traces and the run's instrument record:

- `DATA` 1-4 (raw traces, one per dye), `DATA` 5-8 (electrophoresis
  voltage, current, laser power and oven temperature during the run)
- `Dye#` (the dye count) and `DyeN` (dye names)
- `MCHN`, `MODL` (instrument and model), `TUBE` (well), `LANE`
- `RUND` / `RUNT` 1-4 (run and collection start and stop)
- `EVNT` 1-4 (start and stop of run and collection), the settings `EPVt`
  (electrophoresis voltage), `InSc` and `InVt` (injection time and
  voltage), `LsrP` (laser power), `Tmpr` (run temperature) and `Rate`
  (scanning rate), `Scan` (the number of scans), `SVER` (software and
  firmware versions), `MODF` (data collection module), `SMED` and `SMLt`
  (polymer lot expiry and number), `User`

## `.ab1`: a Sanger trace

A sequencing run: four dyes, one per base, read in the order `FWO_` gives
(`GATC`). Besides the common tags it carries:

- `DATA` 9-12, the analysed traces, one per base
- `PBAS`, `PCON`, `PLOC` 1 and 2: bases, quality values and peak locations,
  as edited (1) and as called (2); read them with `calls` and `editedCalls`
- `SMPL` (sample name), `PDMF` (mobility file), `S/N%` (signal strength per
  dye), `SPAC` (peak spacing and basecaller), `B1Pt` (reference scan of the
  mobility curves), `phAR`, `phCH`, `phDY`, `phQL`, `phTR` (basecalling
  settings), `RevC` (whether the sequence is complemented)
- in the 310 file, `MTXF` / `MTRX` / `MTRD` (the spectral matrix), `CMNT`
  (a comment) and `THUM` (a `thumb` fingerprint); in the 3730 file, `NOIS`
  (noise per dye) and `DyeW` (wavelengths)

```jennifer
def f as abif.File init abif.open("sample.ab1");
def c as abif.Calls init abif.calls($f);
io.printf("%d bases, first ten %s\n", len($c.bases), $c.bases[..10]);
```

## `.fsa`: a fragment-analysis run

Sized DNA fragments (microsatellites, AFLP, STRs) in up to six dyes, one of
them an internal size standard. The sample `.fsa` comes straight off the
instrument:

- `DATA` 1-8 only: raw traces and the run's readings; the analysed traces
  (`DATA` 9-12) appear once analysis software has written them
- no base calls: `calls` refuses the file
- `DyeN`, `DyeW` (wavelengths) and `DyeB` per dye, `DySN` (dye set),
  `GTyp` (polymer), `RunN`, `RMdN` (run and run module), `SpNm`
- no `SMPL`: this file's sample name is empty in `info`

A fifth or sixth dye goes into `DATA` 105 and 106 (raw) and 205 and 206
(analysed); `rawTrace($f, 5)` finds them.

```jennifer
def f as abif.File init abif.open("run.fsa");
for (def d in abif.dyes($f)) {
    io.printf("%s: %d scans\n", $d.name, len(abif.rawTrace($f, $d.number)));
}
```

## `.hid`: a 3500 HID run

The 3500 series' human-identification format: ABIF version 300, six dyes
(the sample is a GlobalFiler™ run, size standard `GS600LIZ`). It adds the
results of the instrument's own sizing and the record of every consumable:

- `DATA` 1-4 and 105-106 (raw), 9-12 and 205-206 (analysed), `DATA` 5-8
- `StdF` (size standard), `SzFt` (the sizing fit), `SMap` (the size map),
  `Peak` 1-25 (peak tables), `ScPa` (the size caller's parameters), `SamQ`
- `AsyN`, `AsyV`, `AsyC` (assay name, version and contents), `AVld`
- consumables: anode buffer (`ABED`, `ABID`, `ABLt`, `ABRn`, `ABTp`),
  capillary array (`CAED`, `CAID`, `CALt`, `CARn`, `CASN`), cathode buffer
  (`CBED`, `CBID`, `CBLt`, `CBRn`, `CBTp`), polymer (`SMID`, `SMRn`)
- `InjN` (injection), `SpeN` (spectral calibration), `RNmF` (Raman
  normalisation), `OvrI` / `OvrV` (values over 32767 that the 16-bit trace
  could not hold), `AmbT` (ambient temperature), `CkSm` (checksum),
  `AAct`, `AUDT` (audit trail, XML)

Most of the measured data is stored as element types 28 to 34, which the
published format does not define and which are encrypted: every `DATA`
trace, the peak tables, the size map and fit, the assay contents, the
saturation and offset scans, dye names 1 to 5, the dye set and the model.
The deck returns them as `Value.Raw`, `rawTrace` refuses them, and `info`
and `dyes` leave those names `""`. Sample name, well, instrument, run times,
size standard, wavelengths and the consumable records read as usual.

```jennifer
def f as abif.File init abif.open("run.hid");
def i as abif.Info init abif.info($f);
io.printf("%s on %s, size standard %s\n", $i.sample, $i.instrument, $i.sizeStandard);
```

A `.hid` whose traces and peak tables are plain data - element type 4
(`short`), as in an `.fsa` - reads like an `.fsa`: `rawTrace`,
`analysedTrace` and `ints` return them. `tag` names the type of any entry,
so one look at `DATA 9` tells which kind a file is. Reading the signal of
an encrypted HID run needs Applied Biosystems™' software.
