# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# abif - run: the readers of the usual contents - traces, dyes, base calls
# and run metadata. Spliced into abif.j via include.

/**
 * One dye of the run.
 *
 * @field number {int} the dye number, 1 and up; also its trace's (`rawTrace($f, number)`)
 * @field name {string} its name (`DyeN`), such as `6-FAM`; `""` when the file has none or keeps it encrypted
 * @field wavelength {int} its emission wavelength in nm (`DyeW`); 0 when the file has none or not as one integer
 */
export def struct Dye {
    number as int,
    name as string,
    wavelength as int
};

/**
 * The base calls of a sequencing run, position by position.
 *
 * @field bases {string} the called bases, IUPAC codes such as `ACGTN` (`PBAS`)
 * @field qualities {list of int} each base's quality value, 0 to 255 (`PCON`); empty when the file has none
 * @field peaks {list of int} each base's peak location, a scan number in the traces (`PLOC`); empty when the file has none
 */
export def struct Calls {
    bases as string,
    qualities as list of int,
    peaks as list of int
};

/**
 * The sample and run metadata. Text fields have trailing spaces and NULs
 * removed (fixed-width fields are padded) and are `""` when the file does not
 * have them as text; 3500 HID files keep some encrypted.
 *
 * @field sample {string} the sample name (`SMPL` 1)
 * @field well {string} the well, such as `B9` (`TUBE` 1)
 * @field lane {int} the capillary or lane (`LANE` 1); 0 when absent or not one integer
 * @field instrument {string} the instrument name and serial number (`MCHN` 1)
 * @field model {string} the instrument model, such as `3730` (`MODL` 1)
 * @field runName {string} the run name (`RunN` 1)
 * @field runModule {string} the run module (`RMdN` 1)
 * @field dyeSet {string} the dye set (`DySN` 1)
 * @field polymer {string} the polymer (`GTyp` 1)
 * @field sizeStandard {string} the size standard of a fragment run, such as `GS600LIZ` (`StdF` 1)
 * @field runStart {string} when the run started, `YYYY-MM-DD HH:MM:SS` (`RUND` / `RUNT` 1)
 * @field runFinish {string} when the run stopped (`RUND` / `RUNT` 2)
 * @field collectionStart {string} when data collection started (`RUND` / `RUNT` 3)
 * @field collectionFinish {string} when data collection stopped (`RUND` / `RUNT` 4)
 */
export def struct Info {
    sample as string,
    well as string,
    lane as int,
    instrument as string,
    model as string,
    runName as string,
    runModule as string,
    dyeSet as string,
    polymer as string,
    sizeStandard as string,
    runStart as string,
    runFinish as string,
    collectionStart as string,
    collectionFinish as string
};

/**
 * The raw trace of a dye: the detector signal per scan, before baseline
 * and spectral correction. Dyes 1 to 4 are `DATA` 1 to 4, a fifth and later
 * dye `DATA` 105 and up.
 *
 * @param f {File} the file
 * @param dye {int} the dye number, 1 and up
 * @return {list of int} one value per scan
 * @throws {Error} kind "abif" when the file has no such trace or keeps it encrypted (3500 HID)
 */
export func rawTrace(f as File, dye as int) {
    return trace($f, $dye, false);
}

/**
 * The analysed trace of a dye, as the instrument software corrected it.
 * Dyes 1 to 4 are `DATA` 9 to 12, a fifth and later dye `DATA` 205 and up.
 *
 * @param f {File} the file
 * @param dye {int} the dye number, 1 and up
 * @return {list of int} one value per scan
 * @throws {Error} kind "abif" when the file has no such trace or keeps it encrypted (3500 HID)
 */
export func analysedTrace(f as File, dye as int) {
    return trace($f, $dye, true);
}

/**
 * A trace by dye.
 *
 * @param f {File} the file
 * @param dye {int} the dye number
 * @param analysed {bool} the analysed trace, not the raw one
 * @return {list of int} the trace
 */
