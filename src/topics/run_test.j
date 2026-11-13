# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

# abif - white-box tests for the run topic. Spliced into abif_test.j via
# include.

/**
 * A five-dye fragment run, with the fifth dye's traces at 105 and 205.
 *
 * @return {File} the parsed file
 */
func fiveDyes() {
    def tags as list of TestTag init [
        shortTag("Dye#", 1, [5]),
        TestTag{name: "DATA", number: 6, elementType: 4, elementSize: 2, data: packed([0], 2)},
        shortTag("DATA", 105, [50, 51]),
        shortTag("DATA", 205, [-5]),
        pTag("DyeN", 1, "6-FAM"),
        TestTag{
            name: "DyeN",
            number: 2,
            elementType: 34,
            elementSize: 1,
            data: bytesOf([1, 2, 3, 4, 5, 6, 7, 8])
        },
        pTag("DyeN", 5, "LIZ"),
        shortTag("DyeW", 1, [522]),
        shortTag("DyeW", 5, [655])
    ];
    for (def i in 1..5) {
        $tags[] = shortTag("DATA", $i, [$i, 10 * $i]);
        $tags[] = shortTag("DATA", 8 + $i, [100 + $i]);
    }
    return parse(build(101, $tags));
}

func testTracesByDye() {
    def f as File init fiveDyes();
    testing.assertEqual(rawTrace($f, 1), [1, 10]);
    testing.assertEqual(rawTrace($f, 4), [4, 40]);
    testing.assertEqual(rawTrace($f, 5), [50, 51]);
    testing.assertEqual(analysedTrace($f, 1), [101]);
    testing.assertEqual(analysedTrace($f, 4), [104]);
    testing.assertEqual(analysedTrace($f, 5), [-5]);
    for (def bad in [0, 100]) {
        try {
            rawTrace($f, $bad);
            missed("dye " + convert.toString($bad));
        } catch (e) {
            testing.assertContains($e.message, "a dye number is 1 to 99");
        }
    }
    try {
        rawTrace($f, 6);
        missed("dye 6");
    } catch (e) {
        testing.assertEqual($e.message, "abif: the file has no DATA 106");
    }
}

func testAnEncryptedTraceIsRefused() {
    def f as File init parse(build(
        300,
        [
            TestTag{
                name: "DATA",
                number: 1,
                elementType: 28,
                elementSize: 1,
                data: bytesOf([1, 2, 3, 4, 5, 6, 7, 8])
            }
        ]));
    try {
        rawTrace($f, 1);
        missed("an encrypted trace");
    } catch (e) {
        testing.assertEqual(
            $e.message,
            "abif: DATA 1 holds unknown elements (type 28) (3500 HID files encrypt these), not a trace (short)");
    }
}

func testDyes() {
    testing.assertEqual(
        dyes(fiveDyes()),
        [
            Dye{number: 1, name: "6-FAM", wavelength: 522},
            Dye{number: 2, name: "", wavelength: 0},
            Dye{number: 3, name: "", wavelength: 0},
            Dye{number: 4, name: "", wavelength: 0},
            Dye{number: 5, name: "LIZ", wavelength: 655}
        ]);
    def f as File init parse(build(101, [pTag("DyeN", 1, "Joe"), pTag("DyeN", 2, "Fam")]));
    testing.assertEqual(
        dyes($f),
        [Dye{number: 1, name: "Joe", wavelength: 0}, Dye{number: 2, name: "Fam", wavelength: 0}]);
    testing.assertEqual(dyes(parse(build(101, []))), []);
    try {
        dyes(parse(build(101, [shortTag("Dye#", 1, [100])])));
        missed("100 dyes");
    } catch (e) {
        testing.assertEqual($e.message, "abif: Dye# 1 is not one number from 0 to 99");
    }
}

/**
 * Base-call tags of one set.
 *
 * @param number {int} 1 or 2
 * @param bases {string} the bases
 * @param qualities {list of int} the qualities
 * @param peaks {list of int} the peak locations
 * @return {list of TestTag} PBAS, PCON and PLOC
 */
func callTags(number as int, bases as string, qualities as list of int, peaks as list of int) {
    return [
        TestTag{name: "PBAS", number: $number, elementType: 2, elementSize: 1, data: utf($bases)},
        TestTag{
            name: "PCON",
            number: $number,
            elementType: 2,
            elementSize: 1,
            data: bytesOf($qualities)
        },
        shortTag("PLOC", $number, $peaks)
    ];
}

func testCallsAndEditedCalls() {
    def tags as list of TestTag init callTags(
        2,
        "GATTACA",
        [20, 30, 40, 50, 60, 0, 255],
        [3, 9, 15, 22, 30, 37, 44]);
    for (def t in callTags(1, "GATNACA", [20, 30, 40, 0, 60, 0, 255], [3, 9, 15, 22, 30, 37, 44])) {
        $tags[] = $t;
    }
    def f as File init parse(build(101, $tags));
    testing.assertEqual(
        calls($f),
        Calls{
            bases: "GATTACA",
            qualities: [20, 30, 40, 50, 60, 0, 255],
            peaks: [3, 9, 15, 22, 30, 37, 44]
        });
    testing.assertEqual(editedCalls($f).bases, "GATNACA");
    testing.assertEqual(editedCalls($f).qualities[3], 0);
}

