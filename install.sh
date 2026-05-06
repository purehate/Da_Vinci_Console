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

echo "✓ Installed: $DEST/$INSTALLED"
echo ""

# ── tmux.conf snippet ─────────────────────────────────────────────────────────
echo "── tmux.conf ────────────────────────────────────────────────"
echo "Add this to your tmux.conf (or see extras/tmux.conf):"
echo ""
echo "  bind s display-popup -B -x C -y C -w 72% -h 72% -s \"bg=default\" -E \"$DEST/$INSTALLED\""
echo ""

# ── Dependency check ─────────────────────────────────────────────────────────
echo "── Dependencies ─────────────────────────────────────────────"
for cmd in tmux fzf; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  ✓ $cmd"
    else
        echo "  ✗ $cmd  (not found)"
    fi
done
echo ""
