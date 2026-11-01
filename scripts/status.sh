#!/usr/bin/env bash
# The project's summary for `mindforge active`: the board line and each stage's progress, read live from TODO.md.
here="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$HOME/Programs/mindforge/boards/board.py" status "$here"
