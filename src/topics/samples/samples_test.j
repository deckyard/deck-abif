# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

# abif - tests on real instrument files in testdata/ (see its README). The
# expected sequences, qualities, samples, wells, models and run times are
# Biopython's (Tests/Abi/test_data and test_SeqIO_AbiIO.py), not this deck's
# own output. jvc runs the overlays from a copy of src/ alone, where
# testdata/ is missing: these tests then return at once. Spliced into
# abif_test.j via include.

/**
 * True beside testdata/, false in a copy of src/ alone.
 *
 * @return {bool} whether the sample files can be read
 */
func haveTestdata() {
    return fs.isDir("testdata");
}

/**
 * The sum of a list.
 *
 * @param xs {list of int} the values
 * @return {int} their sum
 */
func sumOf(xs as list of int) {
    def total as int init 0;
    for (def x in $xs) {
        $total = $total + $x;
    }
    return $total;
}

func testA3730SequencingRun() {
    if (not haveTestdata()) {
        return null;
    }
    def f as File init open("testdata/3730.ab1");
    testing.assertEqual($f.version, 101);
    testing.assertEqual(len(entries($f)), 123);
    def i as Info init info($f);
    testing.assertEqual($i.sample, "226032_C-ME-18_pCAGseqF");
    testing.assertEqual($i.well, "B9");
    testing.assertEqual($i.model, "3730");
    testing.assertEqual($i.dyeSet, "Z-BigDyeV3");
    testing.assertEqual($i.polymer, "POP7");
    testing.assertEqual($i.instrument, "ABI-3730-XL-1404-021");
    testing.assertEqual($i.runStart, "2009-12-12 09:56:53");
    testing.assertEqual($i.runFinish, "2009-12-12 11:44:49");
    def c as Calls init calls($f);
    testing.assertEqual(len($c.bases), 1165);
    testing.assertEqual($c.bases[..30], "GGGCGAGCKYYAYATTTTGGCAAGAATTGA");
    testing.assertEqual($c.bases[1135..], "CATCGAGCTGAAAGGGGCAYCGCACCTTTC");
    testing.assertEqual($c.qualities[..12], [20, 3, 4, 4, 4, 6, 4, 4, 0, 0, 0, 6]);
    testing.assertEqual($c.qualities[1159..], [3, 12, 1, 11, 20, 4]);
    testing.assertEqual(sumOf($c.qualities), 52233);
    testing.assertEqual($c.peaks[..6], [2, 13, 38, 51, 67, 78]);
    testing.assertEqual(sumOf($c.peaks), 8469398);
    testing.assertEqual(editedCalls($f), $c);
    def r as list of int init rawTrace($f, 1);
    testing.assertEqual(len($r), 16961);
    testing.assertEqual($r[..6], [-1, -15, 11, 1, -2, 0]);
    testing.assertEqual(sumOf($r), 1274722);
    testing.assertEqual(len(analysedTrace($f, 4)), 16302);
    testing.assertEqual(analysedTrace($f, 4)[16299..], [335, 346, 354]);
    testing.assertEqual(
        dyes($f),
        [
            Dye{number: 1, name: "Dye1", wavelength: 540},
            Dye{number: 2, name: "Dye2", wavelength: 568},
            Dye{number: 3, name: "Dye3", wavelength: 595},
            Dye{number: 4, name: "Dye4", wavelength: 615}
        ]);
    testing.assertEqual(floats($f, "Scal", 1), [2.0]);
    testing.assertEqual(text($f, "FWO_", 1), "GATC");
}

func testA310SequencingRun() {
    if (not haveTestdata()) {
        return null;
    }
    def f as File init open("testdata/310.ab1");
    def i as Info init info($f);
    testing.assertEqual($i.sample, "D11F");
    testing.assertEqual($i.well, "C5");
    testing.assertEqual($i.model, "310");
    testing.assertEqual($i.lane, 15);
    testing.assertEqual($i.runStart, "2009-02-19 01:19:30");
    testing.assertEqual($i.runFinish, "2009-02-19 04:04:15");
    def c as Calls init calls($f);
    testing.assertEqual(len($c.bases), 868);
    testing.assertEqual($c.bases[..30], "TGATNTTNACNNTTTTGAANCANTGAGTTA");
    testing.assertEqual($c.bases[838..], "NNNNTCNCTNCNCNCCCCNCCCNNNNNNNG");
    testing.assertEqual(sumOf($c.qualities), 0);
    testing.assertEqual(sumOf($c.peaks), 4267632);
    testing.assertEqual(sumOf(rawTrace($f, 1)), 6003661);
    testing.assertEqual(
        dyes($f),
        [
            Dye{number: 1, name: "Joe", wavelength: 0},
            Dye{number: 2, name: "Fam", wavelength: 0},
            Dye{number: 3, name: "Tamra", wavelength: 0},
            Dye{number: 4, name: "Rox", wavelength: 0}
        ]);
    testing.assertEqual(
        tag($f, "THUM", 1),
        Value.Thumbs{values: [Thumb{d: 211557858, u: -1366584667, c: 151, n: 150}]});
    testing.assertEqual(text($f, "CMNT", 1), "Hassan,Ina");
}

