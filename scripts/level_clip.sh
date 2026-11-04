#!/usr/bin/env bash
# The level clip for the testers (Stage 1: a grey level 1 with the boss upstairs). Javier & Claude.
# The bot (game/scripts/sim/hero_bot.gd) plays level 1 through, recorded small, then a clip at full speed and a sheet
# of one frame every five seconds; prints whether the bot won. Fenced (capped.sh) and timed like every Godot run.
# Usage: scripts/level_clip.sh OUT_DIR [name] [seed]   (writes OUT_DIR/clips/<name>.mp4 and OUT_DIR/frames/<name>.png;
#        name is levels/<name>.json, level1 by default; seed the run the bot plays, 2 by default)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1"
NAME="${2:-level1}"
SEED="${3:-2}"
TMP="$ROOT/scratch/level-clip.$$"
mkdir -p "$TMP" "$OUT/clips" "$OUT/frames"
timeout 900 "$ROOT/scripts/capped.sh" godot --path "$ROOT/game" --write-movie "$TMP/level.avi" --fixed-fps 60 \
  --resolution 960x540 -- --level "res://levels/$NAME.json" --bot --seed "$SEED" 2>&1 | grep -v '^Godot Engine' > "$TMP/godot.txt"
if grep -q 'SCRIPT ERROR' "$TMP/godot.txt"; then cat "$TMP/godot.txt"; echo "FAILED the level has a script error"; exit 1; fi
if grep -q 'dumped core' "$TMP/godot.txt"; then echo "FAILED Godot crashed as it quit (see the core dump: coredumpctl list godot)"; exit 1; fi
RESULT="$(grep '^LEVEL ' "$TMP/godot.txt" | tail -1)"
[ -n "$RESULT" ] || { echo "FAILED the level never ended"; exit 1; }
ffmpeg -loglevel error -y -i "$TMP/level.avi" -c:v libx264 -crf 28 -pix_fmt yuv420p "$OUT/clips/$NAME.mp4"
ffmpeg -loglevel error -y -i "$TMP/level.avi" -vf "select='not(mod(n\,300))',scale=384:-1,tile=6x6:padding=3:color=black" \
  -frames:v 1 "$OUT/frames/$NAME.png"
# the ending as pictures (the testers, 2026-11-04: level 2's ending was only in the clip): the last 8 seconds, a frame
# every 20 (the last blows, the boss going down, "cleared" on screen)
N=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$TMP/level.avi")
FROM=$((N > 480 ? N - 480 : 0))
ffmpeg -loglevel error -y -i "$TMP/level.avi" -vf "select='gte(n\,$FROM)*not(mod(n-$FROM\,20))',scale=480:-1,tile=4x6:padding=3:color=black" \
  -frames:v 1 "$OUT/frames/$NAME-ending.png"
rm -rf "$TMP"
echo "OK $NAME by the bot (seed $SEED): $RESULT; clips/$NAME.mp4, frames/$NAME.png, frames/$NAME-ending.png"
