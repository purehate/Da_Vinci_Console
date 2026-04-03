#!/usr/bin/env bash
# da-vinci-console.sh — tmux session + window picker
# https://github.com/smiley/Da_Vinci_Console
set -u

# ── Theme (override with env vars) ───────────────────────────────────────────
DVC_COLOR_ACTIVE="${DVC_COLOR_ACTIVE:-#14E21A}"
DVC_COLOR_BORDER="${DVC_COLOR_BORDER:-#24b030}"
DVC_COLOR_DIM="${DVC_COLOR_DIM:-#333333}"
DVC_TITLE="${DVC_TITLE:- 󰔎 Da Vinci Console }"

# ── Dependencies ──────────────────────────────────────────────────────────────
SESH="sesh"
command -v sesh >/dev/null 2>&1 || SESH="$HOME/go/bin/sesh"
command -v "$SESH" >/dev/null 2>&1 || { echo "da-vinci-console: sesh not found" >&2; exit 1; }
command -v fzf >/dev/null 2>&1 || { echo "da-vinci-console: fzf not found" >&2; exit 1; }
command -v tmux >/dev/null 2>&1 || { echo "da-vinci-console: tmux not found" >&2; exit 1; }

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# ── Colors (derived from theme) ───────────────────────────────────────────────
_hex_to_ansi() {
    local hex="${1#\#}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    printf "\033[38;2;%d;%d;%dm" "$r" "$g" "$b"
}

C_GREEN="$(_hex_to_ansi "$DVC_COLOR_ACTIVE")"
C_GREY="\033[38;2;123;132;150m"
C_DIM="\033[38;2;51;51;51m"
C_WHITE="\033[38;2;220;220;220m"
C_BRIGHT="\033[38;2;255;255;255m"
C_RESET="\033[0m"

FZF_COLORS="border:${DVC_COLOR_BORDER},fg:#b3b3b3,hl:${DVC_COLOR_ACTIVE},fg+:#e6e6e6,bg+:-1,hl+:${DVC_COLOR_ACTIVE},pointer:${DVC_COLOR_ACTIVE},header:#7b8496,marker:${DVC_COLOR_ACTIVE},spinner:${DVC_COLOR_ACTIVE},prompt:${DVC_COLOR_ACTIVE},gutter:-1,label:${DVC_COLOR_BORDER},bg:-1,preview-bg:-1"

SEP=$'\t|\t'

# ── Icons ─────────────────────────────────────────────────────────────────────
icon_for() {
    local n="${1,,}"; n="${n##*/}"
    case "$n" in
        claude*)              echo "󰊠" ;;
        codex*|node)          echo "󰆍" ;;
        lazygit|lg|git)       echo "" ;;
        lazydocker|ld|docker) echo "" ;;
        yazi)                 echo "󰙅" ;;
        nvim|vim|vi)          echo "" ;;
        btop|htop|top)        echo "" ;;
        ssh*)                 echo "󰣀" ;;
        python*|py|ipython)   echo "" ;;
        node*|npm|pnpm)       echo "" ;;
        go|golang)            echo "" ;;
        rust|cargo)           echo "" ;;
        zsh|bash|fish|shell*) echo "" ;;
        qa|dev|staging)       echo "󰑮" ;;
        *)                    echo "" ;;
    esac
}

short_path() { echo "${1/#$HOME/~}"; }

# ── List builders ─────────────────────────────────────────────────────────────
build_sessions() {
    tmux list-sessions -F "#{session_name}|#{session_windows}|#{?session_attached,1,0}" 2>/dev/null \
      | sort -t'|' -k3,3r -k1,1 \
      | while IFS='|' read -r sname wins att; do
            local icon wlabel att_mark
            icon=$(icon_for "$sname")
            wlabel=$([[ "$wins" == "1" ]] && echo "1 window" || echo "${wins} windows")
            att_mark=$([[ "$att" == "1" ]] && echo " ${C_GREEN}●${C_RESET}" || echo "")
            printf "${C_BRIGHT}${icon:+$icon }${sname}${C_RESET}  ${C_GREY}${wlabel}${C_RESET}${att_mark}${SEP}session:${sname}\n"

            tmux list-windows -t "$sname" \
              -F "#{window_index}|#{window_name}|#{pane_current_command}|#{window_active}|#{pane_current_path}" 2>/dev/null \
              | while IFS='|' read -r widx wname wcmd wactive wpath; do
                    local wicon pshort mark
                    wicon=$(icon_for "$wcmd"); [[ -z "$wicon" ]] && wicon=$(icon_for "$wname")
                    pshort=$(short_path "$wpath")
                    mark=$([[ "$wactive" == "1" ]] && echo " ${C_GREEN}✦${C_RESET}" || echo "")
                    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE}${wicon:+$wicon }${wname}${C_RESET}  ${C_GREY}${sname}:${widx}  ${wcmd}  ${pshort}${C_RESET}${mark}${SEP}window:${sname}:${widx}\n"
                done
        done
}

