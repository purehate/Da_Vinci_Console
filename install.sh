#!/usr/bin/env bash
# install.sh — install da-vinci-console + agents to ~/.config/tmux/
set -euo pipefail

DEST="${1:-$HOME/.config/tmux}"
SRC="da-vinci-console.sh"
INSTALLED="sesh_picker.sh"
WRAPPER="picker_popup.sh"

# Hard dependency check: the whole thing is useless without these.
for cmd in tmux fzf; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command '$cmd' not found in PATH." >&2
        echo "Install it first, then re-run ./install.sh" >&2
        exit 1
    fi
done

if [[ ! -f "$SRC" ]]; then
    echo "Error: run this from the repo root (da-vinci-console.sh not found)" >&2
    exit 1
fi

mkdir -p "$DEST"
cp "$SRC" "$DEST/$INSTALLED"
chmod +x "$DEST/$INSTALLED"
echo "✓ Installed: $DEST/$INSTALLED"

# Dynamic-size popup wrapper (sizes display-popup to fit the list)
cp "$WRAPPER" "$DEST/$WRAPPER"
chmod +x "$DEST/$WRAPPER"
echo "✓ Installed: $DEST/$WRAPPER"

# ── Agents module (herdr-style detection) ──────────────────────────────────
# window_agent.sh  -> annotates each window pill in the status line
# agents_state.sh  -> feeds the picker's agents header + window tags
# lib.sh           -> shared watch-list + detection
# jump.sh          -> <prefix>+a fzf picker (optional)
if [[ -d "agents" ]]; then
    mkdir -p "$DEST/agents"
    cp agents/*.sh "$DEST/agents/"
    chmod +x "$DEST"/agents/*.sh
    echo "✓ Installed: $DEST/agents/ (window_agent.sh, agents_state.sh, lib.sh, jump.sh)"
fi
echo ""

# ── tmux.conf ───────────────────────────────────────────────────────────────
echo "── tmux.conf ────────────────────────────────────────────────"
echo "The repo ships a full shareable config in extras/tmux.conf that wires"
echo "the agent window pills + the picker. Install it with (back up first!):"
echo ""
echo "  cp extras/tmux.conf $DEST/tmux.conf   # then <prefix>+r to reload"
echo ""
echo "Or just add the picker binding to your existing tmux.conf:"
echo ""
echo "  bind-key s run-shell \"$DEST/$WRAPPER\""
echo ""
echo "The wrapper sizes the popup to fit the list (dynamic height+width)."
echo ""

# ── Dependency check ────────────────────────────────────────────────────────
echo "── Dependencies ─────────────────────────────────────────────"
for cmd in tmux fzf; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  ✓ $cmd"
    else
        echo "  ✗ $cmd  (not found)"
    fi
done
echo ""
