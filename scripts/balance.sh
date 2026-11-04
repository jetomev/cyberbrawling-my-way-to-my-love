#!/usr/bin/env bash
# The bot's balance numbers for the team (game/tools/balance.gd): health left after each screen, where lives were lost,
# health taken by enemy type, for the levels named. Javier & Claude. Fenced and timed like every Godot run.
# Usage: scripts/balance.sh OUT.md [level3 level4 ...]   (default: level 3 and the drafts, levels 4 to 10)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1"; shift
LEVELS=("$@")
[ ${#LEVELS[@]} -eq 0 ] && LEVELS=(level3 level4 level5 level6 level7 level8 level9 level10)
mkdir -p "$(dirname "$OUT")"
timeout 1800 "$ROOT/scripts/capped.sh" godot --headless --path "$ROOT/game" -s tools/balance.gd -- "$(realpath -m "$OUT")" "${LEVELS[@]}" 2>&1 \
  | grep -v '^Godot Engine' > "$OUT.log"
if grep -q 'SCRIPT ERROR' "$OUT.log"; then cat "$OUT.log"; echo "FAILED the balance run has a script error"; exit 1; fi
grep -q '^BALANCE written' "$OUT.log" || { cat "$OUT.log"; echo "FAILED the balance run didn't finish"; exit 1; }
rm -f "$OUT.log"
echo "OK balance numbers: $OUT"