build_windows() {
    tmux list-windows -a \
      -F "#{session_name}|#{window_index}|#{window_name}|#{pane_current_command}|#{window_active}|#{pane_current_path}" 2>/dev/null \
      | sort -t'|' -k1,1 -k2,2n \
      | while IFS='|' read -r sname widx wname wcmd wactive wpath; do
            local wicon pshort mark
            wicon=$(icon_for "$wcmd"); [[ -z "$wicon" ]] && wicon=$(icon_for "$wname")
            pshort=$(short_path "$wpath")
            mark=$([[ "$wactive" == "1" ]] && echo " ${C_GREEN}✦${C_RESET}" || echo "")
            printf "${C_WHITE}${wicon:+$wicon }${wname}${C_RESET}  ${C_GREY}${sname}:${widx}  ${wcmd}  ${pshort}${C_RESET}${mark}${SEP}window:${sname}:${widx}\n"
        done
}

build_jump() {
    "$SESH" list -c -z 2>/dev/null | while IFS= read -r name; do
        local icon pshort
        icon=$(icon_for "$(basename "$name")")
        pshort=$(short_path "$name")
        printf "${C_WHITE}${icon:+$icon }${pshort}${C_RESET}${SEP}sesh:${name}\n"
    done
}

# ── Reload targets (called by fzf binds) ──────────────────────────────────────
case "${1:-}" in
    --list-sessions) build_sessions; exit 0 ;;
    --list-windows)  build_windows;  exit 0 ;;
    --list-jump)     build_jump;     exit 0 ;;
esac

# ── Preview ({-1} = last field = metadata: "session:NAME" / "window:S:IDX" / "sesh:PATH") ──
# Uses printf to avoid color code expansion issues inside heredoc
DIM_COLOR="${DVC_COLOR_DIM}"
ACTIVE_COLOR="${DVC_COLOR_ACTIVE}"

read -r -d '' PREVIEW_CMD <<PREVIEW
target={-1}
type="\${target%%:*}"
rest="\${target#*:}"
if [ "\$type" = "session" ]; then
    wins=\$(tmux list-windows -t "\$rest" \\
      -F "  #{window_index}. #{window_name}  (#{pane_current_command})#{?window_active,  ✦,}" 2>/dev/null)
    printf "\033[38;2;${ACTIVE_COLOR#\#:0:2}m%s\033[0m\n\n" "\$rest" 2>/dev/null || printf "%s\n\n" "\$rest"
    printf "%s\n" "\$wins"
    printf "\n\033[38;2;51;51;51m─────────────────────────────\033[0m\n"
    widx=\$(tmux display-message -p -t "\$rest" "#{window_index}" 2>/dev/null)
    [ -n "\$widx" ] && tmux capture-pane -p -t "\${rest}:\${widx}" -S -20 2>/dev/null \\
      || printf "preview unavailable\n"
elif [ "\$type" = "window" ]; then
    sess="\${rest%%:*}"
    widx="\${rest#*:}"
    wins=\$(tmux list-windows -t "\$sess" \\
      -F "  #{window_index}. #{window_name}  (#{pane_current_command})#{?window_active,  ✦,}" 2>/dev/null)
    printf "%s\n\n" "\${sess}:\${widx}"
    printf "%s\n" "\$wins"
    printf "\n\033[38;2;51;51;51m─────────────────────────────\033[0m\n"
    tmux capture-pane -p -t "\${sess}:\${widx}" -S -20 2>/dev/null \\
      || printf "preview unavailable\n"
elif [ "\$type" = "sesh" ]; then
    sesh preview "\$rest" 2>/dev/null || printf "no preview available\n"
fi
PREVIEW

HEADER="  Enter switch  •  ^J jump  •  ^W windows  •  ^S sessions  •  ^D kill  •  ^/ preview  •  alt-↑↓ scroll"

selected=$(build_sessions | fzf \
    --ansi \
    --layout=reverse \
    --height=100% \
    --no-sort \
    --pointer='▶' \
    --prompt='  ' \
    --color="$FZF_COLORS" \
    --delimiter=$'\t|\t' \
    --with-nth=1 \
    --border=rounded \
    --border-label="$DVC_TITLE" \
    --border-label-pos=2 \
    --input-border=rounded \
    --input-label='  Search ' \
    --input-label-pos=2 \
    --list-border=rounded \
    --list-label='  Sessions ' \
    --list-label-pos=2 \
    --preview-border=rounded \
    --preview-label='  Preview ' \
    --preview-label-pos=2 \
    --padding=0,1 \
    --info=inline-right \
    --header-first \
    --header "$HEADER" \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-/:toggle-preview' \
    --bind 'alt-up:preview-up' \
    --bind 'alt-down:preview-down' \
    --bind "ctrl-j:reload(bash '$SELF' --list-jump)+change-list-label(  Jump )" \
    --bind "ctrl-w:reload(bash '$SELF' --list-windows)+change-list-label(  Windows )" \
    --bind "ctrl-s:reload(bash '$SELF' --list-sessions)+change-list-label(  Sessions )" \
    --bind "ctrl-d:execute-silent(bash -c 't={-1}; t=\"\${t#*:}\"; tmux kill-session -t \"\${t%%:*}\" 2>/dev/null')+reload(bash '$SELF' --list-sessions)+change-list-label(  Sessions )" \
    --preview-window 'right:50%' \
    --preview "$PREVIEW_CMD" \
)

[[ -z "$selected" ]] && exit 0

target="${selected##*$'\t|\t'}"
type="${target%%:*}"
rest="${target#*:}"

case "$type" in
    window|session) tmux switch-client -t "$rest" ;;
    sesh)           "$SESH" connect "$rest" ;;
    *)              "$SESH" connect "$target" ;;
esac
