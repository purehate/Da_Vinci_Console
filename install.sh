#!/usr/bin/env bash
# install.sh — install da-vinci-console to ~/.config/tmux/
set -euo pipefail

DEST="${1:-$HOME/.config/tmux}"
SRC="da-vinci-console.sh"
INSTALLED="sesh_picker.sh"

if [[ ! -f "$SRC" ]]; then
    echo "Error: run this from the repo root (da-vinci-console.sh not found)" >&2
    exit 1
fi

mkdir -p "$DEST"
cp "$SRC" "$DEST/$INSTALLED"
chmod +x "$DEST/$INSTALLED"

echo "Installed: $DEST/$INSTALLED"
echo ""
echo "Add to your tmux.conf:"
echo "  bind s run-shell \"bash $DEST/$INSTALLED\""
echo ""
echo "Or see extras/tmux.conf for the full snippet."
