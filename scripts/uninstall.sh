#!/usr/bin/env bash
# Take the game away again: only the files scripts/install.sh put there (its list, installed.txt). Your saved feel-lab
# settings stay (Godot keeps them in ~/.local/share/godot/app_userdata/). Javier & Claude.
# Logs to logs/uninstall-<stamp>.log (+ -latest), ends with OK. Usage: scripts/uninstall.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$ROOT/logs/uninstall-$STAMP.log"
mkdir -p "$ROOT/logs"
ln -sfn "$(basename "$LOG")" "$ROOT/logs/uninstall-latest.log"
LIST="$HOME/.local/share/cyberbrawling/installed.txt"
{
  echo
  echo "  Cyberbrawling my way to my love!  ·  uninstall"
  echo
  [ -f "$LIST" ] || { echo "  Nothing to do: it isn't installed (no $LIST)."; echo "OK nothing installed"; exit 0; }
  while IFS= read -r f; do
    case "$f" in
      "$HOME"/.local/*) [ -e "$f" ] && rm -f -- "$f" && echo "  removed $f" ;;
      *) echo "  skipped $f (not under ~/.local)" ;;
    esac
  done < "$LIST"
  rmdir "$HOME/.local/share/cyberbrawling" 2>/dev/null
  command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
  echo
  echo "  Done.   Log: $LOG"
  echo "OK uninstalled"
} > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
