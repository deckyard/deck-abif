# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

# abif - core: the header, the directory and its checks, and finding an
# entry. Spliced into abif.j via include.

/** The most directory entries a file may have; real files have 20 to 200. */
export def const MAX_ENTRIES as int init 65536;

# the header: "ABIF", the version, the directory's own entry, reserved space
def const HEADER_SIZE as int init 128;

# one directory entry
def const ENTRY_SIZE as int init 28;

# the element size each defined type must declare; other types are not checked
def const ELEMENT_SIZES as map of int to int init {
    1: 1,
    2: 1,
    3: 2,
    4: 2,
    5: 4,
    7: 4,
    8: 8,
    10: 4,
    11: 4,
    12: 10,
    13: 1,
    18: 1,
    19: 1
};

/**
 * One directory entry: where a tag's data is and how to read it.
 *
 * @field name {string} the tag name, four characters such as `DATA`
 * @field number {int} the tag number, 0 and up; 1 and up in real files (`DATA` 1 to 12, 105, ...)
 * @field elementType {int} the element type code (see `typeName`)
 * @field elementSize {int} bytes per element
 * @field count {int} the number of elements
 * @field dataSize {int} bytes of data, `count * elementSize`
 * @field offset {int} where the data starts in the file; data of 4 bytes or less sits in the entry itself
 */
export def struct Entry {
    name as string,
    number as int,
    elementType as int,
    elementSize as int,
    count as int,
    dataSize as int,
    offset as int
};

/**
 * A parsed ABIF file: its bytes and their checked directory. The directory
 * is kept as one list per `Entry` field, entry i at position i of each, so a
 * `File` holds none of the module's structs and passes into the module
 * without being rebuilt (a `list of Entry` was rebuilt on every call: 63 MB
 * for one call per tag of an 800 KB file). `entries` and `entry` return
 * `Entry` structs.
 *
 * @field version {int} the format version: 101 in `.ab1` and `.fsa`, 300 in 3500 HID files
 * @field names {list of string} each entry's tag name, in file order
 * @field numbers {list of int} each entry's tag number
 * @field elementTypes {list of int} each entry's element type
 * @field elementSizes {list of int} each entry's element size
 * @field counts {list of int} each entry's element count
 * @field dataSizes {list of int} each entry's data size
 * @field offsets {list of int} each entry's data offset in the file
 * @field index {map of string to int} the position of each tag in those lists, keyed `NAME` + number (`DATA9`)
 * @field data {bytes} the whole file
 */
export def struct File {
    version as int,
    names as list of string,
    numbers as list of int,
    elementTypes as list of int,
    elementSizes as list of int,
    counts as list of int,
    dataSizes as list of int,
    offsets as list of int,
    index as map of string to int,
    data as bytes
};

/**
 * Throw an abif error.
 *
 * @param message {string} what went wrong, without the `abif: ` prefix
 * @throws {Error} kind "abif", always
 */
func fail(message as string) {
    throw Error{kind: "abif", message: "abif: " + $message};
}

/**
 * Parse an ABIF file. The header and every directory entry are checked
 * against the file first: the magic, the version, the directory's place,
 * each tag name, element sizes, counts and data ranges, and duplicate tags.
 *
 * @param data {bytes} the file
 * @return {File} the file with its directory
 * @throws {Error} kind "abif" when the bytes are no ABIF file or the directory does not fit them; kind "limit" for more than `MAX_ENTRIES` entries
 * @example
 *   def f as abif.File init abif.parse(fs.readBytes("run.fsa"));
 */
