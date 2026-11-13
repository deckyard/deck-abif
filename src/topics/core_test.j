# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

# abif - white-box tests for the core topic, and the builder of synthetic
# ABIF files the other overlays use. Spliced into abif_test.j via include.

/**
 * A tag for `build`.
 *
 * @field name {string} the tag name
 * @field number {int} the tag number
 * @field elementType {int} the element type
 * @field elementSize {int} bytes per element
 * @field data {bytes} the data; the count is its length over the element size
 */
def struct TestTag {
    name as string,
    number as int,
    elementType as int,
    elementSize as int,
    data as bytes
};

/**
 * Mark a call that should have thrown.
 *
 * @param what {string} what got through
 * @throws {Error} always, kind "missed"
 */
func missed(what as string) {
    throw Error{kind: "missed", message: $what};
}

/**
 * Write a big-endian integer into bytes.
 *
 * @param b {bytes} the bytes
 * @param at {int} where
 * @param value {int} the value; a negative one in two's complement
 * @param size {int} 1, 2 or 4 bytes
 * @return {bytes} the changed bytes
 */
func put(b as bytes, at as int, value as int, size as int) {
    def v as int init $value;
    if ($v < 0) {
        $v = $v + (1 << (8 * $size));
    }
    for (def i in 0..$size) {
        $b[$at + $i] = ($v >> (8 * ($size - 1 - $i))) & 255;
    }
    return $b;
}

/**
 * Integers as big-endian elements.
 *
 * @param values {list of int} the values
 * @param size {int} bytes each
 * @return {bytes} the data
 */
func packed(values as list of int, size as int) {
    def b as bytes init binary.make(len($values) * $size);
    for (def i in 0..len($values)) {
        $b = put($b, $i * $size, $values[$i], $size);
    }
    return $b;
}

/**
 * Bytes from a list of byte values.
 *
 * @param values {list of int} 0 to 255 each
 * @return {bytes} the bytes
 */
func bytesOf(values as list of int) {
    return packed($values, 1);
}

/**
 * Text as bytes.
 *
 * @param s {string} the text
 * @return {bytes} its UTF-8
 */
func utf(s as string) {
    return convert.bytesFromString("utf-8", $s);
}

/**
 * A pString: a length byte, then the text.
 *
 * @param s {string} the text, under 256 bytes
 * @return {bytes} the data
 */
func pstr(s as string) {
    return binary.concat(bytesOf([len(utf($s))]), utf($s));
}

/**
 * A cString: the text, then a NUL.
 *
 * @param s {string} the text
 * @return {bytes} the data
 */
func cstr(s as string) {
    return binary.concat(utf($s), binary.make(1));
}

/**
 * A tag of shorts (type 4).
 *
 * @param name {string} the tag name
 * @param number {int} the tag number
 * @param values {list of int} the values
 * @return {TestTag} the tag
 */
func shortTag(name as string, number as int, values as list of int) {
    return TestTag{
        name: $name,
        number: $number,
        elementType: 4,
        elementSize: 2,
        data: packed($values, 2)
    };
}

/**
 * A pString tag (type 18).
 *
 * @param name {string} the tag name
 * @param number {int} the tag number
 * @param s {string} the text
 * @return {TestTag} the tag
 */
func pTag(name as string, number as int, s as string) {
    return TestTag{name: $name, number: $number, elementType: 18, elementSize: 1, data: pstr($s)};
}

/**
 * An ABIF file: the header, the data of every tag over 4 bytes from byte
 * 128 on, then the directory. Data of 4 bytes or less goes into its entry.
 *
 * @param version {int} the version, such as 101
 * @param tags {list of TestTag} the tags
 * @return {bytes} the file
 */
