# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

# abif - values: the element types, decoding a tag into a Value, and the
# typed readers text, ints and floats. Spliced into abif.j via include.

/**
 * An element of type `date`.
 *
 * @field year {int} the year, such as 2009
 * @field month {int} the month as stored, 1 to 12 in a sound file
 * @field day {int} the day as stored, 1 to 31 in a sound file
 */
export def struct Date {
    year as int,
    month as int,
    day as int
};

/**
 * An element of type `time`.
 *
 * @field hour {int} the hour as stored
 * @field minute {int} the minute as stored
 * @field second {int} the second as stored
 * @field hundredths {int} hundredths of a second as stored; some instruments write values above 99
 */
export def struct Time {
    hour as int,
    minute as int,
    second as int,
    hundredths as int
};

/**
 * An element of type `thumb`, a fingerprint of the file.
 *
 * @field d {int} the first 32-bit field
 * @field u {int} the second 32-bit field
 * @field c {int} the first byte field
 * @field n {int} the second byte field
 */
export def struct Thumb {
    d as int,
    u as int,
    c as int,
    n as int
};

/**
 * A decoded tag. `match` on it to read the payload.
 *
 * - `Ints` - `byte`, `word`, `short` and `long` elements
 * - `Floats` - `float` and `double` elements
 * - `Chars` - `char` elements: often text (`PBAS`, `MODL`), sometimes numbers (`PCON`)
 * - `Text` - a `pString` or `cString`
 * - `Dates`, `Times`, `Thumbs`, `Bools` - their element types
 * - `Raw` - any other type: user types (1024 and up), the obsolete ones, and the encrypted types of 3500 HID files
 */
export def enum Value {
    Ints{values as list of int},
    Floats{values as list of float},
    Chars{data as bytes},
    Text{value as string},
    Dates{values as list of Date},
    Times{values as list of Time},
    Thumbs{values as list of Thumb},
    Bools{values as list of bool},
    Raw{elementType as int, data as bytes}
};

/**
 * The name of an element type, as the format specification writes it.
 *
 * @param elementType {int} the type code
 * @return {string} such as `short`, `pString` or `user`; `unknown` for a code the specification does not name
 */
export func typeName(elementType as int) {
    def names as map of int to string init {
        1: "byte",
        2: "char",
        3: "word",
        4: "short",
        5: "long",
        6: "rational",
        7: "float",
        8: "double",
        9: "BCD",
        10: "date",
        11: "time",
        12: "thumb",
        13: "bool",
        14: "point",
        15: "rect",
        16: "vPoint",
        17: "vRect",
        18: "pString",
        19: "cString",
        20: "tag",
        128: "deltaComp",
        256: "LZWComp",
        384: "deltaLZW",
        1023: "directory"
    };
    if (maps.has($names, $elementType)) {
        return $names[$elementType];
    }
    if ($elementType >= 1024) {
        return "user";
    }
    return "unknown";
}

/**
 * Decode a tag.
 *
 * @param f {File} the file
 * @param name {string} the tag name, such as `SMPL`
 * @param number {int} the tag number
 * @return {Value} the decoded data
 * @throws {Error} kind "abif" when the file has no such tag, a string is malformed or not UTF-8, or a float is not finite
 * @example
 *   def v as abif.Value init abif.tag($f, "RUND", 1);
 *   match ($v) {
 *       when Dates(d) { io.printf("%d\n", $d.values[0].year); }
 *       else { }
 *   }
 */
export func tag(f as File, name as string, number as int) {
    def e as Entry init entry($f, $name, $number);
    def t as int init $e.elementType;
    if ($t == 1 or $t == 3 or $t == 4 or $t == 5) {
        return Value.Ints{values: intsOf($f, $e)};
    }
    if ($t == 7 or $t == 8) {
        return Value.Floats{values: floatsOf($f, $e)};
    }
    if ($t == 2) {
        return Value.Chars{data: dataOf($f, $e)};
    }
    if ($t == 18 or $t == 19) {
        return Value.Text{value: textOf($f, $e)};
    }
    if ($t == 10) {
        def dates as list of Date init [];
        for (def i in 0..$e.count) {
            def at as int init $e.offset + $i * 4;
            $dates[] = Date{
                year: binary.readInt("be", $f.data, $at, 2),
                month: $f.data[$at + 2],
                day: $f.data[$at + 3]
            };
        }
        return Value.Dates{values: $dates};
    }
    if ($t == 11) {
        def times as list of Time init [];
        for (def i in 0..$e.count) {
            def at as int init $e.offset + $i * 4;
            $times[] = Time{
                hour: $f.data[$at],
                minute: $f.data[$at + 1],
                second: $f.data[$at + 2],
                hundredths: $f.data[$at + 3]
            };
        }
        return Value.Times{values: $times};
    }
    if ($t == 12) {
        def thumbs as list of Thumb init [];
        for (def i in 0..$e.count) {
            def at as int init $e.offset + $i * 10;
            $thumbs[] = Thumb{
                d: binary.readInt("be", $f.data, $at, 4),
                u: binary.readInt("be", $f.data, $at + 4, 4),
                c: $f.data[$at + 8],
                n: $f.data[$at + 9]
            };
        }
        return Value.Thumbs{values: $thumbs};
    }
    if ($t == 13) {
        def bools as list of bool init [];
        for (def i in 0..$e.count) {
            $bools[] = $f.data[$e.offset + $i] != 0;
        }
        return Value.Bools{values: $bools};
    }
    return Value.Raw{elementType: $t, data: dataOf($f, $e)};
}

