#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * tags example - list every tag of an ABIF file with its type, count and a
 * short look at its value.
 *
 *   jennifer run examples/tags.j [file.ab1|file.fsa|file.hid]
 *
 * Without an argument it reads testdata/test.fsa (run it from the deck root).
 */

use io;
use os;
use strings;

import "../src/abif.j" as abif;

/**
 * A short look at a value: text, or the first few numbers.
 *
 * @param v {abif.Value} the value
 * @return {string} at most about 50 characters
 */
func preview(v as abif.Value) {
    def s as string init "";
    match ($v) {
        when Ints(x) { $s = "{$x.values}"; }
        when Floats(x) { $s = "{$x.values}"; }
        when Text(x) { $s = "\"" + $x.value + "\""; }
        when Chars(x) { $s = io.sprintf("%d chars", len($x.data)); }
        when Dates(x) {
            def d as abif.Date init $x.values[0];
            $s = io.sprintf("%d-%d|pad=2|fill=0-%d|pad=2|fill=0", $d.year, $d.month, $d.day);
        }
        when Times(x) {
            def t as abif.Time init $x.values[0];
            $s = io.sprintf(
                "%d|pad=2|fill=0:%d|pad=2|fill=0:%d|pad=2|fill=0",
                $t.hour,
                $t.minute,
                $t.second);
        }
        when Thumbs(x) { $s = "thumb"; }
        when Bools(x) { $s = "{$x.values}"; }
        when Raw(x) { $s = io.sprintf("%d bytes", len($x.data)); }
    }
    if (len($s) > 50) {
        $s = $s[..47] + "...";
    }
    return strings.replace(strings.replace($s, "\n", " "), "\r", " ");
}

def path as string init "testdata/test.fsa";
if (len(os.ARGS) > 1) {
    $path = os.ARGS[1];
}
def f as abif.File init abif.open($path);
def all as list of abif.Entry init abif.entries($f);
io.printf("%s: ABIF version %d, %d tags\n", $path, $f.version, len($all));
for (def e in $all) {
    def look as string init "";
    try {
        $look = preview(abif.tag($f, $e.name, $e.number));
    } catch (err) {
        $look = "(" + $err.message + ")";
    }
    io.printf(
        "%s %d|pad=3 %s|pad=9 %d|pad=6  %s\n",
        $e.name,
        $e.number,
        abif.typeName($e.elementType),
        $e.count,
        $look);
}