func trace(f as File, dye as int, analysed as bool) {
    if ($dye < 1 or $dye > 99) {
        fail(io.sprintf("a dye number is 1 to 99, got %d", $dye));
    }
    def number as int init $dye;
    if ($dye > 4) {
        $number = 100 + $dye;
    }
    if ($analysed) {
        if ($dye > 4) {
            $number = 200 + $dye;
        } else {
            $number = 8 + $dye;
        }
    }
    def e as Entry init entry($f, "DATA", $number);
    if ($e.elementType != 4) {
        fail(mismatch($e, "a trace (short)"));
    }
    return intsOf($f, $e);
}

/**
 * The dyes of the run, from `Dye#` (or, without it, the `DyeN` tags).
 *
 * @param f {File} the file
 * @return {list of Dye} the dyes, by number
 * @throws {Error} kind "abif" when `Dye#` is not one number from 0 to 99, or a dye name is malformed or not UTF-8
 */
export func dyes(f as File) {
    def count as int init 0;
    if (has($f, "Dye#", 1)) {
        def e as Entry init entry($f, "Dye#", 1);
        def t as int init $e.elementType;
        if ($e.count != 1 or ($t != 1 and $t != 3 and $t != 4 and $t != 5)) {
            fail("Dye# 1 is not one number from 0 to 99");
        }
        $count = intsOf($f, $e)[0];
        if ($count < 0 or $count > 99) {
            fail("Dye# 1 is not one number from 0 to 99");
        }
    } else {
        while (has($f, "DyeN", $count + 1)) {
            $count = $count + 1;
        }
    }
    def out as list of Dye init [];
    for (def i in 1..$count + 1) {
        def d as Dye init Dye{number: $i, name: "", wavelength: 0};
        if (has($f, "DyeN", $i) and isText(entry($f, "DyeN", $i))) {
            $d.name = text($f, "DyeN", $i);
        }
        $d.wavelength = oneInt($f, "DyeW", $i);
        $out[] = $d;
    }
    return $out;
}

/**
 * The base calls as the basecaller made them (`PBAS`, `PCON`, `PLOC` 2).
 *
 * @param f {File} the file
 * @return {Calls} bases, qualities and peak locations
 * @throws {Error} kind "abif" when the file has no base calls (a fragment run), or the three disagree in length
 */
export func calls(f as File) {
    return callSet($f, 2);
}

/**
 * The base calls as a user edited them (`PBAS`, `PCON`, `PLOC` 1). In an
 * unedited file they equal `calls`.
 *
 * @param f {File} the file
 * @return {Calls} bases, qualities and peak locations
 * @throws {Error} kind "abif" when the file has no base calls, or the three disagree in length
 */
export func editedCalls(f as File) {
    return callSet($f, 1);
}

/**
 * One set of base calls.
 *
 * @param f {File} the file
 * @param number {int} 1 (edited) or 2 (as called)
 * @return {Calls} the calls
 */
func callSet(f as File, number as int) {
    if (not has($f, "PBAS", $number)) {
        fail(io.sprintf("the file has no base calls (PBAS %d); is it a fragment run?", $number));
    }
    def c as Calls init Calls{bases: text($f, "PBAS", $number), qualities: [], peaks: []};
    # one quality and one peak per base: PBAS is ASCII, but count its bytes,
    # as PCON and PLOC count elements
    def bases as int init entry($f, "PBAS", $number).count;
    if (has($f, "PCON", $number)) {
        $c.qualities = ints($f, "PCON", $number);
        if (len($c.qualities) != $bases) {
            fail(io.sprintf(
                "PCON %d has %d qualities for %d bases",
                $number,
                len($c.qualities),
                $bases));
        }
    }
    if (has($f, "PLOC", $number)) {
        $c.peaks = ints($f, "PLOC", $number);
        if (len($c.peaks) != $bases) {
            fail(io.sprintf(
                "PLOC %d has %d peak locations for %d bases",
                $number,
                len($c.peaks),
                $bases));
        }
    }
    return $c;
}

