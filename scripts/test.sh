#!/usr/bin/env bash
# Run the game's headless test suite, fenced (scripts/capped.sh) and timed. Javier & Claude.
# Logs to logs/test-<stamp>.log with a logs/test-latest.log link; the last line is "OK <n> tests (<m> checks)".
# The test count never drops silently: game/tests/FLOOR holds the lowest count allowed. Fewer tests fail the run;
# more tests raise FLOOR (commit it with them). A real removal is a decision: lower FLOOR by hand and say why.
# Usage: scripts/test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ROOT/logs"
LOG="$ROOT/logs/test-$STAMP.log"
FLOOR_FILE="$ROOT/game/tests/FLOOR"
{
  echo "Cyberbrawling my way to my love! — tests — $STAMP"
  echo "godot $(godot --version 2>/dev/null)"
  # first run in a fresh checkout (a new worktree too): let Godot index the project first (output not kept)
  if [ ! -d "$ROOT/game/.godot" ]; then
    timeout 300 "$ROOT/scripts/capped.sh" godot --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
  fi
  timeout 300 "$ROOT/scripts/capped.sh" godot --headless --path "$ROOT/game" -s res://tests/run_tests.gd 2>&1 \
    | grep -v '^Godot Engine'
} > "$LOG" 2>&1
STATUS=0
LAST="$(tail -n 1 "$LOG")"
if [[ "$LAST" =~ ^OK\ ([0-9]+)\ tests ]]; then
  COUNT="${BASH_REMATCH[1]}"
  FLOOR="$(cat "$FLOOR_FILE" 2>/dev/null || echo 0)"
  if (( COUNT < FLOOR )); then
    echo "FAILED test count dropped: $COUNT tests, the floor is $FLOOR (game/tests/FLOOR)" >> "$LOG"
    STATUS=1
  elif (( COUNT > FLOOR )); then
    echo "$COUNT" > "$FLOOR_FILE"
    echo "floor raised: $FLOOR -> $COUNT tests (commit game/tests/FLOOR)" >> "$LOG"
    echo "OK $COUNT tests" >> "$LOG"
  fi
else
  STATUS=1
fi
ln -sfn "$(basename "$LOG")" "$ROOT/logs/test-latest.log"
cat "$LOG"
echo
echo "log: $LOG"
exit $STATUS