/**
 * A tag that holds text: `pString`, `cString`, or `char` elements decoded
 * as UTF-8. Nothing is trimmed.
 *
 * @param f {File} the file
 * @param name {string} the tag name, such as `SMPL` or `PBAS`
 * @param number {int} the tag number
 * @return {string} the text
 * @throws {Error} kind "abif" when the tag is missing, holds another type, is malformed or is not UTF-8
 */
export func text(f as File, name as string, number as int) {
    def e as Entry init entry($f, $name, $number);
    if ($e.elementType == 2) {
        return utf8($e, dataOf($f, $e));
    }
    if ($e.elementType != 18 and $e.elementType != 19) {
        fail(mismatch($e, "text (char, pString or cString)"));
    }
    return textOf($f, $e);
}

/**
 * A tag of integers: `byte`, `char` (as 0 to 255), `word`, `short` or
 * `long` elements.
 *
 * @param f {File} the file
 * @param name {string} the tag name, such as `DATA` or `PLOC`
 * @param number {int} the tag number
 * @return {list of int} the values
 * @throws {Error} kind "abif" when the tag is missing or holds another type
 */
export func ints(f as File, name as string, number as int) {
    def e as Entry init entry($f, $name, $number);
    def t as int init $e.elementType;
    if ($t != 1 and $t != 2 and $t != 3 and $t != 4 and $t != 5) {
        fail(mismatch($e, "integers (byte, char, word, short or long)"));
    }
    return intsOf($f, $e);
}

/**
 * A tag of `float` or `double` elements.
 *
 * @param f {File} the file
 * @param name {string} the tag name, such as `Scal`
 * @param number {int} the tag number
 * @return {list of float} the values
 * @throws {Error} kind "abif" when the tag is missing, holds another type, or a value is not finite
 */
export func floats(f as File, name as string, number as int) {
    def e as Entry init entry($f, $name, $number);
    if ($e.elementType != 7 and $e.elementType != 8) {
        fail(mismatch($e, "floats (float or double)"));
    }
    return floatsOf($f, $e);
}

/**
 * The message for a tag read as the wrong type.
 *
 * @param e {Entry} the entry
 * @param wanted {string} what the reader takes
 * @return {string} the message
 */
func mismatch(e as Entry, wanted as string) {
    def why as string init "";
    if ($e.elementType >= 28 and $e.elementType <= 34) {
        $why = " (3500 HID files encrypt these)";
    }
    return io.sprintf(
        "%s %d holds %s elements (type %d)%s, not %s",
        $e.name,
        $e.number,
        typeName($e.elementType),
        $e.elementType,
        $why,
        $wanted);
}

/**
 * The data bytes of an entry.
 *
 * @param f {File} the file
 * @param e {Entry} the entry
 * @return {bytes} its data
 */
func dataOf(f as File, e as Entry) {
    return binary.slice($f.data, $e.offset, $e.offset + $e.dataSize);
}

/**
 * The integers of an entry of type byte, char, word, short or long.
 *
 * @param f {File} the file
 * @param e {Entry} the entry
 * @return {list of int} the values; byte, char and word unsigned
 */
func intsOf(f as File, e as Entry) {
    if ($e.elementType == 4 or $e.elementType == 5) {
        return binary.readInts("be", $f.data, $e.offset, $e.count, $e.elementSize);
    }
    def out as list of int init [];
    for (def i in 0..$e.count) {
        $out[] = binary.readUint("be", $f.data, $e.offset + $i * $e.elementSize, $e.elementSize);
    }
    return $out;
}

/**
 * The floats of an entry of type float or double.
 *
 * @param f {File} the file
 * @param e {Entry} the entry
 * @return {list of float} the values
 */
func floatsOf(f as File, e as Entry) {
    try {
        return binary.readFloats("be", $f.data, $e.offset, $e.count, $e.elementSize);
    } catch (err) {
        fail(io.sprintf("%s %d holds a value that is not a finite number", $e.name, $e.number));
    }
}

/**
 * The text of a pString (a length byte, then that many bytes) or a cString
 * (bytes ended by its only NUL).
 *
 * @param f {File} the file
 * @param e {Entry} the entry
 * @return {string} the text
 */
func textOf(f as File, e as Entry) {
    def d as bytes init dataOf($f, $e);
    if ($e.elementType == 18) {
        if (len($d) == 0 or $d[0] != len($d) - 1) {
            fail(io.sprintf(
                "%s %d: a pString whose length byte does not match its %d bytes",
                $e.name,
                $e.number,
                len($d)));
        }
        return utf8($e, binary.slice($d, 1));
    }
    def nul as int init binary.indexOf($d, binary.make(1));
    if (len($d) == 0 or $nul != len($d) - 1) {
        fail(io.sprintf("%s %d: a cString that does not end at its only NUL", $e.name, $e.number));
    }
    return utf8($e, binary.slice($d, 0, $nul));
}

/**
 * Bytes as UTF-8 text.
 *
 * @param e {Entry} the entry, for the message
 * @param d {bytes} the bytes
 * @return {string} the text
 */
func utf8(e as Entry, d as bytes) {
    try {
        return convert.stringFromBytes("utf-8", $d);
    } catch (err) {
        fail(io.sprintf("%s %d is not UTF-8 text; read its bytes with raw", $e.name, $e.number));
    }
}
