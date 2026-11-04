#!/usr/bin/env bash
# The build step (Javier, 2026-11-01: "have the team critize the build, before I do it"). Javier & Claude.
# 1. the tests (a red test stops the build: no demo of a broken build);
# 2. the recorded demo (scripts/record.sh): a clip and a contact sheet;
# 3. for every move (scripts/closeups.py): a still as it lands, close-ups of the hips, hands and feet, and a timed
#    strip of close-ups through the whole move (the team's asks, 2026-11-02: the hero is small in the demo frame, and
#    they read pictures, not video); the hero beside the recordings his movement was measured from (D-30);
# 4. a short build note; 5. all of it copied to the builds folder (~/Documents/Cyberbrawling/builds, or
# $CYBERBRAWLING_BUILDS), where the assistant team critiques it first. Javier's shelf (first line of .review-shelf,
# git-ignored, or $REVIEW_SHELF) gets one plain report a day, cyberbrawling-report-YYYY-MM-DD.md, written by hand;
# the build says whether today's exists. Logs to logs/build-<stamp>.log (+ -latest).
# Usage: scripts/build.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M)"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"
DIRTY="$(git -C "$ROOT" status --porcelain -- game | head -1)"
NAME="cyberbrawling-build-$STAMP-$COMMIT${DIRTY:+-wip}"
OUT="$ROOT/scratch/build/$NAME"
mkdir -p "$ROOT/logs" "$OUT"
LOG="$ROOT/logs/build-$STAMP.log"
ln -sfn "$(basename "$LOG")" "$ROOT/logs/build-latest.log"
fail() { echo "FAILED $*"; exit 1; }
(
  echo "Cyberbrawling my way to my love! — build $NAME"
  echo "== 1. tests"
  "$ROOT/scripts/test.sh" > "$OUT/tests.txt" 2>&1 || { tail -n 20 "$OUT/tests.txt"; fail "tests are red: no demo"; }
  TESTS="$(grep '^OK [0-9]* tests (' "$OUT/tests.txt" | tail -1)"
  echo "$TESTS"
  echo "== 2. demo"
  "$ROOT/scripts/record.sh" --marks "$OUT/marks.txt" > "$OUT/record.txt" 2>&1 || { tail -n 20 "$OUT/record.txt"; fail "the recording failed"; }
  REC="$(sed -n 's/^OK recorded [0-9]* frames: //p' "$OUT/record.txt")"
  [ -d "$REC" ] || fail "no recording folder"
  FRAMES="$(ls "$REC/frames" | wc -l)"
  # every frame is marked but the last, drawn as the demo quits
  [ "$(grep -vc '^#' "$OUT/marks.txt" 2>/dev/null)" -ge $((FRAMES - 1)) ] || fail "the demo didn't mark its frames: no close-ups"
  cp "$REC/demo.mp4" "$REC/sheet.png" "$OUT/"
  echo "== 3. the moves: stills, close-ups and timed strips"
  MOMENTS="$(timeout 120 "$ROOT/scripts/capped.sh" godot --headless --path "$ROOT/game" -s res://tools/demo_moments.gd 2>/dev/null | grep -E '^[a-z_-]+:[0-9]+:[0-9]+:[0-9]+$')"
  [ -n "$MOMENTS" ] || fail "no moves found in the demo"
  python3 "$ROOT/scripts/closeups.py" "$REC/frames" "$OUT/marks.txt" "$OUT" $MOMENTS || fail "could not cut the stills"
  echo "$(echo $MOMENTS | wc -w) moves: $(echo $MOMENTS | sed 's/:[0-9:]*//g')"
  # the sweep from above (the testers, 2026-11-02 23:29: its circle can't show from the side)
  timeout 60 "$ROOT/scripts/capped.sh" godot --headless --path "$ROOT/game" -s res://tools/sweep_above.gd 2>/dev/null \
    | grep -E '^[0-9]+ |^hit' > "$OUT/sweep_above.txt" && python3 "$ROOT/scripts/sweep_above.py" "$OUT/sweep_above.txt" \
    "$OUT/frames/sweep-from-above.png" || fail "could not draw the sweep from above"
  # the sweep's spin frame by frame with its whole circle in view (the testers, 02:29 on 0922751)
  SWEEP="$(echo $MOMENTS | tr ' ' '\n' | grep '^sweep:' | head -n 1)"
  [ -n "$SWEEP" ] && python3 "$ROOT/scripts/sweep_spin.py" "$REC/frames" "$OUT/marks.txt" "$OUT/sweep_above.txt" "$SWEEP" \
    "$OUT/frames/sweep-spin.png" "$OUT/clips/sweep-spin.mp4" || fail "could not draw the sweep's spin with its circle"
  # a whole fight: a bot plays the hero against the thugs, who fight back (Stage 1)
  "$ROOT/scripts/fight_clip.sh" "$OUT" > "$OUT/fight.txt" 2>&1 || { cat "$OUT/fight.txt"; fail "could not record the fight"; }
  # level 1 played through by the bot: the waves, the stairs, the boss (Stage 1)
  "$ROOT/scripts/level_clip.sh" "$OUT" > "$OUT/level.txt" 2>&1 || { cat "$OUT/level.txt"; fail "could not record level 1"; }
  LEVEL_RESULT="$(tail -1 "$OUT/level.txt")"
  # the testers' controlled trials: one thing on purpose each, its numbers on screen (2026-11-03)
  "$ROOT/scripts/trials.sh" "$OUT" > "$OUT/trials.txt" 2>&1 || { cat "$OUT/trials.txt"; fail "could not record the trials"; }
  # the hero beside the recordings he was measured from (D-30); the recordings live outside the repo, so a machine
  # without them builds without these pictures and the note says so
  SBS="no"
  if [ -d "$HOME/Programs/cyberbrawling-reference/cmu" ]; then
    python3 "$ROOT/scripts/reference_strips.py" "$REC/frames" "$OUT/marks.txt" "$OUT" $MOMENTS || fail "could not draw the side-by-sides"
    SBS="yes"
  fi
  # measurements on the drawing for the notes, and every frame sheet checked to cover its whole move (the testers,
  # 00:57 on 66ce4c6: "measure it yourself ... and put that number in the build notes"; "make sure each sheet covers
  # the whole action start to finish")
  MEASURE="$(timeout 60 "$ROOT/scripts/capped.sh" godot --headless --path "$ROOT/game" -s res://tools/measure.gd 2>/dev/null | grep -v '^Godot')"
  echo "$MEASURE" | grep -q '^- Power punch' || fail "could not measure the drawing"
  WHOLE="$(python3 - "$MEASURE" $MOMENTS <<'PY'
import sys
lens = {l.split(":")[1]: int(l.split(":")[2]) for l in sys.argv[1].splitlines() if l.startswith("len:")}
short = []
n = 0
for item in sys.argv[2:]:
    name, hit, start, end = item.split(":")
    move = name.replace("-cycle-frames", "")
    if move not in lens:
        continue
    n += 1
    if int(end) - int(start) + 1 < lens[move]:
        short.append(f"{move} ({int(end) - int(start) + 1} of {lens[move]} frames)")
print(f"- Every frame sheet covers its whole move: {n} moves checked, each from its first frame to its last, with 8"
      if not short else "- NOT WHOLE: " + ", ".join(short))
if not short:
    print("  frames more on either side (the frames before and after can be the moves chained to it).")
PY
)"
  echo "$WHOLE" | grep -q '^- Every frame sheet' || fail "a frame sheet doesn't cover its whole move: $WHOLE"
  echo "== 4. the note"
  {
    echo "# Build $NAME"
    echo
    echo "*Cyberbrawling my way to my love! Javier & Claude. For the assistant team's review before Javier plays it.*"
    echo
    echo "- Commit: \`$COMMIT\`${DIRTY:+ (with work not yet committed)} — $(git -C "$ROOT" log -1 --format=%s)"
    echo "- Tests: $TESTS"
    echo "- Files: \`demo.mp4\` (the scripted demo), \`moves.png\` (each move as it lands), \`sheet.png\` (nine moments),"
    echo "  \`closeups.png\` and \`closeups/\` (each move as it lands: the whole body, the hips, the hands, the feet, up close),"
    echo "  \`strips/NN-move.png\` (each move from start to end, a still every 50 ms lined up on the hit: whole body, hips,"
    echo "  hands, feet), \`strips/NN-move-hit.png\` (every frame from 100 ms before the hit to 50 ms after) and"
    echo "  \`strips/NN-landing-N.png\` (every frame of the flying kick's landing, from the air until he is back up),"
    echo "  \`strips/NN-<walk|stroll|run|to_walk|to_fight>-cycle-frames-N.png\` (every frame of the walking, running and stance switches),"
    echo "  \`clips/NN-move.mp4\` and \`clips/NN-move-half.mp4\` (each move moving, close up, at full speed and at half speed),"
    echo "  \`frames/NN-move.png\` (every frame of that clip, in order, 60 a second, ten to a row, each with its time from"
    echo "  the hit, or from the first frame of a walk or run cycle; half speed is the same frames), and beside each"
    echo "  \`frames/NN-move-street.png\` and \`clips/NN-move-street.mp4\` / \`-street-half.mp4\`: the same with the street held"
    echo "  still (the game's camera follows him; the build undoes its panning), so his travel along the street shows"
    echo "- \`frames/sweep-from-above.png\`: the sweep's foot path seen from above, a dot a frame (worked out from the pose's"
    echo "  spin and the foot's reach; the game draws only from the side). \`frames/NN-runkick.png\` and the runkick strips"
    echo "  and clips: the running flying kick whole, from the first running step to half a second after landing"
    echo "- \`frames/sweep-spin.png\` and \`clips/sweep-spin.mp4\` / \`-half.mp4\`: the sweep's spin, every frame, the side view"
    echo "  with the street held still beside the foot's whole circle from above, that frame's place on it lit"
    if [ "$SBS" = yes ]; then
      echo "- Side by side: \`reference/NN-<move>-side-by-side.png\` (jump, flying kick, walk, stance; power punch, cross, jab,"
      echo "  body kick, round kick, side kick: each seen along the way the blow goes), the hero (top) beside the"
      echo "  recording his movement was measured from (below, a stick figure scaled to the same leg length, on the same"
      echo "  street line), lined up on the move's events; each column gives both times. The recorded jump is a small"
      echo "  forward hop (the feet rise about a fifth of the hip height) and the game jump clears a crate, so compare"
      echo "  the shapes (crouch, extension, legs reaching for the landing), not the heights. The flying kick compares the"
      echo "  leg's shape only (the recorded kick is done standing); the stance row is the recorded kicker standing"
      echo "  ready before his kick. Reference: CMU, mocap.cs.cmu.edu (never in the game)."
    else
      echo "- Side by side: not drawn (no reference recordings on this machine)"
    fi
    echo "- \`trials/<name>.png\` (12 frames, the numbers on screen), \`trials/<name>.mp4\` / \`-half.mp4\` and \`trials/<name>.txt\` (what happened on which frame): the controlled"
    echo "  trials, one thing on purpose each with its numbers on screen. combo_edge: the next press 23, 24, 25 frames after a"
    echo "  jab ends (the window is $(grep -o '"combo_window_ticks": [0-9]*' "$ROOT/game/scripts/sim/tuning.gd" | grep -o '[0-9]*$') frames, the last frame that still chains); injuries: low kicks to"
    echo "  bruised, swollen, broken, then the limp's speed; weapon_wear: a stick swung until it breaks; disarm: a perfect"
    echo "  block, then a counter, each knocking a pipe loose; dizzy: two three-punch combos in a row; scenery: a steady"
    echo "  6 px a frame pan with each layer's speed on screen"
    echo "- \`clips/level1.mp4\` and \`frames/level1.png\` (a frame every 5 s): level 1 played through by the bot: four"
    echo "  waves along the street (it locks at each until they're beaten), food and first aid lying about, the stairs, the"
    echo "  boss upstairs; three lives. A grey placeholder layout until the team's lands. How it went: $LEVEL_RESULT"
    echo "- \`clips/fight.mp4\` / \`fight-half.mp4\` and \`frames/fight.png\` (a frame every half second): a 25 s fight, a bot"
    echo "  playing the hero against thugs who fight back (red): they walk up, throw combos with a breath between, sometimes"
    echo "  block (a white flash is a perfect block); blows make them flinch, reel, get shoved, knocked down, thrown up;"
    echo "  they get back up; the last blow puts one down for good and he drops his pipe; another walks in"
    echo "- \`frames/NN-roll-shoulder.png\` and \`clips/NN-roll-shoulder.mp4\` / \`-half.mp4\`: the shoulders up close through"
    echo "  the whole roll, every frame, the shoulder point ringed, the street under it"
    echo "- Moves in the demo: $(echo $MOMENTS | sed 's/:[0-9:]*//g')"
    echo "- Drawn with no recording behind them: the sweep (Z, from the posture sheet; no recorded sweep exists in the"
    echo "  libraries we use) and the roll (C, from common technique; CMU 128_09 \"Run Roll Underneath\" is the candidate,"
    echo "  waiting on Javier's own yes to download). The low kick, knee, hook, uppercut, elbow and push kick have no"
    echo "  recorded counterpart either; they follow the posture sheet."
    echo
    echo "## Measured on the drawing"
    echo "$MEASURE" | grep -v '^len:'
    echo "$WHOLE"
    echo
    echo "## What changed since the last push"
    git -C "$ROOT" log --format='- %h %s' origin/main..HEAD 2>/dev/null
    echo
    echo "## Play it"
    echo '`~/Programs/cyberbrawling-my-way-to-my-love/scripts/play.sh`'
  } > "$OUT/build.md"
  rm -rf "$OUT/moves"
  echo "== 5. the builds folder"
  # Javier, 2026-11-02 20:14 (through the assistant team): "It is only one report a day, not so many." Builds live in
  # their own folder outside the repo, where the assistant team reads them; the shelf gets one plain report a day.
  BUILDS="${CYBERBRAWLING_BUILDS:-$HOME/Documents/Cyberbrawling/builds}"
  mkdir -p "$BUILDS/$NAME" && cp -r "$OUT"/demo.mp4 "$OUT"/moves.png "$OUT"/sheet.png "$OUT"/closeups.png "$OUT"/closeups "$OUT"/strips "$OUT"/clips "$OUT"/frames "$OUT"/trials "$OUT"/build.md "$BUILDS/$NAME/" \
    && { [ "$SBS" != yes ] || cp -r "$OUT"/reference "$BUILDS/$NAME/"; } \
    || fail "could not copy to the builds folder"
  echo "in the builds folder: $BUILDS/$NAME"
  SHELF="${REVIEW_SHELF:-$(head -n 1 "$ROOT/.review-shelf" 2>/dev/null)}"
  if [ -n "$SHELF" ] && [ -d "$SHELF" ]; then
    REPORT="$SHELF/cyberbrawling-report-$(date +%Y-%m-%d).md"
    if [ -f "$REPORT" ]; then
      echo "today's report for Javier: $REPORT (add this build to it)"
    else
      echo "today's report for Javier NOT WRITTEN YET: $REPORT"
    fi
    # the newest report's facts (between <!-- facts --> and <!-- /facts -->) come from the machine, never typed by hand
    # (2026-11-02 night: three wrong numbers typed into the report in one evening)
    NEWEST="$(ls "$SHELF"/cyberbrawling-report-*.md 2>/dev/null | sort | tail -n 1)"
    if [ -n "$NEWEST" ] && grep -q '<!-- facts -->' "$NEWEST"; then
      WAITING="$(git -C "$ROOT" rev-list --count origin/main..HEAD 2>/dev/null)"
      FACTS="$(printf '%s\n' "- Newest build: \`~/Documents/Cyberbrawling/builds/$NAME/\`" \
        "- Tests: $TESTS" "- Changes saved here and not on GitHub yet: $WAITING")"
      python3 - "$NEWEST" "$FACTS" <<'PY' || fail "could not refresh the report's facts"
import re, sys
path, facts = sys.argv[1], sys.argv[2]
text = open(path).read()
new = re.sub(r"<!-- facts -->.*?<!-- /facts -->", lambda m: "<!-- facts -->\n" + facts + "\n<!-- /facts -->", text, flags=re.S)
open(path, "w").write(new)
PY
      echo "facts refreshed in $NEWEST"
    fi
  else
    echo "no shelf set (\$REVIEW_SHELF or .review-shelf): no daily report to check"
  fi
  echo "OK build $NAME"
) > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
