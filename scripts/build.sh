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
  # the hero beside the recordings he was measured from (D-30); the recordings live outside the repo, so a machine
  # without them builds without these pictures and the note says so
  SBS="no"
  if [ -d "$HOME/Programs/cyberbrawling-reference/cmu" ]; then
    python3 "$ROOT/scripts/reference_strips.py" "$REC/frames" "$OUT/marks.txt" "$OUT" $MOMENTS || fail "could not draw the side-by-sides"
    SBS="yes"
  fi
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
    echo "  the hit, or from the first frame of a walk or run cycle; half speed is the same frames)"
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
    echo "- Moves in the demo: $(echo $MOMENTS | sed 's/:[0-9:]*//g')"
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
  mkdir -p "$BUILDS/$NAME" && cp -r "$OUT"/demo.mp4 "$OUT"/moves.png "$OUT"/sheet.png "$OUT"/closeups.png "$OUT"/closeups "$OUT"/strips "$OUT"/clips "$OUT"/frames "$OUT"/build.md "$BUILDS/$NAME/" \
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
  else
    echo "no shelf set (\$REVIEW_SHELF or .review-shelf): no daily report to check"
  fi
  echo "OK build $NAME"
) > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
