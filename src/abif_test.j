# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * White-box tests: jennifer test src/abif_test.j (from the deck root)
 *
 * Most tests build small ABIF files in code (`build` in
 * `topics/core_test.j`), so they run where jvc runs the overlays: from a
 * copy of src/ alone. `topics/samples/samples_test.j` reads real instrument files
 * from `testdata/` (see its README) and checks them against Biopython's
 * expected values; it skips them when `testdata/` is not there.
 */
use lists;
use testing;

include "topics/core_test.j";
include "topics/values_test.j";
include "topics/run_test.j";
include "topics/samples/samples_test.j";
