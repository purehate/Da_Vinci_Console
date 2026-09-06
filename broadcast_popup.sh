#!/usr/bin/env bash
# broadcast_popup.sh — Da Vinci Console broadcast popup wrapper
#
# Opens the multi-select pane broadcaster in a tmux display-popup. Pick panes
# (Tab toggles, Ctrl-A all), then a command with history; it's sent + Enter to
# every selected pane.
#
# Wire it up with:
#   bind-key B run-shell "~/.config/tmux/broadcast_popup.sh"
set -euo pipefail

PICKER="${DA_VINCI_PICKER:-$HOME/.config/tmux/sesh_picker.sh}"
if [[ ! -x "$PICKER" ]]; then
    PICKER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sesh_picker.sh"
fi

client_h=$( tmux display-message -p '#{client_height}' 2>/dev/null || echo 40 )
rows=$(( client_h * 70 / 100 ))
(( rows < 18 )) && rows=18

client_w=$( tmux display-message -p '#{client_width}' 2>/dev/null || echo 120 )
width=$(( client_w * 70 / 100 ))
(( width < 60 )) && width=60

tmux display-popup -B -x C -y C -w "$width" -h "$rows" -s "bg=#0a0a0a" \
    -E "$PICKER --broadcast"
