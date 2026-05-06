#!/usr/bin/env bash
# da-vinci-console.sh - tmux session/window picker
set -u

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SEP=$'\t|\t'

command -v tmux >/dev/null 2>&1 || { echo "tmux not found" >&2; exit 1; }
command -v fzf >/dev/null 2>&1 || { echo "fzf not found" >&2; exit 1; }

C_GREEN="\033[38;2;20;226;26m"
C_GREY="\033[38;2;123;132;150m"
C_DIM="\033[38;2;51;51;51m"
C_WHITE="\033[38;2;220;220;220m"
C_BRIGHT="\033[38;2;255;255;255m"
C_RED="\033[38;2;255;100;80m"
C_YELLOW="\033[38;2;255;200;60m"
C_BORDER="\033[38;2;36;176;48m"
C_RESET="\033[0m"

FZF_COLORS="border:#24b030,fg:#b3b3b3,hl:#14E21A,fg+:#e6e6e6,bg+:-1,hl+:#14E21A,pointer:#14E21A,header:#7b8496,marker:#14E21A,spinner:#14E21A,prompt:#14E21A,gutter:-1,label:#24b030,bg:-1,preview-bg:-1"

icon_for() {
    local n="${1,,}"
    n="${n##*/}"
    case "$n" in
        claude*)              echo "C" ;;
        codex*)               echo "X" ;;
        nvim|vim|vi)          echo "V" ;;
        lazygit|lg|git)       echo "G" ;;
        lazydocker|ld|docker) echo "D" ;;
        yazi)                 echo "Y" ;;
        btop|htop|top)        echo "T" ;;
        ssh*)                 echo "S" ;;
        zsh|bash|fish|shell*) echo "$" ;;
        *)                    echo "" ;;
    esac
}

short_path() {
    [[ "$1" == "$HOME"* ]] && printf '~%s' "${1#"$HOME"}" || printf '%s' "$1"
}

relative_time() {
    local now diff s="$1"
    now=$(date +%s)
    diff=$(( now - s ))
    if   (( diff < 60 ));    then echo "now"
    elif (( diff < 3600 ));  then echo "$(( diff / 60 ))m"
    elif (( diff < 86400 )); then echo "$(( diff / 3600 ))h"
    else                          echo "$(( diff / 86400 ))d"
    fi
}

repeat_str() {
    local ch="$1" n="$2" out=""
    (( n > 0 )) || { printf ''; return; }
    while (( n > 0 )); do out+="$ch"; (( n-- )); done
    printf '%s' "$out"
}

div_width() {
    local cols="${COLUMNS:-0}"
    [[ "$cols" -lt 1 ]] && cols=$(tput cols 2>/dev/null || echo 120)
    local list_cols=$(( cols / 2 - 6 ))
    (( list_cols < 28 )) && list_cols=28
    (( list_cols > 90 )) && list_cols=90
    printf '%s' "$list_cols"
}

