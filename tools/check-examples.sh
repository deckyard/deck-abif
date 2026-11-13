#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
#
# How this deck's examples are checked. This file belongs to the deck, not to
# the shared CI layer: the workflows call it, and it is the place to say what
# the examples need.
#
# Every example reads a sample file from testdata/ by a relative path when it
# gets no argument, so the shared runner runs them as they are from the deck
# root.
#
# Usage: tools/check-examples.sh
set -euo pipefail
cd "$(dirname "$0")/.."
exec tools/check-examples-shared.sh "$@"