func build(version as int, tags as list of TestTag) {
    def parts as list of bytes init [binary.make(128)];
    def offsets as list of int init [];
    def at as int init 128;
    for (def t in $tags) {
        $offsets[] = $at;
        if (len($t.data) > 4) {
            $parts[] = $t.data;
            $at = $at + len($t.data);
        }
    }
    def dir as bytes init binary.make(28 * len($tags));
    for (def i in 0..len($tags)) {
        def t as TestTag init $tags[$i];
        def e as int init 28 * $i;
        for (def k in 0..4) {
            $dir[$e + $k] = utf($t.name)[$k];
        }
        $dir = put($dir, $e + 4, $t.number, 4);
        $dir = put($dir, $e + 8, $t.elementType, 2);
        $dir = put($dir, $e + 10, $t.elementSize, 2);
        $dir = put($dir, $e + 12, len($t.data) // $t.elementSize, 4);
        $dir = put($dir, $e + 16, len($t.data), 4);
        if (len($t.data) > 4) {
            $dir = put($dir, $e + 20, $offsets[$i], 4);
        } else {
            for (def k in 0..len($t.data)) {
                $dir[$e + 20 + $k] = $t.data[$k];
            }
        }
    }
    $parts[] = $dir;
    def b as bytes init binary.join($parts);
    for (def k in 0..4) {
        $b[$k] = utf("ABIF")[$k];
    }
    $b = put($b, 4, $version, 2);
    for (def k in 0..4) {
        $b[6 + $k] = utf("tdir")[$k];
    }
    $b = put($b, 10, 1, 4);
    $b = put($b, 14, 1023, 2);
    $b = put($b, 16, 28, 2);
    $b = put($b, 18, len($tags), 4);
    $b = put($b, 22, 28 * len($tags), 4);
    $b = put($b, 26, $at, 4);
    return $b;
}

/**
 * Where a built file's directory starts.
 *
 * @param b {bytes} the file
 * @return {int} the directory's offset
 */
func dirOf(b as bytes) {
    return binary.readInt("be", $b, 26, 4);
}

/**
 * A small sequencing file: two traces, a sample name and a short directory.
 *
 * @return {bytes} the file
 */
func sampleFile() {
    return build(
        101,
        [shortTag("DATA", 1, [1, -2, 300]), pTag("SMPL", 1, "S1"), shortTag("DATA", 9, [5, 6, 7])]);
}

/**
 * Assert that parsing throws an abif error with a message.
 *
 * @param b {bytes} the file
 * @param want {string} part of the message
 */
func refused(b as bytes, want as string) {
    try {
        parse($b);
        missed($want);
    } catch (e) {
        testing.assertEqual($e.kind, "abif");
        testing.assertContains($e.message, $want);
    }
}

func testParseReadsTheDirectory() {
    def f as File init parse(sampleFile());
    testing.assertEqual($f.version, 101);
    testing.assertEqual(tags($f), ["DATA1", "SMPL1", "DATA9"]);
    testing.assertTrue(has($f, "SMPL", 1));
    testing.assertFalse(has($f, "SMPL", 2));
    def e as Entry init entry($f, "DATA", 1);
    testing.assertEqual($e.elementType, 4);
    testing.assertEqual($e.elementSize, 2);
    testing.assertEqual($e.count, 3);
    testing.assertEqual($e.dataSize, 6);
    testing.assertEqual($e.offset, 128);
    def s as Entry init entry($f, "SMPL", 1);
    testing.assertEqual($s.offset, dirOf(sampleFile()) + 28 + 20);
    testing.assertEqual(raw($f, "SMPL", 1), pstr("S1"));
    testing.assertEqual(raw($f, "DATA", 9), packed([5, 6, 7], 2));
}

func testAnEmptyDirectoryAndAnEmptyTag() {
    def f as File init parse(build(101, []));
    testing.assertEqual(len(entries($f)), 0);
    $f = parse(build(300, [shortTag("OvrI", 11, [])]));
    testing.assertEqual($f.version, 300);
    testing.assertEqual(entry($f, "OvrI", 11).count, 0);
    testing.assertEqual(len(raw($f, "OvrI", 11)), 0);
}

func testWhatIsNoAbifFile() {
    refused(binary.make(127), "127 bytes, the header alone is 128");
    def b as bytes init sampleFile();
    $b[0] = 97;
    refused($b, "does not start with \"ABIF\"");
    refused(put(sampleFile(), 4, 99, 2), "ABIF version 99");
    refused(put(sampleFile(), 4, 400, 2), "ABIF version 400");
}

func testTheDirectoryIsChecked() {
    def b as bytes init sampleFile();
    $b[6] = 120;
    refused($b, "the header's directory entry is malformed");
    $b[6] = 255;
    refused($b, "the header's directory entry is malformed");
    refused(put(sampleFile(), 16, 27, 2), "the header's directory entry is malformed");
    refused(put(sampleFile(), 18, 4, 4), "the header's directory entry is malformed");
    refused(
        put(put(sampleFile(), 18, MAX_ENTRIES + 1, 4), 22, 28 * (MAX_ENTRIES + 1), 4),
        "65537 directory entries");
    refused(
        put(put(sampleFile(), 18, 4, 4), 22, 112, 4),
        "the directory runs past the end of the file");
    refused(put(sampleFile(), 26, 100, 4), "the directory overlaps the header");
}

func testEachEntryIsChecked() {
    def d as int init dirOf(sampleFile());
    def b as bytes init sampleFile();
    $b[$d + 1] = 9;
    refused($b, "has a tag name that is not printable ASCII");
    refused(
        put(sampleFile(), $d + 4, -1, 4),
        "DATA -1: a negative number, or a type or element size below 1");
    refused(put(sampleFile(), $d + 10, 3, 2), "DATA 1: element type 4 has 2-byte elements, not 3");
    refused(put(sampleFile(), $d + 16, 8, 4), "DATA 1: 8 bytes of data for 3 elements of 2 bytes");
    refused(put(sampleFile(), $d + 20, 100, 4), "DATA 1: its 6 bytes at 100 lie outside the file");
    refused(put(sampleFile(), $d + 20, $d + 80, 4), "lie outside the file");
    def twice as bytes init build(101, [shortTag("DATA", 1, [1]), shortTag("DATA", 1, [2])]);
    refused($twice, "DATA 1 appears twice in the directory");
}

func testEntryNamesWhatIsMissing() {
    def f as File init parse(sampleFile());
    for (def bad in ["PBAS", "DAT"]) {
        try {
            entry($f, $bad, 1);
            missed($bad);
        } catch (e) {
            testing.assertEqual($e.kind, "abif");
        }
    }
    try {
        raw($f, "PBAS", 2);
        missed("PBAS 2");
    } catch (e) {
        testing.assertEqual($e.message, "abif: the file has no PBAS 2");
    }
    try {
        entry($f, "DAT", 1);
        missed("DAT");
    } catch (e) {
        testing.assertEqual($e.message, "abif: a tag name is four characters, got 3");
    }
}

func testOpenReadsAFile() {
    def dir as string init fs.makeTempDir("", "abif-test-");
    defer fs.removeAll($dir);
    fs.writeBytes($dir + "/a.ab1", sampleFile());
    testing.assertEqual(tags(open($dir + "/a.ab1")), ["DATA1", "SMPL1", "DATA9"]);
}

func testTheHeadersDirectoryEntryIsChecked() {
    refused(put(sampleFile(), 10, 2, 4), "the header's directory entry is malformed");
    refused(put(sampleFile(), 14, 1022, 2), "the header's directory entry is malformed");
}

func testLookupsTakeFourCharacterNames() {
    def tags as list of TestTag init [];
    for (def n in [1, 10]) {
        $tags[] = shortTag("DATA", $n, [$n]);
    }
    $tags[] = shortTag("ZERO", 0, [7]);
    def f as File init parse(build(101, $tags));
    testing.assertFalse(has($f, "DATA1", 0));
    testing.assertTrue(has($f, "DATA", 10));
    try {
        entry($f, "DATA1", 0);
        missed("DATA1 0");
    } catch (e) {
        testing.assertEqual($e.message, "abif: a tag name is four characters, got 5");
    }
    testing.assertEqual(entry($f, "ZERO", 0).count, 1);
}
