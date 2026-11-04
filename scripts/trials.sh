#!/usr/bin/env bash
# The testers' controlled trials, recorded (their ask, 2026-11-03): each a short scripted clip where one thing happens
# on purpose with its numbers on screen (game/scripts/present/trials.gd). Javier & Claude. Fenced and timed.
# Usage: scripts/trials.sh OUT_DIR      (writes OUT_DIR/trials/<name>.mp4 and <name>.txt, what happened and when)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1/trials"
mkdir -p "$OUT"
for T in combo_edge injuries broken_arm weapon_wear weapons disarm counter dizzy scenery; do
  TMP="$ROOT/scratch/trial-$T.$$"
  mkdir -p "$TMP"
  timeout 300 "$ROOT/scripts/capped.sh" godot --path "$ROOT/game" --write-movie "$TMP/f.png" --fixed-fps 60 \
    --resolution 1280x720 -- --trial "$T" 2>&1 | grep -v '^Godot Engine' > "$OUT/$T.txt"
  if grep -q 'SCRIPT ERROR' "$OUT/$T.txt"; then echo "FAILED trial $T has a script error"; exit 1; fi
  if grep -q 'dumped core' "$OUT/$T.txt"; then echo "FAILED Godot crashed as it quit (see the core dump: coredumpctl list godot)"; exit 1; fi
  ffmpeg -loglevel error -y -framerate 60 -i "$TMP/f%08d.png" -c:v libx264 -pix_fmt yuv420p "$OUT/$T.mp4"
  ffmpeg -loglevel error -y -framerate 60 -i "$TMP/f%08d.png" -vf "setpts=2*PTS" -r 60 -c:v libx264 -pix_fmt yuv420p "$OUT/$T-half.mp4"
  # a sheet of 12 frames with the numbers on screen, for the testers, who read pictures
  N=$(ls "$TMP" | grep -c '^f.*png$')
  ffmpeg -loglevel error -y -i "$TMP/f%08d.png" -vf "select='not(mod(n\,$(( N / 12 + 1 ))))',scale=640:-1,tile=3x4:padding=4:color=black" \
    -frames:v 1 "$OUT/$T.png"
  rm -rf "$TMP"
done
echo "OK trials: $(ls "$OUT"/*.mp4 | grep -vc half) clips at full and half speed in trials/"