section_sep() {
    local label="$1" w body
    w=$(div_width)
    body=$(repeat_str '-' $(( w - ${#label} - 4 )))
    printf "${C_BORDER}--${C_RESET} ${C_WHITE}%s${C_RESET} ${C_BORDER}%s${C_RESET}${SEP}sep:section\n" "$label" "$body"
}

session_div() {
    local w body
    w=$(div_width)
    body=$(repeat_str '-' $(( w - 3 )))
    printf "${C_DIM}   %s${C_RESET}${SEP}sep:\n" "$body"
}

build_sessions() {
    local first=1 any=0

    while IFS='|' read -r sname wins attached activity; do
        local icon wlabel attached_mark age_str
        any=1
        [[ "$first" == "1" ]] && first=0 || session_div

        icon=$(icon_for "$sname")
        wlabel=$([[ "$wins" == "1" ]] && echo "1 window" || echo "${wins} windows")
        attached_mark=$([[ "$attached" == "1" ]] && echo " ${C_GREEN}*${C_RESET}" || echo "")
        age_str=""
        [[ -n "$activity" && "$activity" != "0" ]] && age_str="  ${C_DIM}$(relative_time "$activity") idle${C_RESET}"

        printf "${C_BRIGHT}%s%s${C_RESET}  ${C_GREY}%s${C_RESET}%b%b${SEP}session:%s\n" \
            "${icon:+$icon }" "$sname" "$wlabel" "$attached_mark" "$age_str" "$sname"

        while IFS='|' read -r widx wname wcmd wactive wpath panes; do
            local wicon pshort active_mark pane_mark
            wicon=$(icon_for "$wcmd")
            [[ -z "$wicon" ]] && wicon=$(icon_for "$wname")
            pshort=$(short_path "$wpath")
            active_mark=$([[ "$wactive" == "1" ]] && echo " ${C_GREEN}+${C_RESET}" || echo "")
            pane_mark=$([[ "$panes" == "1" ]] && echo "" || echo " ${C_YELLOW}${panes}p${C_RESET}")
            printf "  ${C_DIM}|-${C_RESET} ${C_WHITE}%s%s${C_RESET}  ${C_GREY}%s:%s  %s  %s${C_RESET}%b%b${SEP}window:%s:%s\n" \
                "${wicon:+$wicon }" "$wname" "$sname" "$widx" "$wcmd" "$pshort" "$pane_mark" "$active_mark" "$sname" "$widx"
        done < <(tmux list-windows -t "$sname" \
            -F "#{window_index}|#{window_name}|#{pane_current_command}|#{window_active}|#{pane_current_path}|#{window_panes}" 2>/dev/null)
    done < <(tmux list-sessions \
        -F "#{session_name}|#{session_windows}|#{?session_attached,1,0}|#{session_activity}" 2>/dev/null \
        | sort -t'|' -k3,3r -k1,1)

    if [[ "$any" == "0" ]]; then
        printf "${C_DIM}No tmux sessions found. Press Ctrl-N to create one.${C_RESET}${SEP}sep:empty\n"
    fi
}

list_all() {
    section_sep " Tmux Sessions "
    build_sessions
}

new_session() {
    local name="$1"
    [[ -z "$name" ]] && exit 0
    tmux new-session -d -s "$name" 2>/dev/null || true
    tmux switch-client -t "$name" 2>/dev/null
}

kill_target() {
    local raw="$1" type rest
    type="${raw%%:*}"
    rest="${raw#*:}"
    case "$type" in
        session)
            tmux kill-session -t "$rest" 2>/dev/null
            ;;
        window)
            tmux kill-window -t "${rest%%:*}:${rest#*:}" 2>/dev/null
            ;;
    esac
}

rename_target() {
    local raw="$1" type rest sess widx newname
    type="${raw%%:*}"
    rest="${raw#*:}"

    if [[ "$type" == "session" ]]; then
        printf "Rename session '%s': " "$rest"
        read -r newname
        [[ -n "$newname" ]] && tmux rename-session -t "$rest" "$newname" 2>/dev/null
    elif [[ "$type" == "window" ]]; then
        sess="${rest%%:*}"
        widx="${rest#*:}"
        printf "Rename window '%s:%s': " "$sess" "$widx"
        read -r newname
        [[ -n "$newname" ]] && tmux rename-window -t "${sess}:${widx}" "$newname" 2>/dev/null
    fi
}

drill_panes() {
    local raw="$1" rest sess widx pane_count pane_sel pidx
    [[ "$raw" == window:* ]] || exit 0
    rest="${raw#window:}"
    sess="${rest%%:*}"
    widx="${rest#*:}"
    pane_count=$(tmux list-panes -t "${sess}:${widx}" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$pane_count" -le 1 ]]; then
        tmux switch-client -t "${sess}:${widx}" 2>/dev/null
        exit 0
    fi
    pane_sel=$(tmux list-panes -t "${sess}:${widx}" \
        -F "#{pane_index}  #{pane_current_command}  #{pane_current_path}  #{pane_width}x#{pane_height}#{?pane_active,  +,}" 2>/dev/null \
        | fzf --ansi --layout=reverse --height=40% --prompt="Select pane: " \
              --border=rounded --color="$FZF_COLORS" \
              --preview "tmux capture-pane -p -t '${sess}:${widx}.{1}' -S -20 2>/dev/null" \
              --preview-window='right:50%' 2>/dev/null)
    [[ -z "$pane_sel" ]] && exit 0
    pidx="${pane_sel%%  *}"
    pidx="${pidx%% *}"
    tmux select-pane -t "${sess}:${widx}.${pidx}" 2>/dev/null
    tmux switch-client -t "${sess}:${widx}" 2>/dev/null
}

case "${1:-}" in
    --list)              list_all; exit 0 ;;
    --new-session)       new_session "${2:-}"; exit 0 ;;
    --kill-target)        kill_target "${2:-}"; exit 0 ;;
    --rename)            rename_target "${2:-}"; exit 0 ;;
    --drill-panes)       drill_panes "${2:-}"; exit 0 ;;
