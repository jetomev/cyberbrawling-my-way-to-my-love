#!/usr/bin/env bash
# The testers' controlled trials, recorded (their ask, 2026-11-03): each a short scripted clip where one thing happens
# on purpose with its numbers on screen (game/scripts/present/trials.gd). Javier & Claude. Fenced and timed.
# Usage: scripts/trials.sh OUT_DIR      (writes OUT_DIR/trials/<name>.mp4 and <name>.txt, what happened and when)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1/trials"
mkdir -p "$OUT"
# the trials on a bare street, then the scenes on a real level (scene:<name>, present/scenes.gd: the cat)
# (scene:<name>@<level>: the scene on that level)
for T in combo_edge injuries broken_arm weapon_wear weapons disarm counter dizzy records bass_drop scenery umbrella first_aid \
    scene:cat@level1 scene:twins@roster_yard scene:coach@coach_gym scene:chrome@chrome_casino; do
  ARGS=(--trial "$T")
  if [[ "$T" == scene:* ]]; then L="${T#*@}"; T="${T#scene:}"; T="${T%@*}"; ARGS=(--level "res://levels/$L.json" --scene "$T"); fi
  TMP="$ROOT/scratch/trial-$T.$$"
  mkdir -p "$TMP"
  timeout 300 "$ROOT/scripts/capped.sh" godot --path "$ROOT/game" --write-movie "$TMP/f.png" --fixed-fps 60 \
    --resolution 1280x720 -- "${ARGS[@]}" 2>&1 | grep -v '^Godot Engine' > "$OUT/$T.txt"
  grep -q "^TRIAL DONE $T" "$OUT/$T.txt" || { cat "$OUT/$T.txt"; echo "FAILED trial $T never finished"; exit 1; }
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
  # the moments sheet (the testers, 2026-11-04: "the moment + the 4 frames after it"): a row for each key moment the
  # trial logged ("frame N: ..."): the frame before it (the blow landing), the moment and the 4 after it, up to 12 rows
  # (the picture of frame N is f<N-1>.png: the movie's first picture is frame 1)
  ROWS=$(grep -cE '^frame [0-9]+:' "$OUT/$T.txt")
  [ "$ROWS" -gt 12 ] && ROWS=12
  if [ "$ROWS" -gt 0 ]; then
    for k in $(grep -oE '^frame [0-9]+:' "$OUT/$T.txt" | head -12 | grep -oE '[0-9]+'); do
      for d in -2 -1 0 1 2 3; do
        F=$((k + d)); [ "$F" -lt 0 ] && F=0; [ "$F" -ge "$N" ] && F=$((N - 1))
        printf "file '%s'\n" "$TMP/$(printf 'f%08d.png' "$F")"
      done
    done > "$TMP/moments.txt"
    ffmpeg -loglevel error -y -f concat -safe 0 -i "$TMP/moments.txt" -vf "scale=480:-1,tile=6x$ROWS:padding=4:color=black" \
      -frames:v 1 "$OUT/$T-moments.png"
  fi
  rm -rf "$TMP"
done
echo "OK trials: $(ls "$OUT"/*.mp4 | grep -vc half) clips at full and half speed, $(ls "$OUT"/*-moments.png | wc -l) moments sheets in trials/"
