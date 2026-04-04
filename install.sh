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

# ── Detect shell and rc file ─────────────────────────────────────────────────
SHELL_NAME=$(basename "${SHELL:-bash}")
case "$SHELL_NAME" in
    zsh)  RC="$HOME/.zshrc" ;  ENV_EXPORT='export SESH_REPO_DIRS="$HOME/dev:$HOME/projects"' ;;
    fish) RC="$HOME/.config/fish/config.fish" ; ENV_EXPORT='set -gx SESH_REPO_DIRS "$HOME/dev:$HOME/projects"' ;;
    *)    RC="$HOME/.bashrc" ; ENV_EXPORT='export SESH_REPO_DIRS="$HOME/dev:$HOME/projects"' ;;
esac

# ── tmux.conf snippet ─────────────────────────────────────────────────────────
echo "── tmux.conf ────────────────────────────────────────────────"
echo "Add this to your tmux.conf (or see extras/tmux.conf):"
echo ""
echo "  bind s display-popup -B -x C -y C -w 72% -h 72% -s \"bg=default\" -E \"$DEST/$INSTALLED\""
echo ""

# ── Shell env var (optional) ──────────────────────────────────────────────────
echo "── Optional: pin your repo dirs ($SHELL_NAME) ───────────────────────────"
echo "Without SESH_REPO_DIRS set, the picker seeds workspaces from tmux, cache, current dir, sesh, and zoxide."
echo "To use specific directories instead, add to $RC:"
echo ""
echo "  $ENV_EXPORT"
echo ""
echo "Separate multiple paths with colons. Tilde is supported."
echo ""

# ── Dependency check ─────────────────────────────────────────────────────────
echo "── Dependencies ─────────────────────────────────────────────"
for cmd in tmux fzf; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  ✓ $cmd"
    else
        echo "  ✗ $cmd  (not found — install it for full functionality)"
    fi
done
echo ""
echo "Optional: sesh, zoxide"
command -v sesh >/dev/null 2>&1 && echo "  ✓ sesh" || echo "  - sesh  (not installed)"
command -v zoxide >/dev/null 2>&1 && echo "  ✓ zoxide" || echo "  - zoxide  (not installed)"
echo ""
