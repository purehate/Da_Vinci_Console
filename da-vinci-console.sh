#!/usr/bin/env bash
# da-vinci-console.sh - tmux session/window/agent picker
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SELF_DIR/$(basename "${BASH_SOURCE[0]}")"
SEP=$'\t|\t'
AGENTS_DIR="$SELF_DIR/agents"

# Live agent state (populated by load_agents, read by the list builders).
declare -A pane_agent
declare -A sess_agents

command -v tmux >/dev/null 2>&1 || { echo "tmux not found" >&2; exit 1; }
command -v fzf >/dev/null 2>&1 || { echo "fzf not found" >&2; exit 1; }

if [ -r "$HOME/.config/ts/palette.sh" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.config/ts/palette.sh"
fi

ansi_fg() {
    local hex="${1#\#}"
    printf '\033[38;2;%d;%d;%dm' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

ansi_bg() {
    local hex="${1#\#}"
    printf '\033[48;2;%d;%d;%dm' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

C_GREEN="$(ansi_fg "${TS_GIBSON:-#14E21A}")"
C_GREEN_BG="$(ansi_bg "${TS_GIBSON:-#14E21A}")"
C_BLACK="$(ansi_fg "#000000")"
C_BLUE="$(ansi_fg "${TS_PHANTOM:-#1C47FF}")"
C_GREY="$(ansi_fg "${TS_MUTED:-#666666}")"
C_DIM="$(ansi_fg "${TS_DIM:-#333333}")"
C_WHITE="$(ansi_fg "${TS_FG:-#EDF1F3}")"
C_BRIGHT="\033[38;2;255;255;255m"
C_RED="$(ansi_fg "${TS_ANSI_RED:-#FF3333}")"
C_YELLOW="$(ansi_fg "${TS_CEREAL:-#E8FD2E}")"
C_BORDER="$(ansi_fg "${TS_BORDER:-#00422C}")"
C_RESET=$'\033[0m'

FZF_COLORS="${TS_FZF_COLORS:-border:#00422C,fg:#EDF1F3,hl:#14E21A,fg+:#FFFFFF,bg+:#00422C,hl+:#14E21A,pointer:#14E21A,header:#666666,marker:#E8FD2E,spinner:#33CCCC,prompt:#14E21A,gutter:-1,label:#14E21A,bg:-1,preview-bg:-1,preview-border:#00422C,input-border:#00422C,list-border:#00422C}"

pill_label() {
    printf '%b%b %s %b%b' "$C_GREEN" "$C_GREEN_BG$C_BLACK" "$1" "$C_RESET$C_GREEN" "$C_RESET"
}

icon_for() {
    local n="${1,,}"
    n="${n##*/}"
    case "$n" in
        claude*)              echo "C" ;;
        codex*)               echo "X" ;;
        pi*)                  echo "P" ;;
        opencode*)            echo "O" ;;
        gemini*)              echo "m" ;;
        aider*)               echo "A" ;;
        grok*)                echo "k" ;;
        qwen*)                echo "Q" ;;
        continue*)            echo "c" ;;
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

light_color() {
    case "$1" in
        ◐) printf '%s' "$C_YELLOW$1$C_RESET" ;;
        ●) printf '%s' "$C_GREEN$1$C_RESET" ;;
        ○) printf '%s' "$C_GREY$1$C_RESET" ;;
        *) printf '%s' "$1" ;;
    esac
}

short_path() {
    [[ "$1" == "$HOME"* ]] && printf '~%s' "${1#"$HOME"}" || printf '%s' "$1"
}

