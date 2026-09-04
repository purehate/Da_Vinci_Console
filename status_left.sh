#!/usr/bin/env bash
# status_left.sh - styled status-left: prefix-aware session + hostname.
#
# Renders the session name as a powerline block; when you press <prefix> the
# block turns blue with a keyboard glyph so you know a prefix command is next.
# Also appends a hostname block. Used from status-left via:
#   set -g status-left "#(bash ~/.config/tmux/status_left.sh)"
set -u

ansi_fg() { local h="${1#\#}"; printf '\033[38;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; }
ansi_bg() { local h="${1#\#}"; printf '\033[48;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; }

GREEN="$(ansi_fg 14E21A)"; GREEN_BG="$(ansi_bg 14E21A)"
BLUE="$(ansi_fg 1C47FF)";  BLUE_BG="$(ansi_bg 1C47FF)"
BLACK="$(ansi_fg 000000)"
RESET=$'\033[0m'; BOLD=$'\033[1m'
L=$'\ue0b6'; R=$'\ue0b4'   # powerline wedges (right/left-pointing)
KB=$'\u2328'             # keyboard glyph for the prefix state

SESS="$(tmux display-message -p '#S' 2>/dev/null)"
PREFIX="$(tmux display-message -p '#{client_prefix}' 2>/dev/null)"
HOST="$(hostname -s 2>/dev/null)"

out=""
if [[ "$PREFIX" == "1" ]]; then
    out+="${BLUE}${L}${RESET}${BLACK}${BLUE_BG}${BOLD} $KB ${SESS} ${RESET}${BLUE}${R}${RESET}"
else
    out+="${GREEN}${L}${RESET}${BLACK}${GREEN_BG}${BOLD} ${SESS} ${RESET}${GREEN}${R}${RESET}"
fi
out+=" ${BLUE}${L}${RESET}${BLACK}${BLUE_BG}${BOLD} ${HOST} ${RESET}${BLUE}${R}${RESET}"

printf '%s\n' "$out"