func testAFragmentRun() {
    if (not haveTestdata()) {
        return null;
    }
    def f as File init open("testdata/test.fsa");
    # Biopython's abif_raw_keys for this file
    def want as list of string init [
        "RGNm1",
        "MCHN1",
        "DyeW1",
        "Dye#1",
        "InVt1",
        "EVNT4",
        "HCFG1",
        "RunN1",
        "PXLB1",
        "DyeB1",
        "DCHT1",
        "DyeN3",
        "DyeW2",
        "DyeW3",
        "DyeN2",
        "SVER3",
        "MODL1",
        "SpNm1",
        "HCFG2",
        "RMdX1",
        "LANE1",
        "DATA5",
        "EVNT2",
        "DATA7",
        "SVER4",
        "RMdV1",
        "RUND1",
        "HCFG3",
        "RUNT1",
        "RUNT2",
        "DyeB4",
        "User1",
        "RGOw1",
        "DyeW4",
        "DATA1",
        "CTID1",
        "DyeB3",
        "DATA2",
        "HCFG4",
        "SMLt1",
        "EVNT3",
        "CpEP1",
        "EVNT1",
        "Tmpr1",
        "Satd1",
        "GTyp1",
        "DySN1",
        "Scan1",
        "CTTL1",
        "RUNT3",
        "RPrV1",
        "RUND4",
        "LIMS1",
        "DATA4",
        "DATA6",
        "DyeB2",
        "DyeN4",
        "NLNE1",
        "InSc1",
        "OfSc1",
        "RMdN1",
        "DATA3",
        "MODF1",
        "NAVG1",
        "Rate1",
        "SMED1",
        "RUNT4",
        "LNTD1",
        "SVER1",
        "RUND2",
        "DSam1",
        "CTNM1",
        "Scal1",
        "SCAN1",
        "TUBE1",
        "DyeN1",
        "CTOw1",
        "RUND3",
        "RMXV1",
        "EPVt1",
        "LsrP1",
        "RPrN1",
        "DATA8"
    ];
    testing.assertEqual(lists.sort(tags($f)), lists.sort($want));
    def i as Info init info($f);
    testing.assertEqual($i.sample, "");
    testing.assertEqual($i.well, "E1");
    testing.assertEqual($i.model, "3100");
    testing.assertEqual($i.dyeSet, "F");
    testing.assertEqual($i.polymer, "POP7");
    testing.assertEqual($i.runStart, "2004-11-22 11:58:35");
    testing.assertEqual($i.runFinish, "2004-11-22 12:42:08");
    testing.assertEqual(
        tag($f, "RUNT", 2),
        Value.Times{values: [Time{hour: 12, minute: 42, second: 8, hundredths: 234}]});
    testing.assertEqual(
        dyes($f),
        [
            Dye{number: 1, name: "5-FAM", wavelength: 530},
            Dye{number: 2, name: "JOE", wavelength: 554},
            Dye{number: 3, name: "NED", wavelength: 575},
            Dye{number: 4, name: "ROX", wavelength: 607}
        ]);
    def r as list of int init rawTrace($f, 1);
    testing.assertEqual(len($r), 8531);
    testing.assertEqual($r[..6], [0, 7, 0, 2, -1, 0]);
    try {
        calls($f);
        missed("calls of a fragment run");
    } catch (e) {
        testing.assertContains($e.message, "is it a fragment run?");
    }
}

func testA3500HidRun() {
    if (not haveTestdata()) {
        return null;
    }
    def f as File init open("testdata/GF_8_FTA_H01_08.hid");
    testing.assertEqual($f.version, 300);
    testing.assertEqual(len(entries($f)), 174);
    testing.assertEqual(entries($f)[0], entry($f, "AAct", 1));
    def i as Info init info($f);
    testing.assertEqual($i.sample, "Sample");
    testing.assertEqual($i.well, "H01");
    testing.assertEqual($i.instrument, "3500 Instrument");
    testing.assertEqual($i.model, "");
    testing.assertEqual($i.dyeSet, "");
    testing.assertEqual($i.sizeStandard, "GS600LIZ");
    testing.assertEqual($i.polymer, "POP4");
    testing.assertEqual($i.runStart, "2012-09-28 15:41:03");
    def names as list of string init [];
    def waves as list of int init [];
    for (def d in dyes($f)) {
        $names[] = $d.name;
        $waves[] = $d.wavelength;
    }
    testing.assertEqual($names, ["", "", "", "", "", " SID"]);
    testing.assertEqual($waves, [522, 554, 575, 595, 655, 620]);
    def v as Value init tag($f, "DATA", 105);
    match ($v) {
        when Raw(r) {
            testing.assertEqual($r.elementType, 28);
            testing.assertEqual(len($r.data), 19280);
        }
        else { missed("DATA 105 as Raw"); }
    }
    try {
        rawTrace($f, 1);
        missed("an encrypted trace");
    } catch (e) {
        testing.assertContains($e.message, "(3500 HID files encrypt these)");
    }
    testing.assertEqual(floats($f, "SzFt", 2), [0.9995559815802043]);
    testing.assertEqual(tag($f, "AAct", 1), Value.Bools{values: [true]});
}

func testATruncatedFile() {
    if (not haveTestdata()) {
        return null;
    }
    try {
        open("testdata/fake.ab1");
        missed("fake.ab1");
    } catch (e) {
        testing.assertEqual($e.message, "not an ABIF file: 26 bytes, the header alone is 128");
    }
}
