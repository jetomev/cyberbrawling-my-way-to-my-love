#!/usr/bin/env bash
# Record the scripted demo to frames, then make a contact sheet and a short clip. Javier & Claude.
# Opens a game window for the demo's length (about 8 s), fenced (capped.sh) and timed. Frames go to scratch/ (on disk,
# git-ignored); the sheet and clip land in scratch/record/<stamp>/. Logs to logs/record-<stamp>.log (+ -latest).
# Usage: scripts/record.sh [game options]     e.g. scripts/record.sh --flat
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/scratch/record/$STAMP"
mkdir -p "$ROOT/logs" "$OUT/frames"
LOG="$ROOT/logs/record-$STAMP.log"
ln -sfn "$(basename "$LOG")" "$ROOT/logs/record-latest.log"
{
  echo "Cyberbrawling my way to my love! — recording the demo — $STAMP"
  if [ ! -d "$ROOT/game/.godot" ]; then
    timeout 300 "$ROOT/scripts/capped.sh" godot --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
  fi
  timeout 120 "$ROOT/scripts/capped.sh" godot --path "$ROOT/game" --write-movie "$OUT/frames/f.png" \
    --fixed-fps 60 -- --demo "$@" 2>&1 | grep -v '^Godot Engine' | tee "$OUT/godot.txt"
  # a game that fails to load still opens a window and records nothing worth seeing: stop on any script error
  if grep -q 'SCRIPT ERROR' "$OUT/godot.txt"; then echo "FAILED the game has a script error"; exit 1; fi
  N=$(ls "$OUT/frames" | wc -l)
  echo "frames: $N"
  [ "$N" -gt 60 ] || { echo "FAILED too few frames"; exit 1; }
  # nine moments across the demo, three by three
  ffmpeg -loglevel error -y -i "$OUT/frames/f%08d.png" \
    -vf "select='not(mod(n\,$(( N / 9 ))))',scale=640:-1,tile=3x3:padding=6:color=black" -frames:v 1 "$OUT/sheet.png"
  ffmpeg -loglevel error -y -framerate 60 -i "$OUT/frames/f%08d.png" -vf "scale=960:-2" -c:v libx264 \
    -pix_fmt yuv420p "$OUT/demo.mp4"
  ls -la "$OUT/sheet.png" "$OUT/demo.mp4"
  echo "OK recorded $N frames: $OUT"
} > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