export func parse(data as bytes) {
    if (len($data) < HEADER_SIZE) {
        fail(io.sprintf("not an ABIF file: %d bytes, the header alone is 128", len($data)));
    }
    if (not binary.startsWith($data, convert.bytesFromString("utf-8", "ABIF"))) {
        fail("not an ABIF file: it does not start with \"ABIF\"");
    }
    def version as int init binary.readUint("be", $data, 4, 2);
    if ($version < 100 or $version >= 400) {
        fail(io.sprintf("ABIF version %d; this deck reads 1.xx to 3.xx", $version));
    }
    # the header's own entry for the directory; its data size is the space
    # reserved for it (3584 bytes for 113 entries in a 310 file), so only
    # the entries it counts are read
    def count as int init binary.readInt("be", $data, 18, 4);
    def reserved as int init binary.readInt("be", $data, 22, 4);
    def at as int init binary.readInt("be", $data, 26, 4);
    if (not binary.startsWith(binary.slice($data, 6, 10), convert.bytesFromString("utf-8", "tdir")) or
        binary.readInt("be", $data, 10, 4) != 1 or binary.readInt("be", $data, 14, 2) != 1023 or
        binary.readInt("be", $data, 16, 2) != ENTRY_SIZE or $count < 0 or
        $reserved < $count * ENTRY_SIZE) {
        fail("the header's directory entry is malformed");
    }
    if ($count > MAX_ENTRIES) {
        throw Error{
            kind: "limit",
            message: io.sprintf("abif: %d directory entries, more than %d", $count, MAX_ENTRIES)
        };
    }
    if ($count > 0 and $at < HEADER_SIZE) {
        fail("the directory overlaps the header");
    }
    def f as File init File{
        version: $version,
        names: [],
        numbers: [],
        elementTypes: [],
        elementSizes: [],
        counts: [],
        dataSizes: [],
        offsets: [],
        index: {},
        data: $data
    };
    for (def i in 0..$count) {
        def e as Entry init readEntry($data, $at + $i * ENTRY_SIZE, len($data));
        def key as string init $e.name + convert.toString($e.number);
        if (maps.has($f.index, $key)) {
            fail(io.sprintf("%s %d appears twice in the directory", $e.name, $e.number));
        }
        $f.index[$key] = $i;
        $f.names[] = $e.name;
        $f.numbers[] = $e.number;
        $f.elementTypes[] = $e.elementType;
        $f.elementSizes[] = $e.elementSize;
        $f.counts[] = $e.count;
        $f.dataSizes[] = $e.dataSize;
        $f.offsets[] = $e.offset;
    }
    return $f;
}

/**
 * Read and parse an ABIF file.
 *
 * @param path {string} the file, such as `sample.ab1`
 * @return {File} the file with its directory
 * @throws {Error} kind "abif" when the file is no ABIF file; reading it can throw as `fs.readBytes` does
 */
export func open(path as string) {
    return parse(fs.readBytes($path));
}

/**
 * Read and check the directory entry at `at`.
 *
 * @param data {bytes} the file
 * @param at {int} where the entry starts
 * @param size {int} the file's length
 * @return {Entry} the entry, `offset` made absolute for inline data
 */
func readEntry(data as bytes, at as int, size as int) {
    if ($at + ENTRY_SIZE > $size) {
        fail("the directory runs past the end of the file");
    }
    for (def i in 0..4) {
        if ($data[$at + $i] < 32 or $data[$at + $i] > 126) {
            fail(io.sprintf(
                "the directory entry at byte %d has a tag name that is not printable ASCII",
                $at));
        }
    }
    def e as Entry init Entry{
        name: convert.stringFromBytes("utf-8", binary.slice($data, $at, $at + 4)),
        number: binary.readInt("be", $data, $at + 4, 4),
        elementType: binary.readInt("be", $data, $at + 8, 2),
        elementSize: binary.readInt("be", $data, $at + 10, 2),
        count: binary.readInt("be", $data, $at + 12, 4),
        dataSize: binary.readInt("be", $data, $at + 16, 4),
        offset: binary.readInt("be", $data, $at + 20, 4)
    };
    def what as string init io.sprintf("%s %d", $e.name, $e.number);
    if ($e.number < 0 or $e.elementType < 1 or $e.elementSize < 1 or $e.count < 0) {
        fail($what + ": a negative number, or a type or element size below 1");
    }
    if (maps.has(ELEMENT_SIZES, $e.elementType) and $e.elementSize != ELEMENT_SIZES[$e.elementType]) {
        fail(io.sprintf(
            "%s: element type %d has %d-byte elements, not %d",
            $what,
            $e.elementType,
            ELEMENT_SIZES[$e.elementType],
            $e.elementSize));
    }
    if ($e.dataSize != $e.count * $e.elementSize) {
        fail(io.sprintf(
            "%s: %d bytes of data for %d elements of %d bytes",
            $what,
            $e.dataSize,
            $e.count,
            $e.elementSize));
    }
    if ($e.dataSize <= 4) {
        $e.offset = $at + 20;
    } elseif ($e.offset < HEADER_SIZE or $e.offset > $size - $e.dataSize) {
        fail(io.sprintf(
            "%s: its %d bytes at %d lie outside the file",
            $what,
            $e.dataSize,
            $e.offset));
    }
    return $e;
}

