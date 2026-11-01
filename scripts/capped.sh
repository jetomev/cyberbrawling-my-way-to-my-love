#!/usr/bin/env bash
# Run a command inside a fenced box so it can never take the whole PC down (2026-10-26: a runaway test stranded
# 2,809 3D models, filled 31 GB and crashed the desktop). The box: at most CAP_MEM of memory (default 6G), no swap
# (a runaway is killed at once instead of grinding the machine), at most CAP_CPU (default 800% = 8 of 16 cores).
# Only the boxed command is killed when it goes over; the desktop keeps running.
# Usage: scripts/capped.sh <command> [args...]      e.g. scripts/capped.sh godot --headless --path game ...
set -u
exec systemd-run --user --scope --quiet --collect \
  -p MemoryMax="${CAP_MEM:-6G}" -p MemorySwapMax=0 -p CPUQuota="${CAP_CPU:-800%}" -- "$@"
