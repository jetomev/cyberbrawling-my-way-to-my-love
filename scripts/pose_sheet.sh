#!/usr/bin/env bash
# Draw poses side by side, large, and save the picture (game/tools/pose_sheet.gd). Javier & Claude.
# Fenced (capped.sh) and timed like every Godot run. Writes scratch/pose-sheet/<stamp>.png and prints its path.
# Usage: scripts/pose_sheet.sh idle:0 walk:8 cross:5 air_kick:3:air
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/scratch/pose-sheet/$STAMP"
mkdir -p "$OUT"
timeout 60 "$ROOT/scripts/capped.sh" godot --path "$ROOT/game" --write-movie "$OUT/f.png" --fixed-fps 60 \
  -s res://tools/pose_sheet.gd -- "$@" 2>&1 | grep -E "SCRIPT ERROR|ERROR" | head -5
LAST="$(ls "$OUT"/f*.png 2>/dev/null | tail -1)"
[ -n "$LAST" ] || { echo "FAILED no picture"; exit 1; }
cp "$LAST" "$OUT.png"
rm -rf "$OUT"
echo "OK $OUT.png"
