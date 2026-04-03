#!/usr/bin/env bash
# install.sh — install da-vinci-console to ~/.config/tmux/
set -euo pipefail

DEST="${1:-$HOME/.config/tmux}"
SCRIPT="da-vinci-console.sh"

if [[ ! -f "$SCRIPT" ]]; then
    echo "Error: run this from the repo root (da-vinci-console.sh not found)" >&2
    exit 1
fi

mkdir -p "$DEST"
cp "$SCRIPT" "$DEST/$SCRIPT"
chmod +x "$DEST/$SCRIPT"

echo "Installed: $DEST/$SCRIPT"
echo ""
echo "Add to your tmux.conf:"
echo "  bind s run-shell \"bash $DEST/$SCRIPT\""
echo ""
echo "Or see extras/tmux.conf for the full snippet."
