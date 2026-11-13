#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * dyes example - the dyes of a fragment run and the highest point of each
 * raw trace.
 *
 *   jennifer run examples/dyes.j [file.fsa]
 *
 * Without an argument it reads testdata/test.fsa (run it from the deck root).
 */

use io;
use os;

import "../src/abif.j" as abif;

def path as string init "testdata/test.fsa";
if (len(os.ARGS) > 1) {
    $path = os.ARGS[1];
}
def f as abif.File init abif.open($path);
for (def d in abif.dyes($f)) {
    def trace as list of int init abif.rawTrace($f, $d.number);
    def top as int init 0;
    for (def scan in 1..len($trace)) {
        if ($trace[$scan] > $trace[$top]) {
            $top = $scan;
        }
    }
    io.printf(
        "dye %d %s|pad=8 %d nm: %d scans, highest %d at scan %d\n",
        $d.number,
        $d.name,
        $d.wavelength,
        len($trace),
        $trace[$top],
        $top);
}