/**
 * The sample and run metadata.
 *
 * @param f {File} the file
 * @return {Info} the metadata; a field the file lacks is `""` or 0
 * @throws {Error} kind "abif" when a text field is malformed or not UTF-8
 * @example
 *   def i as abif.Info init abif.info($f);
 *   io.printf("%s in %s, %s\n", $i.sample, $i.well, $i.runStart);
 */
export func info(f as File) {
    def lane as int init oneInt($f, "LANE", 1);
    return Info{
        sample: field($f, "SMPL"),
        well: field($f, "TUBE"),
        lane: $lane,
        instrument: field($f, "MCHN"),
        model: field($f, "MODL"),
        runName: field($f, "RunN"),
        runModule: field($f, "RMdN"),
        dyeSet: field($f, "DySN"),
        polymer: field($f, "GTyp"),
        sizeStandard: field($f, "StdF"),
        runStart: stamp($f, 1),
        runFinish: stamp($f, 2),
        collectionStart: stamp($f, 3),
        collectionFinish: stamp($f, 4)
    };
}

/**
 * A tag that holds one integer, as `info` and `dyes` read it.
 *
 * @param f {File} the file
 * @param name {string} the tag name
 * @param number {int} the tag number
 * @return {int} the value; 0 when the tag is absent, not an integer type (encrypted, say) or not one element
 */
func oneInt(f as File, name as string, number as int) {
    if (not has($f, $name, $number)) {
        return 0;
    }
    def e as Entry init entry($f, $name, $number);
    def t as int init $e.elementType;
    if ($e.count != 1 or ($t != 1 and $t != 3 and $t != 4 and $t != 5)) {
        return 0;
    }
    return intsOf($f, $e)[0];
}

/**
 * Whether an entry holds text.
 *
 * @param e {Entry} the entry
 * @return {bool} true for char, pString and cString
 */
func isText(e as Entry) {
    return $e.elementType == 2 or $e.elementType == 18 or $e.elementType == 19;
}

/**
 * A text field of `info`: tag number 1, trailing spaces and NULs removed.
 *
 * @param f {File} the file
 * @param name {string} the tag name
 * @return {string} the text, `""` when absent or not text
 */
func field(f as File, name as string) {
    if (not has($f, $name, 1) or not isText(entry($f, $name, 1))) {
        return "";
    }
    def s as string init text($f, $name, 1);
    while ($s != "" and ($s[len($s) - 1..] == " " or $s[len($s) - 1..] == "\0")) {
        $s = $s[..len($s) - 1];
    }
    return $s;
}

/**
 * A date and time from `RUND` and `RUNT` of one number.
 *
 * @param f {File} the file
 * @param number {int} 1 to 4
 * @return {string} `YYYY-MM-DD HH:MM:SS`, `""` when either is missing or not one element
 */
func stamp(f as File, number as int) {
    if (not has($f, "RUND", $number) or not has($f, "RUNT", $number)) {
        return "";
    }
    def d as Date;
    def t as Time;
    def found as int init 0;
    def dv as Value init tag($f, "RUND", $number);
    match ($dv) {
        when Dates(v) {
            if (len($v.values) == 1) {
                $d = $v.values[0];
                $found = $found + 1;
            }
        }
        else {
        }
    }
    def tv as Value init tag($f, "RUNT", $number);
    match ($tv) {
        when Times(v) {
            if (len($v.values) == 1) {
                $t = $v.values[0];
                $found = $found + 1;
            }
        }
        else {
        }
    }
    if ($found != 2) {
        return "";
    }
    return io.sprintf(
        "%d|pad=4|fill=0-%d|pad=2|fill=0-%d|pad=2|fill=0 %d|pad=2|fill=0:%d|pad=2|fill=0:%d|pad=2|fill=0",
        $d.year,
        $d.month,
        $d.day,
        $t.hour,
        $t.minute,
        $t.second);
}
