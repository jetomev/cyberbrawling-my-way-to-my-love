#!/usr/bin/env bash
# The build step (Javier, 2026-11-01: "have the team critize the build, before I do it"). Javier & Claude.
# 1. the tests (a red test stops the build: no demo of a broken build);
# 2. the recorded demo (scripts/record.sh): a clip and a contact sheet;
# 3. for every move (scripts/closeups.py): a still as it lands, close-ups of the hips, hands and feet, and a timed
#    strip of close-ups through the whole move (the team's asks, 2026-11-02: the hero is small in the demo frame, and
#    they read pictures, not video);
# 4. a short build note; 5. all of it copied to the review shelf, where the assistant team critiques it first.
# The shelf's folder is set outside the repo: $REVIEW_SHELF, or the first line of .review-shelf (git-ignored).
# Without one, the build stays in scratch/build/ and says so. Logs to logs/build-<stamp>.log (+ -latest).
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
  MOMENTS="$(timeout 120 "$ROOT/scripts/capped.sh" godot --headless --path "$ROOT/game" -s res://tools/demo_moments.gd 2>/dev/null | grep -E '^[a-z_]+:[0-9]+:[0-9]+:[0-9]+$')"
  [ -n "$MOMENTS" ] || fail "no moves found in the demo"
  python3 "$ROOT/scripts/closeups.py" "$REC/frames" "$OUT/marks.txt" "$OUT" $MOMENTS || fail "could not cut the stills"
  echo "$(echo $MOMENTS | wc -w) moves: $(echo $MOMENTS | sed 's/:[0-9:]*//g')"
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
    echo "  \`strips/NN-<walk|stroll|run|to_walk|to_fight>-cycle-frames-N.png\` (every frame of the walking, running and stance switches)"
    echo "- Moves in the demo: $(echo $MOMENTS | sed 's/:[0-9:]*//g')"
    echo
    echo "## What changed since the last push"
    git -C "$ROOT" log --format='- %h %s' origin/main..HEAD 2>/dev/null
    echo
    echo "## Play it"
    echo '`~/Programs/cyberbrawling-my-way-to-my-love/scripts/play.sh`'
  } > "$OUT/build.md"
  rm -rf "$OUT/moves"
  echo "== 5. the review shelf"
  SHELF="${REVIEW_SHELF:-$(head -n 1 "$ROOT/.review-shelf" 2>/dev/null)}"
  if [ -n "$SHELF" ] && [ -d "$SHELF" ]; then
    mkdir -p "$SHELF/$NAME" && cp -r "$OUT"/demo.mp4 "$OUT"/moves.png "$OUT"/sheet.png "$OUT"/closeups.png "$OUT"/closeups "$OUT"/strips "$OUT"/build.md "$SHELF/$NAME/" \
      || fail "could not copy to the shelf"
    echo "on the shelf: $SHELF/$NAME"
  else
    echo "no review shelf set (\$REVIEW_SHELF or .review-shelf): the build stays in $OUT"
  fi
  echo "OK build $NAME"
) > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
