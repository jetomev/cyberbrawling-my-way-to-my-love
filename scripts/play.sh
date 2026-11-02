#!/usr/bin/env bash
# Play the game in a window, fenced (capped.sh) and with a 4-hour limit. Javier & Claude.
# Logs to logs/play-<stamp>.log (+ play-latest.log); the last line says whether it closed normally.
# Usage: scripts/play.sh [options]     options: --flat (the flat line instead of the shallow street), --demo
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ROOT/logs"
LOG="$ROOT/logs/play-$STAMP.log"
ln -sfn "$(basename "$LOG")" "$ROOT/logs/play-latest.log"
echo "Cyberbrawling my way to my love! — starting ($STAMP), log: $LOG"
if [ ! -d "$ROOT/game/.godot" ]; then
  timeout 300 "$ROOT/scripts/capped.sh" godot --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
fi
timeout 4h "$ROOT/scripts/capped.sh" godot --path "$ROOT/game" -- "$@" > "$LOG" 2>&1
CODE=$?
if [ $CODE -eq 0 ]; then
  echo "OK game closed normally" | tee -a "$LOG"
else
  echo "game exited with code $CODE (see $LOG)" | tee -a "$LOG"
fi
exit $CODE
