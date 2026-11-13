<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Reading a file

`open` reads a file and `parse` takes its bytes; both return a `File`, the
bytes with their checked directory.

```jennifer
def f as abif.File init abif.open("run.fsa");
io.printf("version %d, %d tags\n", $f.version, len(abif.tags($f)));
```

`parse` refuses a file whose header or directory does not fit it: fewer than
128 bytes, no `ABIF` magic, a version outside 1.xx to 3.xx, a directory past
the end, an entry whose data lies outside the file or whose size disagrees
with its element type and count, a tag name that is not printable ASCII, or
a tag listed twice. Nothing is read from an entry before all of them pass.

## The directory

A tag is a four-character name and a number: `DATA` 1 is the first raw
trace, `PBAS` 2 the called bases. `tags` lists them as `NAME` + number,
`has` asks for one, and `entry` returns its `Entry`: element type, size,
count and where the data is. `entries` returns them all, in file order.

```jennifer
for (def e in abif.entries($f)) {
    io.printf("%s %d: %s x %d\n", $e.name, $e.number, abif.typeName($e.elementType), $e.count);
}
if (abif.has($f, "PBAS", 2)) {
    io.printf("a sequencing run\n");
}
```

`raw` returns a tag's bytes whatever its type: the way to user-defined types
(1024 and up), the obsolete ones, and text that is not UTF-8.

## Values

`tag` decodes a tag by its element type into a `Value`. Read the payload
with `match`:

```jennifer
def v as abif.Value init abif.tag($f, "RUND", 1);
match ($v) {
    when Dates(d) {
        io.printf("run started in %d\n", $d.values[0].year);
    }
    else {
        io.printf("RUND 1 is no date\n");
    }
}
```

| Element types | Variant |
|---|---|
| `byte`, `word` (unsigned), `short`, `long` (signed) | `Ints` |
| `float`, `double` | `Floats` |
| `char` | `Chars`, the bytes |
| `pString`, `cString` | `Text` |
| `date`, `time`, `thumb`, `bool` | `Dates`, `Times`, `Thumbs`, `Bools` |
| anything else | `Raw`, with the type code |

`char` stays bytes because the format uses it both for text (`PBAS`, `MODL`)
and for small numbers (`PCON`, the qualities).

## Typed readers

When the type is known, `text`, `ints` and `floats` skip the `match`, and
throw when the tag holds something else:

```jennifer
def sample as string init abif.text($f, "SMPL", 1);
def scale as list of float init abif.floats($f, "Scal", 1);
def quals as list of int init abif.ints($f, "PCON", 2);
```

`text` takes `pString`, `cString` and `char` tags and decodes them as UTF-8;
nothing is trimmed. A `pString` whose length byte does not match its data, a
`cString` that does not end at its only NUL, and bytes that are not UTF-8
are errors; `raw` still returns them. `ints` reads `char` as 0 to 255.