display_path() {
    local p="$1" dir base parent max=34
    p=$(short_path "$p")
    (( ${#p} <= max )) && { printf '%s' "$p"; return; }

    base="${p##*/}"
    dir="${p%/*}"
    [[ "$dir" == "$p" ]] && { printf '%s' "$p"; return; }

    parent="${dir##*/}"
    if [[ "$dir" == "~" ]]; then
        printf '~/%s' "$base"
    elif [[ "$p" == "~/"* ]]; then
        printf '~/.../%s/%s' "$parent" "$base"
    elif [[ "$p" == /* ]]; then
        printf '/.../%s/%s' "$parent" "$base"
    else
        printf '.../%s/%s' "$parent" "$base"
    fi
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
    printf "${C_GREEN}>${C_RESET} ${C_WHITE}%s${C_RESET} ${C_BORDER}%s${C_RESET}${SEP}sep:section\n" "$label" "$body"
}

session_div() {
    local w body
    w=$(div_width)
    body=$(repeat_str '-' $(( w - 3 )))
    printf "${C_DIM}   %s${C_RESET}${SEP}sep:\n" "$body"
}

# Load live agent state into globals: pane_agent, sess_agents, agent_rows.
load_agents() {
    local name sess widx wname paneid pid light
    if [[ ! -x "$AGENTS_DIR/agents_state.sh" ]]; then
        return 0
    fi
    while IFS='|' read -r name sess widx wname paneid pid light; do
        [[ -n "$name" ]] || continue
        pane_agent["$paneid"]="$name|$light"
        if [[ -z "${sess_agents[$sess]:-}" ]]; then
            sess_agents["$sess"]="$name"
        elif [[ " ${sess_agents[$sess]} " != *" $name "* ]]; then
            sess_agents["$sess"]="${sess_agents[$sess]} $name"
        fi
    done < <(bash "$AGENTS_DIR/agents_state.sh" 2>/dev/null)
}

build_sessions() {
    local first=1 any=0

    load_agents

    local sname wins attached activity icon wlabel attached_mark age_str sessag
    while IFS='|' read -r sname wins attached activity; do
        # In agent-only view (ctrl-g), skip sessions with no agents.
        if [[ "${AGENTS_ONLY:-0}" == "1" && -z "${sess_agents[$sname]:-}" ]]; then
            continue
        fi
        any=1
        [[ "$first" == "1" ]] && first=0 || session_div

        icon=$(icon_for "$sname")
        wlabel=$([[ "$wins" == "1" ]] && echo "1 window" || echo "${wins} windows")
        attached_mark=$([[ "$attached" == "1" ]] && echo " ${C_GREEN}*${C_RESET}" || echo "")
        age_str=""
        [[ -n "$activity" && "$activity" != "0" ]] && age_str="  ${C_DIM}$(relative_time "$activity") idle${C_RESET}"
        sessag=""
        if [[ -n "${sess_agents[$sname]:-}" ]]; then
            sessag=" ${C_DIM}·${C_RESET} ${C_BLUE}${sess_agents[$sname]// /,}${C_RESET}"
        fi

        printf "${C_BRIGHT}%s%s${C_RESET}  ${C_BLUE}%s${C_RESET}%s%b%b${SEP}session:%s\n" \
            "${icon:+$icon }" "$sname" "$wlabel" "$sessag" "$attached_mark" "$age_str" "$sname"

        local widx wname wcmd wactive wpath panes wpaneid wicon pshort active_mark pane_mark an al
        while IFS='|' read -r widx wname wcmd wactive wpath panes wpaneid; do
            # In agent-only view, keep only windows running an agent.
            [[ "${AGENTS_ONLY:-0}" == "1" && -z "${pane_agent[$wpaneid]:-}" ]] && continue
            wicon=$(icon_for "$wcmd")
            [[ -z "$wicon" ]] && wicon=$(icon_for "$wname")
            pshort=$(display_path "$wpath")
            active_mark=$([[ "$wactive" == "1" ]] && echo " ${C_GREEN}+${C_RESET}" || echo "")
            pane_mark=$([[ "$panes" == "1" ]] && echo "" || echo " ${C_YELLOW}${panes}p${C_RESET}")
            printf "  ${C_DIM}|-${C_RESET} ${C_WHITE}%s%s${C_RESET}  ${C_GREY}%s:%s  %s  %s${C_RESET}%b%b${SEP}window:%s:%s\n" \
                "${wicon:+$wicon }" "$wname" "$sname" "$widx" "$wcmd" "$pshort" "$pane_mark" "$active_mark" "$sname" "$widx"
            # Agent nested directly under its window (click to jump).
            if [[ -n "${pane_agent[$wpaneid]:-}" ]]; then
                an="${pane_agent[$wpaneid]%%|*}"
                al="$(light_color "${pane_agent[$wpaneid]##*|}")"
                printf "     ${C_DIM}└${C_RESET} ${C_BLUE}%s${C_RESET} ${al}${SEP}window:%s:%s\n" "$an" "$sname" "$widx"
            fi
        done < <(tmux list-windows -t "$sname" \
            -F "#{window_index}|#{window_name}|#{pane_current_command}|#{window_active}|#{pane_current_path}|#{window_panes}|#{pane_id}" 2>/dev/null)
    done < <(tmux list-sessions \
        -F "#{session_name}|#{session_windows}|#{?session_attached,1,0}|#{session_activity}" 2>/dev/null \
        | sort -t'|' -k3,3r -k1,1)

    if [[ "$any" == "0" ]]; then
        printf "${C_DIM}No tmux sessions found. Press Ctrl-N to create one.${C_RESET}${SEP}sep:empty\n"
    fi
}

list_all() {
    build_sessions
}

list_agents() {
    AGENTS_ONLY=1
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
    --list-agents)       list_agents; exit 0 ;;
    --new-session)       new_session "${2:-}"; exit 0 ;;
    --kill-target)        kill_target "${2:-}"; exit 0 ;;
    --rename)            rename_target "${2:-}"; exit 0 ;;
    --drill-panes)       drill_panes "${2:-}"; exit 0 ;;
esac

read -r -d '' PREVIEW_CMD <<'PREVIEW'
target={-1}
type="${target%%:*}"
rest="${target#*:}"

if [ -r "$HOME/.config/ts/palette.sh" ]; then
    . "$HOME/.config/ts/palette.sh"
fi

ansi_fg() {
    local hex="${1#\#}"
    printf '\033[38;2;%d;%d;%dm' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

green="$(ansi_fg "${TS_GIBSON:-#14E21A}")"
blue="$(ansi_fg "${TS_PHANTOM:-#1C47FF}")"
yellow="$(ansi_fg "${TS_CEREAL:-#E8FD2E}")"
gray="$(ansi_fg "${TS_MUTED:-#666666}")"
white="$(ansi_fg "${TS_FG:-#EDF1F3}")"
reset=$'\033[0m'
empty="${gray}(no pane output)${reset}"
AGENTS="@AGENTS_DIR@/agents_state.sh"

short_path() {
    case "$1" in
        "$HOME"*) printf '~%s' "${1#"$HOME"}" ;;
        *) printf '%s' "$1" ;;
    esac
}

display_path() {
    p=$(short_path "$1")
    max=42
    [ "${#p}" -le "$max" ] && { printf '%s' "$p"; return; }

    base="${p##*/}"
    dir="${p%/*}"
    [ "$dir" = "$p" ] && { printf '%s' "$p"; return; }

    parent="${dir##*/}"
    case "$p" in
        "~/"*) printf '~/.../%s/%s' "$parent" "$base" ;;
        /*)    printf '/.../%s/%s' "$parent" "$base" ;;
        *)     printf '.../%s/%s' "$parent" "$base" ;;
    esac
}

light_color() {
    case "$1" in
        ◐) printf '%s' "$yellow$1$reset" ;;
        ●) printf '%s' "$green$1$reset" ;;
        ○) printf '%s' "$gray$1$reset" ;;
        *) printf '%s' "$1" ;;
    esac
}

# show_agents <session> [window-index]
show_agents() {
    local sess="$1" w="${2:-}" n s widx wn l lc
    [ -x "$AGENTS" ] || return 0
    bash "$AGENTS" 2>/dev/null | while IFS='|' read -r n s widx wn p pid l; do
        [ "$s" = "$sess" ] || continue
        [ -n "$w" ] && [ "$widx" != "$w" ] && continue
        lc="$(light_color "$l")"
        printf "  %s%s%s %s  %s:%s  %s\n" "$green" "$n" "$reset" "$lc" "$s" "$widx" "$wn"
    done
}

preview_session() {
    local sess="$1" attached created windows active_window active_cmd active_path
    attached=$(tmux display-message -p -t "$sess" "#{?session_attached,attached,detached}" 2>/dev/null)
    created=$(tmux display-message -p -t "$sess" "#{session_created_string}" 2>/dev/null)
    windows=$(tmux display-message -p -t "$sess" "#{session_windows}" 2>/dev/null)
    active_window=$(tmux display-message -p -t "$sess" "#{window_index}:#{window_name}" 2>/dev/null)
    active_cmd=$(tmux display-message -p -t "$sess" "#{pane_current_command}" 2>/dev/null)
    active_path=$(tmux display-message -p -t "$sess" "#{pane_current_path}" 2>/dev/null)

    printf "%sSession%s %s%s%s\n" "$green" "$reset" "$white" "$sess" "$reset"
    printf "%sState%s   %s%s%s  %s%s windows%s\n" "$gray" "$reset" "$blue" "$attached" "$reset" "$yellow" "${windows:-0}" "$reset"
    [[ -n "$created" ]] && printf "%sCreated%s %s\n" "$gray" "$reset" "$created"
    printf "%sActive%s  %s%s%s  %s%s%s\n" "$gray" "$reset" "$white" "${active_window:-unknown}" "$reset" "$gray" "${active_cmd:-unknown}" "$reset"
    [[ -n "$active_path" ]] && printf "%sPath%s    %s\n" "$gray" "$reset" "$(display_path "$active_path")"
    printf "%s\nAgents%s\n" "$green" "$reset"
    show_agents "$sess"
    printf "%s\nWindows%s\n" "$green" "$reset"
    tmux list-windows -t "$sess" \
        -F "  #{?window_active,+, } #{window_index}:#{window_name}  #{window_panes}p  #{pane_current_command}  #{pane_current_path}" 2>/dev/null |
        while IFS= read -r line; do
            case "$line" in
                "  +"*) printf "%s%s%s\n" "$green" "$(short_path "$line")" "$reset" ;;
                *) printf "%s%s%s\n" "$gray" "$(short_path "$line")" "$reset" ;;
            esac
        done

    printf "%s\nActive pane%s\n" "$green" "$reset"
    output=$(tmux capture-pane -p -t "$sess" -S -24 2>/dev/null | /usr/bin/sed '/^[[:space:]]*$/d' | /usr/bin/tail -24)
    [ -n "$output" ] && printf "%s\n" "$output" || printf "%s\n" "$empty"
}

preview_window() {
    local sess="$1" widx="$2" name panes cmd path
    name=$(tmux display-message -p -t "${sess}:${widx}" "#{window_name}" 2>/dev/null)
    panes=$(tmux display-message -p -t "${sess}:${widx}" "#{window_panes}" 2>/dev/null)
    cmd=$(tmux display-message -p -t "${sess}:${widx}" "#{pane_current_command}" 2>/dev/null)
    path=$(tmux display-message -p -t "${sess}:${widx}" "#{pane_current_path}" 2>/dev/null)

    printf "%sWindow%s  %s%s:%s %s%s\n" "$green" "$reset" "$white" "$sess" "$widx" "${name:-unknown}" "$reset"
    printf "%sPanes%s   %s%s%s\n" "$gray" "$reset" "$yellow" "${panes:-0}" "$reset"
    printf "%sActive%s  %s%s%s\n" "$gray" "$reset" "$white" "${cmd:-unknown}" "$reset"
    [[ -n "$path" ]] && printf "%sPath%s    %s\n" "$gray" "$reset" "$(display_path "$path")"
    printf "%s\nAgents%s\n" "$green" "$reset"
    show_agents "$sess" "$widx"
    printf "%s\nPane output%s\n" "$green" "$reset"
    output=$(tmux capture-pane -p -t "${sess}:${widx}" -S -35 2>/dev/null | /usr/bin/sed '/^[[:space:]]*$/d' | /usr/bin/tail -35)
    [ -n "$output" ] && printf "%s\n" "$output" || printf "%s\n" "$empty"
}

if [ "$type" = "session" ]; then
    preview_session "$rest"
elif [ "$type" = "window" ]; then
    sess="${rest%%:*}"
    widx="${rest#*:}"
    preview_window "$sess" "$widx"
else
    printf "%sNo tmux target selected%s\n" "$gray" "$reset"
fi
PREVIEW
# Inject the resolved agents dir (the heredoc is intentionally single-quoted).
PREVIEW_CMD="${PREVIEW_CMD//@AGENTS_DIR@/$AGENTS_DIR}"

selected=$(printf '' | fzf \
    --height 100% \
    --ansi \
    --layout=reverse \
    --no-sort \
    --pointer='>' \
    --marker='' \
    --gutter=' ' \
    --prompt='  ' \
    --no-scrollbar \
    --color="$FZF_COLORS" \
    --delimiter=$'\t|\t' \
    --with-nth=1 \
    --border=rounded \
    --input-border=rounded \
    --input-label="$(pill_label 'Search')" \
    --input-label-pos=2 \
    --list-border=rounded \
    --list-label="$(pill_label 'Sessions')" \
    --list-label-pos=2 \
    --preview-border=rounded \
    --preview-label="$(pill_label 'Tmux')" \
    --preview-label-pos=2 \
    --padding=0,1 \
    --info=inline-right \
    --header $'  Enter attach  ^N new  ^R rename  ^D kill  ^/ preview  ^G agents-only  ^T all' \
    --bind "start:reload-sync(bash '$SELF' --list)" \
    --bind 'ctrl-/:toggle-preview' \
    --bind 'ctrl-g:reload-sync(bash '$SELF' --list-agents)' \
    --bind 'ctrl-t:reload-sync(bash '$SELF' --list)' \
    --bind 'alt-up:preview-up' \
    --bind 'alt-down:preview-down' \
    --bind "enter:transform:[[ {-1} == sep:* ]] && echo ignore || echo accept" \
    --bind "ctrl-n:execute(bash -c 'read -r -p \"Session name: \" n; bash \"\$1\" --new-session \"\$n\"' _ '$SELF')+abort" \
    --bind "ctrl-d:execute-silent(bash '$SELF' --kill-target {-1})+reload-sync(bash '$SELF' --list)" \
    --bind "ctrl-r:execute(bash '$SELF' --rename {-1})+reload-sync(bash '$SELF' --list)" \
    --preview-window 'hidden,right,42%,border-rounded' \
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
