#!/usr/bin/env bash
# picker_popup.sh — Da Vinci Console popup wrapper
#
# Sizes the tmux display-popup to fit the picker's actual content (rows and
# width) instead of a fixed percentage, so it hugs the list regardless of how
# many sessions/windows are open. This is what makes it "just work" when shared.
#
# Wire it up with:
#   bind-key s run-shell "~/.config/tmux/picker_popup.sh"
set -euo pipefail

# The picker to run inside the popup (override with DA_VINCI_PICKER).
PICKER="${DA_VINCI_PICKER:-$HOME/.config/tmux/sesh_picker.sh}"
if [[ ! -x "$PICKER" ]]; then
    PICKER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sesh_picker.sh"
fi

# ---- height: rows of list content + a little header/search margin --------
rows=$( "$PICKER" --list 2>/dev/null | wc -l | tr -d ' ' )
rows=$(( rows + 5 ))
client_h=$( tmux display-message -p '#{client_height}' 2>/dev/null || echo 40 )
max_h=$(( client_h * 85 / 100 ))
(( rows > max_h )) && rows=$max_h
(( rows < 14 )) && rows=14

# ---- width: longest visible line (ANSI stripped), clamped ----------------
longest=$( "$PICKER" --list 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | awk '{ if (length > m) m = length } END { print m+0 }' )
(( longest < 1 )) && longest=60
width=$(( longest + 6 ))
client_w=$( tmux display-message -p '#{client_width}' 2>/dev/null || echo 120 )
max_w=$(( client_w * 82 / 100 ))
(( width > max_w )) && width=$max_w
(( width < 50 )) && width=50

tmux display-popup -B -x C -y C -w "$width" -h "$rows" -s "bg=#0a0a0a" -E "$PICKER"
