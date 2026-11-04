#!/usr/bin/env bash
# The level clip for the testers (Stage 1: a grey level 1 with the boss upstairs). Javier & Claude.
# The bot (game/scripts/sim/hero_bot.gd) plays level 1 through, recorded small, then a clip at full speed and a sheet
# of one frame every five seconds; prints whether the bot won. Fenced (capped.sh) and timed like every Godot run.
# Usage: scripts/level_clip.sh OUT_DIR       (writes OUT_DIR/clips/level1.mp4 and OUT_DIR/frames/level1.png)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1"
TMP="$ROOT/scratch/level-clip.$$"
mkdir -p "$TMP" "$OUT/clips" "$OUT/frames"
timeout 900 "$ROOT/scripts/capped.sh" godot --path "$ROOT/game" --write-movie "$TMP/level.avi" --fixed-fps 60 \
  --resolution 960x540 -- --bot 2>&1 | grep -v '^Godot Engine' > "$TMP/godot.txt"
if grep -q 'SCRIPT ERROR' "$TMP/godot.txt"; then cat "$TMP/godot.txt"; echo "FAILED the level has a script error"; exit 1; fi
RESULT="$(grep '^LEVEL ' "$TMP/godot.txt" | tail -1)"
[ -n "$RESULT" ] || { echo "FAILED the level never ended"; exit 1; }
ffmpeg -loglevel error -y -i "$TMP/level.avi" -c:v libx264 -crf 28 -pix_fmt yuv420p "$OUT/clips/level1.mp4"
ffmpeg -loglevel error -y -i "$TMP/level.avi" -vf "select='not(mod(n\,300))',scale=384:-1,tile=6x6:padding=3:color=black" \
  -frames:v 1 "$OUT/frames/level1.png"
rm -rf "$TMP"
echo "OK level 1 by the bot: $RESULT; clips/level1.mp4, frames/level1.png"
