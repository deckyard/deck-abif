# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# abif - white-box tests for the values topic. Spliced into abif_test.j via
# include.

/**
 * A file with one tag of every decoded type, and some raw ones.
 *
 * @return {File} the parsed file
 */
func everyType() {
    return parse(build(
        101,
        [
            TestTag{
                name: "BYTE",
                number: 1,
                elementType: 1,
                elementSize: 1,
                data: bytesOf([0, 255, 7])
            },
            TestTag{name: "CHAR", number: 1, elementType: 2, elementSize: 1, data: utf("GATC")},
            TestTag{
                name: "WORD",
                number: 1,
                elementType: 3,
                elementSize: 2,
                data: packed([65535, 1], 2)
            },
            shortTag("SHRT", 1, [-2, 3, 32767]),
            TestTag{
                name: "LONG",
                number: 1,
                elementType: 5,
                elementSize: 4,
                data: packed([-70000, 8], 4)
            },
            TestTag{
                name: "FLOT",
                number: 1,
                elementType: 7,
                elementSize: 4,
                data: packed([0x3fc00000], 4)
            },
            TestTag{
                name: "DOUB",
                number: 1,
                elementType: 8,
                elementSize: 8,
                data: binary.concat(packed([0x40020000], 4), binary.make(4))
            },
            TestTag{
                name: "RUND",
                number: 1,
                elementType: 10,
                elementSize: 4,
                data: binary.concat(packed([2009], 2), bytesOf([12, 3]))
            },
            TestTag{
                name: "RUNT",
                number: 1,
                elementType: 11,
                elementSize: 4,
                data: bytesOf([9, 5, 7, 234])
            },
            TestTag{
                name: "THUM",
                number: 1,
                elementType: 12,
                elementSize: 10,
                data: binary.concat(packed([211557858, -1366584667], 4), bytesOf([151, 150]))
            },
            TestTag{
                name: "BOOL",
                number: 1,
                elementType: 13,
                elementSize: 1,
                data: bytesOf([1, 0, 2])
            },
            pTag("PSTR", 1, "POP7  "),
            TestTag{
                name: "CSTR",
                number: 1,
                elementType: 19,
                elementSize: 1,
                data: cstr("6-DYE Assay")
            },
            TestTag{
                name: "Rate",
                number: 1,
                elementType: 1024,
                elementSize: 1,
                data: bytesOf([0, 1, 2, 3, 4])
            },
            TestTag{
                name: "DATA",
                number: 1,
                elementType: 28,
                elementSize: 1,
                data: bytesOf([9, 8, 7, 6, 5, 4, 3, 2])
            },
            TestTag{name: "RATL", number: 1, elementType: 6, elementSize: 8, data: binary.make(8)}
        ]));
}

/**
 * The integers of a Value, or a failure when it is another variant.
 *
 * @param v {Value} the value
 * @return {list of int} its integers
 */
func intsIn(v as Value) {
    match ($v) {
        when Ints(x) { return $x.values; }
        else { missed("an Ints value"); }
    }
}

func testEveryTypeDecodes() {
    def f as File init everyType();
    testing.assertEqual(intsIn(tag($f, "BYTE", 1)), [0, 255, 7]);
    testing.assertEqual(intsIn(tag($f, "WORD", 1)), [65535, 1]);
    testing.assertEqual(intsIn(tag($f, "SHRT", 1)), [-2, 3, 32767]);
    testing.assertEqual(intsIn(tag($f, "LONG", 1)), [-70000, 8]);
    testing.assertEqual(tag($f, "FLOT", 1), Value.Floats{values: [1.5]});
    testing.assertEqual(tag($f, "DOUB", 1), Value.Floats{values: [2.25]});
    testing.assertEqual(tag($f, "CHAR", 1), Value.Chars{data: utf("GATC")});
    testing.assertEqual(tag($f, "PSTR", 1), Value.Text{value: "POP7  "});
    testing.assertEqual(tag($f, "CSTR", 1), Value.Text{value: "6-DYE Assay"});
    testing.assertEqual(
        tag($f, "RUND", 1),
        Value.Dates{values: [Date{year: 2009, month: 12, day: 3}]});
    testing.assertEqual(
        tag($f, "RUNT", 1),
        Value.Times{values: [Time{hour: 9, minute: 5, second: 7, hundredths: 234}]});
    testing.assertEqual(
        tag($f, "THUM", 1),
        Value.Thumbs{values: [Thumb{d: 211557858, u: -1366584667, c: 151, n: 150}]});
    testing.assertEqual(tag($f, "BOOL", 1), Value.Bools{values: [true, false, true]});
    testing.assertEqual(
        tag($f, "Rate", 1),
        Value.Raw{elementType: 1024, data: bytesOf([0, 1, 2, 3, 4])});
    testing.assertEqual(
        tag($f, "DATA", 1),
        Value.Raw{elementType: 28, data: bytesOf([9, 8, 7, 6, 5, 4, 3, 2])});
    testing.assertEqual(tag($f, "RATL", 1), Value.Raw{elementType: 6, data: binary.make(8)});
}

