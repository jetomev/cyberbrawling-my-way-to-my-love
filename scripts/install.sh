#!/usr/bin/env bash
# Install the game for this user only (no sudo): the exported program, a "cyberbrawling" command and a menu entry.
# Javier & Claude. Run scripts/export.sh first (it makes export/linux/cyberbrawling.x86_64 and checks it plays).
# Everything goes under ~/.local; scripts/uninstall.sh takes it all away again (it removes only what this put there,
# listed in ~/.local/share/cyberbrawling/installed.txt). Logs to logs/install-<stamp>.log (+ -latest), ends with OK.
# Usage: scripts/install.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$ROOT/logs/install-$STAMP.log"
mkdir -p "$ROOT/logs"
ln -sfn "$(basename "$LOG")" "$ROOT/logs/install-latest.log"
BIN="$ROOT/export/linux/cyberbrawling.x86_64"
HOME_DIR="$HOME/.local/share/cyberbrawling"
CMD="$HOME/.local/bin/cyberbrawling"
DESKTOP="$HOME/.local/share/applications/cyberbrawling.desktop"
ICON="$HOME/.local/share/icons/hicolor/256x256/apps/cyberbrawling.png"
{
  echo
  echo "  ============================================"
  echo "   Cyberbrawling my way to my love!  ·  install"
  echo "  ============================================"
  echo
  [ -x "$BIN" ] || { echo "  FAILED no exported game at $BIN: run scripts/export.sh first"; exit 1; }
  mkdir -p "$HOME_DIR" "$(dirname "$CMD")" "$(dirname "$DESKTOP")" "$(dirname "$ICON")"
  install -m 755 "$BIN" "$HOME_DIR/cyberbrawling.x86_64"
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$HOME_DIR/cyberbrawling.x86_64" > "$CMD"
  chmod 755 "$CMD"
  install -m 644 "$ROOT/packaging/cyberbrawling.desktop" "$DESKTOP"
  rsvg-convert -w 256 -h 256 -o "$ICON" "$ROOT/packaging/icon-placeholder.svg"
  printf '%s\n' "$HOME_DIR/cyberbrawling.x86_64" "$CMD" "$DESKTOP" "$ICON" "$HOME_DIR/installed.txt" > "$HOME_DIR/installed.txt"
  command -v update-desktop-database >/dev/null && update-desktop-database "$(dirname "$DESKTOP")" 2>/dev/null
  echo "  The game:      $HOME_DIR/cyberbrawling.x86_64 ($(du -h "$HOME_DIR/cyberbrawling.x86_64" | cut -f1))"
  echo "  The command:   cyberbrawling"
  echo "  The menu:      Cyberbrawling my way to my love! (Games)"
  echo
  echo "  Done. Have fun, and thanks for playing.   Log: $LOG"
  echo "OK installed"
} > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
