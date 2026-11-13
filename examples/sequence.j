#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * sequence example - a Sanger trace's base calls as a FASTQ record.
 *
 *   jennifer run examples/sequence.j [file.ab1]
 *
 * Without an argument it reads testdata/3730.ab1 (run it from the deck root).
 */

use convert;
use io;
use os;
use strings;

import "../src/abif.j" as abif;

def path as string init "testdata/3730.ab1";
if (len(os.ARGS) > 1) {
    $path = os.ARGS[1];
}
def f as abif.File init abif.open($path);
def i as abif.Info init abif.info($f);
def c as abif.Calls init abif.calls($f);

# FASTQ writes each quality as one character, Phred + 33
def quals as list of string init [];
for (def q in $c.qualities) {
    if ($q > 93) {
        $q = 93;
    }
    $quals[] = convert.fromCodepoint($q + 33);
}
io.printf("@%s well=%s model=%s run=%s\n", $i.sample, $i.well, $i.model, $i.runStart);
io.printf("%s\n+\n%s\n", $c.bases, strings.join($quals, ""));
