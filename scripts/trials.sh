#!/usr/bin/env bash
# The testers' controlled trials, recorded (their ask, 2026-11-03): each a short scripted clip where one thing happens
# on purpose with its numbers on screen (game/scripts/present/trials.gd). Javier & Claude. Fenced and timed.
# Usage: scripts/trials.sh OUT_DIR      (writes OUT_DIR/trials/<name>.mp4 and <name>.txt, what happened and when)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1/trials"
mkdir -p "$OUT"
for T in combo_edge injuries broken_arm weapon_wear weapons disarm counter dizzy records bass_drop scenery; do
  TMP="$ROOT/scratch/trial-$T.$$"
  mkdir -p "$TMP"
  timeout 300 "$ROOT/scripts/capped.sh" godot --path "$ROOT/game" --write-movie "$TMP/f.png" --fixed-fps 60 \
    --resolution 1280x720 -- --trial "$T" 2>&1 | grep -v '^Godot Engine' > "$OUT/$T.txt"
  if grep -q 'SCRIPT ERROR' "$OUT/$T.txt"; then echo "FAILED trial $T has a script error"; exit 1; fi
  if grep -q 'dumped core' "$OUT/$T.txt"; then echo "FAILED Godot crashed as it quit (see the core dump: coredumpctl list godot)"; exit 1; fi
  ffmpeg -loglevel error -y -framerate 60 -i "$TMP/f%08d.png" -c:v libx264 -pix_fmt yuv420p "$OUT/$T.mp4"
  ffmpeg -loglevel error -y -framerate 60 -i "$TMP/f%08d.png" -vf "setpts=2*PTS" -r 60 -c:v libx264 -pix_fmt yuv420p "$OUT/$T-half.mp4"
  # a sheet for the testers, who read pictures: the frame of every moment the trial logged (and 4 frames after, to see
  # it land), filled out with evenly spaced frames, in order, 24 in all (the testers, 2026-11-04: a sampled sheet missed
  # the moments themselves)
  N=$(ls "$TMP" | grep -c '^f.*png$')
  PICK=$(python3 -c '
import re, sys
n, log = int(sys.argv[1]), open(sys.argv[2]).read()
moments = sorted({f for m in re.findall(r"^frame (\d+)", log, re.M) for f in (int(m), int(m) + 4) if f < n})[:24]
fill = [round(i * (n - 1) / 23) for i in range(24)]
pick = set(moments)
for f in fill:
    if len(pick) >= 24:
        break
    pick.add(f)
print("+".join("eq(n\\,%d)" % f for f in sorted(pick)))
' "$N" "$OUT/$T.txt")
  ffmpeg -loglevel error -y -i "$TMP/f%08d.png" -vf "select='$PICK',scale=640:-1,tile=4x6:padding=4:color=black" \
    -frames:v 1 "$OUT/$T.png"
  rm -rf "$TMP"
done
echo "OK trials: $(ls "$OUT"/*.mp4 | grep -vc half) clips at full and half speed in trials/"
