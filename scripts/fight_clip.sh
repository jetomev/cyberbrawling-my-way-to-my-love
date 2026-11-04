#!/usr/bin/env bash
# The fight clip for the testers (Stage 1: an enemy that fights back). Javier & Claude.
# A bot plays the hero (game/scripts/sim/hero_bot.gd) against the thugs for 25 s, recorded; then a clip at full and
# at half speed and a sheet of one frame every half second. Fenced (capped.sh) and timed like every Godot run.
# Usage: scripts/fight_clip.sh OUT_DIR       (writes OUT_DIR/clips/fight.mp4, fight-half.mp4, OUT_DIR/frames/fight.png)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1"
TMP="$ROOT/scratch/fight-clip.$$"
mkdir -p "$TMP" "$OUT/clips" "$OUT/frames"
timeout 300 "$ROOT/scripts/capped.sh" godot --path "$ROOT/game" --write-movie "$TMP/f.png" --fixed-fps 60 \
  --resolution 1280x720 -- --fight 2>&1 | grep -v '^Godot Engine' > "$TMP/godot.txt"
if grep -q 'SCRIPT ERROR' "$TMP/godot.txt"; then cat "$TMP/godot.txt"; echo "FAILED the fight has a script error"; exit 1; fi
if grep -q 'dumped core' "$TMP/godot.txt"; then echo "FAILED Godot crashed as it quit (see the core dump: coredumpctl list godot)"; exit 1; fi
N=$(ls "$TMP" | grep -c '^f.*png$')
[ "$N" -gt 600 ] || { echo "FAILED too few fight frames ($N)"; exit 1; }
ffmpeg -loglevel error -y -framerate 60 -i "$TMP/f%08d.png" -c:v libx264 -pix_fmt yuv420p "$OUT/clips/fight.mp4"
ffmpeg -loglevel error -y -framerate 60 -i "$TMP/f%08d.png" -vf "setpts=2*PTS" -r 60 -c:v libx264 -pix_fmt yuv420p "$OUT/clips/fight-half.mp4"
ffmpeg -loglevel error -y -i "$TMP/f%08d.png" -vf "select='not(mod(n\,30))',scale=480:-1,tile=5x10:padding=4:color=black" \
  -frames:v 1 "$OUT/frames/fight.png"
rm -rf "$TMP"
echo "OK the fight: $N frames, clips/fight.mp4 and -half, frames/fight.png"