esac

read -r -d '' PREVIEW_CMD <<'PREVIEW'
target={-1}
type="${target%%:*}"
rest="${target#*:}"

if [ "$type" = "session" ]; then
    widx=$(tmux display-message -p -t "$rest" "#{window_index}" 2>/dev/null)
    [ -n "$widx" ] && tmux capture-pane -p -t "${rest}:${widx}" -S -45 2>/dev/null \
      || printf "preview unavailable\n"
elif [ "$type" = "window" ]; then
    sess="${rest%%:*}"
    widx="${rest#*:}"
    tmux capture-pane -p -t "${sess}:${widx}" -S -45 2>/dev/null \
      || printf "preview unavailable\n"
fi
PREVIEW

selected=$(printf '' | fzf \
    --ansi \
    --layout=reverse \
    --no-sort \
    --pointer='>' \
    --prompt='  ' \
    --color="$FZF_COLORS" \
    --delimiter=$'\t|\t' \
    --with-nth=1 \
    --border=rounded \
    --border-label=" Da Vinci Console " \
    --border-label-pos=2 \
    --input-border=rounded \
    --input-label=' Search ' \
    --input-label-pos=2 \
    --list-border=rounded \
    --list-label=' Sessions ' \
    --list-label-pos=2 \
    --preview-border=rounded \
    --preview-label=' Tmux ' \
    --preview-label-pos=2 \
    --padding=0,1 \
    --info=inline-right \
    --bind "start:reload-sync(bash '$SELF' --list)" \
    --bind 'ctrl-/:toggle-preview' \
    --bind 'alt-up:preview-up' \
    --bind 'alt-down:preview-down' \
    --bind "enter:transform:[[ {-1} == sep:* ]] && echo ignore || echo accept" \
    --bind "ctrl-n:execute(bash -c 'read -r -p \"Session name: \" n; bash \"\$1\" --new-session \"\$n\"' _ '$SELF')+abort" \
    --bind "ctrl-d:execute-silent(bash '$SELF' --kill-target {-1})+reload-sync(bash '$SELF' --list)" \
    --bind "ctrl-r:execute(bash '$SELF' --rename {-1})+reload-sync(bash '$SELF' --list)" \
    --preview-window 'right,50%,border-rounded' \
    --preview "$PREVIEW_CMD" \
)

[[ -z "$selected" ]] && exit 0

target="${selected##*$'\t|\t'}"
type="${target%%:*}"
rest="${target#*:}"

case "$type" in
    window)
        sess="${rest%%:*}"
        widx="${rest#*:}"
        pane_count=$(tmux list-panes -t "${sess}:${widx}" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$pane_count" -gt 1 ]]; then
            bash "$SELF" --drill-panes "$target"
        else
            tmux switch-client -t "$rest"
        fi
        ;;
    session) tmux switch-client -t "$rest" ;;
    sep|skip) : ;;
esac