/**
 * Every tag in the file, as `NAME` + number (`DATA9`, `PBAS2`), in file
 * order.
 *
 * @param f {File} the file
 * @return {list of string} the tags
 */
export func tags(f as File) {
    def out as list of string init [];
    for (def i in 0..len($f.names)) {
        $out[] = $f.names[$i] + convert.toString($f.numbers[$i]);
    }
    return $out;
}

/**
 * The directory, in file order.
 *
 * @param f {File} the file
 * @return {list of Entry} every entry
 * @example
 *   for (def e in abif.entries($f)) {
 *       io.printf("%s %d: %s\n", $e.name, $e.number, abif.typeName($e.elementType));
 *   }
 */
export func entries(f as File) {
    def out as list of Entry init [];
    for (def i in 0..len($f.names)) {
        $out[] = entryAt($f, $i);
    }
    return $out;
}

/**
 * The entry at a position of the directory.
 *
 * @param f {File} the file
 * @param i {int} the position
 * @return {Entry} the entry
 */
func entryAt(f as File, i as int) {
    return Entry{
        name: $f.names[$i],
        number: $f.numbers[$i],
        elementType: $f.elementTypes[$i],
        elementSize: $f.elementSizes[$i],
        count: $f.counts[$i],
        dataSize: $f.dataSizes[$i],
        offset: $f.offsets[$i]
    };
}

/**
 * Whether the file has a tag.
 *
 * @param f {File} the file
 * @param name {string} the tag name, such as `PBAS`
 * @param number {int} the tag number
 * @return {bool} true when the directory lists it; false for a name that is not four characters
 */
export func has(f as File, name as string, number as int) {
    return len($name) == 4 and maps.has($f.index, $name + convert.toString($number));
}

/**
 * The directory entry of a tag.
 *
 * @param f {File} the file
 * @param name {string} the tag name, such as `DATA`
 * @param number {int} the tag number
 * @return {Entry} its entry
 * @throws {Error} kind "abif" when the name is not four characters or the file has no such tag
 */
export func entry(f as File, name as string, number as int) {
    # names are four characters, so `NAME` + number is a unique key only
    # for a four-character name: ("DATA1", 0) would find DATA 10
    if (len($name) != 4) {
        fail(io.sprintf("a tag name is four characters, got %d", len($name)));
    }
    def key as string init $name + convert.toString($number);
    if (not maps.has($f.index, $key)) {
        fail(io.sprintf("the file has no %s %d", $name, $number));
    }
    return entryAt($f, $f.index[$key]);
}

/**
 * The bytes of a tag's data, whatever its type.
 *
 * @param f {File} the file
 * @param name {string} the tag name
 * @param number {int} the tag number
 * @return {bytes} the data, `dataSize` bytes
 * @throws {Error} kind "abif" when the file has no such tag
 */
export func raw(f as File, name as string, number as int) {
    def e as Entry init entry($f, $name, $number);
    return binary.slice($f.data, $e.offset, $e.offset + $e.dataSize);
}
