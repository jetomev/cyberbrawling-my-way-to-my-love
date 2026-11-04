#!/usr/bin/env bash
# Every armed blow, weapon by weapon, recorded and cut for the testers (game/tools/armed_blows.gd): close-ups of each
# weapon's grip and block, and every blow its hands make, every frame from Ready through contact and recovery, as
# sheets and as clips at full and half speed. Javier & Claude. Fenced (capped.sh) and timed like every Godot run.
# Usage: scripts/armed_blows.sh OUT_DIR   (writes OUT_DIR/armed/: grips.png, <weapon>/NN-<blow>-N.png, <weapon>.mp4, -half)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1/armed"
TMP="$ROOT/scratch/armed.$$"
mkdir -p "$OUT" "$TMP"
timeout 600 "$ROOT/scripts/capped.sh" godot --path "$ROOT/game" --write-movie "$TMP/f.png" --fixed-fps 60 \
  --resolution 1280x720 -s res://tools/armed_blows.gd 2>&1 | grep -v '^Godot Engine' > "$OUT/segments.txt"
if grep -q 'SCRIPT ERROR' "$OUT/segments.txt"; then cat "$OUT/segments.txt"; echo "FAILED the armed blows have a script error"; exit 1; fi
grep -q '^ARMED DONE' "$OUT/segments.txt" || { cat "$OUT/segments.txt"; echo "FAILED the armed blows never finished"; exit 1; }
python3 "$ROOT/scripts/armed_blows.py" "$TMP" "$OUT" || { echo "FAILED could not cut the armed blows"; exit 1; }
rm -rf "$TMP"
echo "OK armed blows: $OUT"
