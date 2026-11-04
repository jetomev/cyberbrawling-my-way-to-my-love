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
    scene:cat@level1 scene:twins@roster_yard scene:coach@coach_gym scene:chrome@chrome_casino scene:static@static_plant \
    scene:rook@rook_penthouse scene:crane@crane_docks scene:godfather@tower_top \
    scene:proof_headbutt@tests/levels/open_street scene:proof_doorman@tests/levels/open_street \
    scene:proof_dancer@tests/levels/open_street scene:proof_enforcer@tests/levels/open_street \
    scene:proof_lookout@tests/levels/open_street scene:proof_grabber@tests/levels/open_street \
    scene:proof_swap@level3 scene:proof_shove@tests/levels/stairs scene:proof_climb@tests/levels/twins \
    scene:proof_escape@tests/levels/twins scene:proof_coach@coach_gym scene:proof_chrome@chrome_casino \
    scene:proof_crane@crane_docks scene:proof_static@static_plant scene:proof_rook@rook_penthouse scene:proof_ropes@coach_gym scene:proof_cab@crane_docks \
    scene:proof_gap@level4; do
  ARGS=(--trial "$T")
  LIMIT=300
  if [[ "$T" == scene:* ]]; then
    L="${T#*@}"; T="${T#scene:}"; T="${T%@*}"
    [[ "$L" == */* ]] || L="levels/$L"  # (a showcase level, or a test layout by its path)
    ARGS=(--level "res://$L.json" --scene "$T")
    [[ "$T" == proof_* ]] || LIMIT=600  # the boss scenes run 4800 frames: 3.5 min recorded on a quiet machine, past 5 on a busy one (6c908a7)
  fi
  TMP="$ROOT/scratch/trial-$T.$$"
  mkdir -p "$TMP"
  timeout "$LIMIT" "$ROOT/scripts/capped.sh" godot --path "$ROOT/game" --write-movie "$TMP/f.png" --fixed-fps 60 \
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
  # a proof's unbroken sequence (the testers, 2026-11-04: "one unbroken sequence, start frame through the outcome"):
  # every frame from the one before its START to 4 after its END, in order, pages of 60 (6 across, 10 down)
  S=$(grep -oE '^frame [0-9]+: START' "$OUT/$T.txt" | head -1 | grep -oE '[0-9]+')
  E=$(grep -oE '^frame [0-9]+: END' "$OUT/$T.txt" | head -1 | grep -oE '[0-9]+')
  if [ -n "$S" ] && [ -n "$E" ]; then
    rm -f "$OUT/$T"-sequence-*.png
    FIRST=$((S > 1 ? S - 2 : 0)); LAST=$((E + 3)); [ "$LAST" -ge "$N" ] && LAST=$((N - 1))
    PAGE=1; F=$FIRST
    while [ "$F" -le "$LAST" ]; do
      TO=$((F + 59)); [ "$TO" -gt "$LAST" ] && TO=$LAST
      for k in $(seq "$F" "$TO"); do printf "file '%s'\n" "$TMP/$(printf 'f%08d.png' "$k")"; done > "$TMP/seq.txt"
      ROWS=$(( (TO - F + 6) / 6 ))
      ffmpeg -loglevel error -y -f concat -safe 0 -i "$TMP/seq.txt" -vf "scale=320:-1,tile=6x$ROWS:padding=3:color=black" \
        -frames:v 1 "$OUT/$T-sequence-$PAGE.png"
      PAGE=$((PAGE + 1)); F=$((TO + 1))
    done
  fi
  rm -rf "$TMP"
done
echo "OK trials: $(ls "$OUT"/*.mp4 | grep -vc half) clips at full and half speed, $(ls "$OUT"/*-moments.png | wc -l) moments sheets, $(ls "$OUT"/*-sequence-1.png 2>/dev/null | wc -l) unbroken proof sequences in trials/"
