#!/usr/bin/env bash
# Export the game for Linux and prove the exported program works (Stage 3: a Linux build Javier can install).
# Javier & Claude. Tests first (red = no export); then Godot's Linux export into export/linux/ (git-ignored); then a
# smoke test: the exported program plays level 1 by itself with no window (--bot) and must say it was won.
# Fenced (capped.sh) and timed like every Godot run. Logs to logs/export-<stamp>.log (+ -latest), last line OK.
# Usage: scripts/export.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$ROOT/logs/export-$STAMP.log"
mkdir -p "$ROOT/logs" "$ROOT/export/linux"
ln -sfn "$(basename "$LOG")" "$ROOT/logs/export-latest.log"
BIN="$ROOT/export/linux/cyberbrawling.x86_64"
{
  echo "Cyberbrawling my way to my love! — Linux export — $STAMP (commit $(git -C "$ROOT" rev-parse --short HEAD))"
  echo "== tests"
  "$ROOT/scripts/test.sh" > /dev/null 2>&1 || { tail -n 3 "$ROOT/logs/test-latest.log"; echo "FAILED tests are red: no export"; exit 1; }
  tail -n 1 "$ROOT/logs/test-latest.log"
  echo "== export"
  rm -f "$BIN"
  timeout 600 "$ROOT/scripts/capped.sh" godot --headless --path "$ROOT/game" --export-release "Linux" 2>&1 \
    | grep -v '^Godot Engine' | grep -iE 'error|warn' | head -20
  [ -x "$BIN" ] || { echo "FAILED no program at $BIN"; exit 1; }
  ls -la "$BIN"
  echo "== smoke test: the exported program plays level 1 by itself"
  OUT="$(timeout 600 "$ROOT/scripts/capped.sh" "$BIN" --headless -- --bot 2>&1)"
  echo "$OUT" | grep -E 'SCRIPT ERROR|LEVEL ' | head -5
  if echo "$OUT" | grep -q 'SCRIPT ERROR'; then echo "FAILED the exported program has a script error"; exit 1; fi
  if echo "$OUT" | grep -q 'dumped core'; then echo "FAILED the exported program crashed as it quit"; exit 1; fi
  echo "$OUT" | grep -q '^LEVEL WON' || { echo "FAILED the exported program didn't finish level 1"; exit 1; }
  echo "OK exported: $BIN ($(du -h "$BIN" | cut -f1)), plays level 1 through"
} > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