func testCallsAreChecked() {
    def bases as TestTag init TestTag{
        name: "PBAS",
        number: 2,
        elementType: 2,
        elementSize: 1,
        data: utf("ACGT")
    };
    testing.assertEqual(
        calls(parse(build(101, [$bases]))),
        Calls{bases: "ACGT", qualities: [], peaks: []});
    try {
        calls(parse(build(101, [shortTag("DATA", 1, [1])])));
        missed("no PBAS");
    } catch (e) {
        testing.assertEqual(
            $e.message,
            "abif: the file has no base calls (PBAS 2); is it a fragment run?");
    }
    try {
        calls(parse(build(
            101,
            [
                $bases,
                TestTag{
                    name: "PCON",
                    number: 2,
                    elementType: 2,
                    elementSize: 1,
                    data: bytesOf([1, 2, 3])
                }
            ])));
        missed("short PCON");
    } catch (e) {
        testing.assertEqual($e.message, "abif: PCON 2 has 3 qualities for 4 bases");
    }
    try {
        calls(parse(build(101, [$bases, shortTag("PLOC", 2, [1, 2, 3, 4, 5])])));
        missed("long PLOC");
    } catch (e) {
        testing.assertEqual($e.message, "abif: PLOC 2 has 5 peak locations for 4 bases");
    }
}

func testInfo() {
    def f as File init parse(build(
        101,
        [
            pTag("SMPL", 1, "D11F"),
            pTag("TUBE", 1, "C5"),
            shortTag("LANE", 1, [15]),
            pTag("MCHN", 1, "ABI PRISM 310"),
            TestTag{name: "MODL", number: 1, elementType: 2, elementSize: 1, data: utf("310 ")},
            TestTag{name: "RunN", number: 1, elementType: 19, elementSize: 1, data: cstr("Run 1")},
            pTag("GTyp", 1, "POP7      "),
            TestTag{
                name: "DySN",
                number: 1,
                elementType: 34,
                elementSize: 1,
                data: bytesOf([1, 2, 3, 4, 5, 6, 7, 8])
            },
            TestTag{
                name: "StdF",
                number: 1,
                elementType: 2,
                elementSize: 1,
                data: bytesOf([76, 73, 90, 0, 0])
            },
            TestTag{
                name: "RUND",
                number: 1,
                elementType: 10,
                elementSize: 4,
                data: binary.concat(packed([2009], 2), bytesOf([2, 9]))
            },
            TestTag{
                name: "RUNT",
                number: 1,
                elementType: 11,
                elementSize: 4,
                data: bytesOf([1, 9, 3, 0])
            },
            TestTag{
                name: "RUND",
                number: 2,
                elementType: 10,
                elementSize: 4,
                data: binary.concat(packed([2009], 2), bytesOf([2, 19]))
            }
        ]));
    def i as Info init info($f);
    testing.assertEqual(
        $i,
        Info{
            sample: "D11F",
            well: "C5",
            lane: 15,
            instrument: "ABI PRISM 310",
            model: "310",
            runName: "Run 1",
            runModule: "",
            dyeSet: "",
            polymer: "POP7",
            sizeStandard: "LIZ",
            runStart: "2009-02-09 01:09:03",
            runFinish: "",
            collectionStart: "",
            collectionFinish: ""
        });
    testing.assertEqual(info(parse(build(101, []))).lane, 0);
}

func testNumbersStoredOtherwiseReadAsZero() {
    def f as File init parse(build(
        101,
        [
            pTag("LANE", 1, "7"),
            pTag("DyeN", 1, "FAM"),
            TestTag{
                name: "DyeW",
                number: 1,
                elementType: 34,
                elementSize: 1,
                data: bytesOf([1, 2, 3, 4, 5, 6, 7, 8])
            },
            pTag("DyeN", 2, "VIC"),
            shortTag("DyeW", 2, [554, 555])
        ]));
    testing.assertEqual(info($f).lane, 0);
    testing.assertEqual(
        dyes($f),
        [Dye{number: 1, name: "FAM", wavelength: 0}, Dye{number: 2, name: "VIC", wavelength: 0}]);
    try {
        dyes(parse(build(101, [pTag("Dye#", 1, "4")])));
        missed("Dye# as text");
    } catch (e) {
        testing.assertEqual($e.message, "abif: Dye# 1 is not one number from 0 to 99");
    }
}

func testCallsCountBasesInBytes() {
    def bases as TestTag init TestTag{
        name: "PBAS",
        number: 2,
        elementType: 2,
        elementSize: 1,
        data: utf("é")
    };
    try {
        calls(parse(build(
            101,
            [
                $bases,
                TestTag{
                    name: "PCON",
                    number: 2,
                    elementType: 2,
                    elementSize: 1,
                    data: bytesOf([30])
                }
            ])));
        missed("one quality for two bytes");
    } catch (e) {
        testing.assertEqual($e.message, "abif: PCON 2 has 1 qualities for 2 bases");
    }
}