func testTypeNames() {
    testing.assertEqual(typeName(4), "short");
    testing.assertEqual(typeName(18), "pString");
    testing.assertEqual(typeName(384), "deltaLZW");
    testing.assertEqual(typeName(1023), "directory");
    testing.assertEqual(typeName(1024), "user");
    testing.assertEqual(typeName(5000), "user");
    testing.assertEqual(typeName(28), "unknown");
}

func testTheTypedReaders() {
    def f as File init everyType();
    testing.assertEqual(text($f, "CHAR", 1), "GATC");
    testing.assertEqual(text($f, "PSTR", 1), "POP7  ");
    testing.assertEqual(text($f, "CSTR", 1), "6-DYE Assay");
    testing.assertEqual(ints($f, "CHAR", 1), [71, 65, 84, 67]);
    testing.assertEqual(ints($f, "BYTE", 1), [0, 255, 7]);
    testing.assertEqual(ints($f, "SHRT", 1), [-2, 3, 32767]);
    testing.assertEqual(floats($f, "DOUB", 1), [2.25]);
    try {
        text($f, "SHRT", 1);
        missed("text of shorts");
    } catch (e) {
        testing.assertEqual(
            $e.message,
            "SHRT 1 holds short elements (type 4), not text (char, pString or cString)");
    }
    try {
        ints($f, "FLOT", 1);
        missed("ints of floats");
    } catch (e) {
        testing.assertContains($e.message, "FLOT 1 holds float elements (type 7), not integers");
    }
    try {
        floats($f, "DATA", 1);
        missed("floats of an encrypted tag");
    } catch (e) {
        testing.assertEqual(
            $e.message,
            "DATA 1 holds unknown elements (type 28) (3500 HID files encrypt these), not floats (float or double)");
    }
}

func testMalformedStringsAreRefused() {
    def f as File init parse(build(
        101,
        [
            TestTag{
                name: "PLEN",
                number: 1,
                elementType: 18,
                elementSize: 1,
                data: bytesOf([5, 65, 66])
            },
            TestTag{name: "PNIL", number: 1, elementType: 18, elementSize: 1, data: binary.make(0)},
            TestTag{name: "CEND", number: 1, elementType: 19, elementSize: 1, data: utf("ABC")},
            TestTag{
                name: "CMID",
                number: 1,
                elementType: 19,
                elementSize: 1,
                data: bytesOf([65, 0, 66, 0])
            },
            TestTag{
                name: "CMNT",
                number: 1,
                elementType: 18,
                elementSize: 1,
                data: bytesOf([3, 0xe6, 0x13, 0xb9])
            },
            TestTag{name: "BADC", number: 1, elementType: 2, elementSize: 1, data: bytesOf([0xff])},
            TestTag{
                name: "NANF",
                number: 1,
                elementType: 7,
                elementSize: 4,
                data: packed([0x7fc00000], 4)
            }
        ]));
    for (def t in ["PLEN", "PNIL"]) {
        try {
            tag($f, $t, 1);
            missed($t);
        } catch (e) {
            testing.assertContains($e.message, "a pString whose length byte does not match");
        }
    }
    for (def t in ["CEND", "CMID"]) {
        try {
            text($f, $t, 1);
            missed($t);
        } catch (e) {
            testing.assertContains($e.message, "a cString that does not end at its only NUL");
        }
    }
    for (def t in ["CMNT", "BADC"]) {
        try {
            text($f, $t, 1);
            missed($t);
        } catch (e) {
            testing.assertContains($e.message, " 1 is not UTF-8 text; read its bytes with raw");
        }
    }
    testing.assertEqual(raw($f, "CMNT", 1), bytesOf([3, 0xe6, 0x13, 0xb9]));
    testing.assertEqual(tag($f, "BADC", 1), Value.Chars{data: bytesOf([0xff])});
    try {
        tag($f, "NANF", 1);
        missed("NaN");
    } catch (e) {
        testing.assertEqual($e.message, "NANF 1 holds a value that is not a finite number");
    }
}

func testAnEmptyCStringIsRefused() {
    def f as File init parse(build(
        101,
        [TestTag{name: "CEMP", number: 1, elementType: 19, elementSize: 1, data: binary.make(0)}]));
    for (def i in 0..2) {
        try {
            if ($i == 0) {
                text($f, "CEMP", 1);
            } else {
                tag($f, "CEMP", 1);
            }
            missed("an empty cString");
        } catch (e) {
            testing.assertEqual($e.message, "CEMP 1: a cString that does not end at its only NUL");
        }
    }
}
