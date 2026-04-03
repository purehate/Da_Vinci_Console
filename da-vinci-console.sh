#!/usr/bin/env bash
# sesh_picker.sh — TrustedSec session/window picker
set -u

SESH="sesh"
command -v sesh >/dev/null 2>&1 || SESH="$HOME/go/bin/sesh"
command -v "$SESH" >/dev/null 2>&1 || { echo "sesh not found" >&2; exit 1; }

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# ── Colors ───────────────────────────────────────────────────────────────────
C_GREEN="\033[38;2;20;226;26m"
C_GREY="\033[38;2;123;132;150m"
C_DIM="\033[38;2;51;51;51m"
C_WHITE="\033[38;2;220;220;220m"
C_BRIGHT="\033[38;2;255;255;255m"
C_RESET="\033[0m"

FZF_COLORS="border:#24b030,fg:#b3b3b3,hl:#14E21A,fg+:#e6e6e6,bg+:-1,hl+:#14E21A,pointer:#14E21A,header:#7b8496,marker:#14E21A,spinner:#14E21A,prompt:#14E21A,gutter:-1,label:#24b030,bg:-1,preview-bg:-1"

SEP=$'\t|\t'

# ── Icons ────────────────────────────────────────────────────────────────────
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
        odoo*)                echo "" ;;
        zsh|bash|fish|shell*) echo "" ;;
        qa|dev|staging)       echo "󰑮" ;;
        *)                    echo "" ;;
    esac
}

short_path() { [[ "$1" == "$HOME"* ]] && echo "~${1#"$HOME"}" || echo "$1"; }

# ── List builders ────────────────────────────────────────────────────────────
build_sessions() {
    local first=1
    while IFS='|' read -r sname wins att; do
        local icon wlabel att_mark
        [[ "$first" == "1" ]] && first=0 || session_div
        icon=$(icon_for "$sname")
        wlabel=$([[ "$wins" == "1" ]] && echo "1 window" || echo "${wins} windows")
        att_mark=$([[ "$att" == "1" ]] && echo " ${C_GREEN}●${C_RESET}" || echo "")
        printf "${C_BRIGHT}${icon:+$icon }${sname}${C_RESET}  ${C_GREY}${wlabel}${C_RESET}${att_mark}${SEP}session:${sname}\n"

        while IFS='|' read -r widx wname wcmd wactive wpath; do
            local wicon pshort mark
            wicon=$(icon_for "$wcmd"); [[ -z "$wicon" ]] && wicon=$(icon_for "$wname")
            pshort=$(short_path "$wpath")
            mark=$([[ "$wactive" == "1" ]] && echo " ${C_GREEN}✦${C_RESET}" || echo "")
            printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE}${wicon:+$wicon }${wname}${C_RESET}  ${C_GREY}${sname}:${widx}  ${wcmd}  ${pshort}${C_RESET}${mark}${SEP}window:${sname}:${widx}\n"
        done < <(tmux list-windows -t "$sname" \
          -F "#{window_index}|#{window_name}|#{pane_current_command}|#{window_active}|#{pane_current_path}" 2>/dev/null)
    done < <(tmux list-sessions -F "#{session_name}|#{session_windows}|#{?session_attached,1,0}" 2>/dev/null \
      | sort -t'|' -k3,3r -k1,1)
}

build_windows() {
    local cur_sess=""
    while IFS='|' read -r sname widx wname wcmd wactive wpath; do
        if [[ "$sname" != "$cur_sess" ]]; then
            [[ -n "$cur_sess" ]] && session_div
            section_sep " $sname"
            cur_sess="$sname"
        fi
        local wicon pshort mark
        wicon=$(icon_for "$wcmd"); [[ -z "$wicon" ]] && wicon=$(icon_for "$wname")
        pshort=$(short_path "$wpath")
        mark=$([[ "$wactive" == "1" ]] && echo " ${C_GREEN}✦${C_RESET}" || echo "")
        printf "${C_WHITE}${wicon:+$wicon }${wname}${C_RESET}  ${C_GREY}${sname}:${widx}  ${wcmd}  ${pshort}${C_RESET}${mark}${SEP}window:${sname}:${widx}\n"
    done < <(tmux list-windows -a \
      -F "#{session_name}|#{window_index}|#{window_name}|#{pane_current_command}|#{window_active}|#{pane_current_path}" 2>/dev/null \
      | sort -t'|' -k1,1 -k2,2n)
}

find_repos() {
    # If SESH_REPO_DIRS is set, search those dirs (colon-separated); otherwise auto-scan ~/
    if [[ -n "${SESH_REPO_DIRS:-}" ]]; then
        local IFS=':'
        for base in $SESH_REPO_DIRS; do
            base="${base/#\~/$HOME}"
            [[ -d "$base" ]] || continue
            find "$base" -maxdepth 2 -name ".git" -type d 2>/dev/null | sed 's|/.git$||'
        done
    else
        find "$HOME" -maxdepth 3 \
          \( \( -name ".*" ! -name ".git" \) -o -name "node_modules" -o -name ".venv" \
             -o -name "venv" -o -name "vendor" -o -name "target" \
             -o -name "__pycache__" -o -name "dist" -o -name "build" \) -prune \
          -o -name ".git" -type d -print 2>/dev/null | sed 's|/.git$||'
    fi | sort -u
}

build_repos() {
    local active_sessions
    active_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)

    find_repos | while IFS= read -r repo; do
        local icon pshort name
        icon=$(icon_for "$(basename "$repo")")
        pshort=$(short_path "$repo")
        name=$(basename "$repo")
        if echo "$active_sessions" | grep -qx "$name" 2>/dev/null; then
            printf "${C_GREEN}${icon:+$icon }${pshort}${C_RESET}  ${C_GREEN}●${C_RESET}${SEP}session:${name}\n"
        else
            printf "${C_WHITE}${icon:+$icon }${pshort}${C_RESET}${SEP}sesh:${repo}\n"
        fi
    done
}

build_curdir() {
    local curdir
    curdir=$(tmux display-message -p "#{pane_current_path}" 2>/dev/null)
    [[ -z "$curdir" || ! -d "$curdir" ]] && curdir="$HOME"
    local active_sessions
    active_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    find "$curdir" -maxdepth 1 -mindepth 1 -not -name '.*' 2>/dev/null | sort \
      | while IFS= read -r entry; do
            local icon pshort name
            icon=$(icon_for "$(basename "$entry")")
            pshort=$(short_path "$entry")
            name=$(basename "$entry")
            if [[ -d "$entry" ]]; then
                if echo "$active_sessions" | grep -qx "$name" 2>/dev/null; then
                    printf "${C_GREEN}${icon:+$icon }${pshort}${C_RESET}  ${C_GREEN}●${C_RESET}${SEP}session:${name}\n"
                else
                    printf "${C_WHITE}${icon:+$icon }${pshort}${C_RESET}${SEP}sesh:${entry}\n"
                fi
            else
                printf "${C_GREY}󰈔 ${pshort}${C_RESET}${SEP}skip:\n"
            fi
        done
}

C_BORDER="\033[38;2;36;176;48m"   # #24b030 — matches fzf border colour

section_sep() {
    printf "${C_BORDER}──${C_RESET} ${C_WHITE}${1}${C_RESET} ${C_BORDER}$(printf '─%.0s' {1..52})${C_RESET}${SEP}sep:\n"
}

session_div() {
    printf "${C_DIM}   $(printf '╌%.0s' {1..58})${C_RESET}${SEP}sep:\n"
}

build_all() {
    section_sep " Sessions & Windows  "
    build_sessions
    section_sep " Repos  "
    build_repos
    section_sep " Current Dir  "
    build_curdir
}

build_jump() {
    section_sep " Configured"
    "$SESH" list -c -z 2>/dev/null | while IFS= read -r name; do
        local icon pshort
        icon=$(icon_for "$(basename "$name")")
        pshort=$(short_path "$name")
        printf "${C_WHITE}${icon:+$icon }${pshort}${C_RESET}${SEP}sesh:${name}\n"
    done

    section_sep " Frecent  (zoxide)"
    zoxide query -l 2>/dev/null | while IFS= read -r name; do
        local icon pshort
        icon=$(icon_for "$(basename "$name")")
        pshort=$(short_path "$name")
        printf "${C_WHITE}${icon:+$icon }${pshort}${C_RESET}  ${C_DIM}z${C_RESET}${SEP}sesh:${name}\n"
    done
}

# ── Reload targets (called by fzf binds) ─────────────────────────────────────
case "${1:-}" in
    --list-all)      build_all;      exit 0 ;;
    --list-sessions) build_sessions; exit 0 ;;
    --list-windows)  build_windows;  exit 0 ;;
    --list-jump)     build_jump;     exit 0 ;;
    --list-repos)    build_repos;    exit 0 ;;
    --new-session)
        raw="${2:-}"
        path="${raw#sesh:}"
        [[ "$path" == "$raw" || -z "$path" ]] && exit 0
        name="$(basename "$path")"
        tmux new-session -d -s "$name" -c "$path" 2>/dev/null || true
        tmux switch-client -t "$name" 2>/dev/null
        exit 0
        ;;
esac

# ── Preview ({-1} = last field = metadata: "session:NAME" or "window:SESSION:IDX") ───
read -r -d '' PREVIEW_CMD <<'PREVIEW'
target={-1}
type="${target%%:*}"
rest="${target#*:}"
if [ "$type" = "session" ]; then
    wins=$(tmux list-windows -t "$rest" \
      -F "  #{window_index}. #{window_name}  (#{pane_current_command})#{?window_active,  ✦,}" 2>/dev/null)
    printf "\033[38;2;20;226;26m%s\033[0m\n\n" "$rest"
    printf "%s\n" "$wins"
    printf "\n\033[38;2;51;51;51m─────────────────────────────\033[0m\n"
    widx=$(tmux display-message -p -t "$rest" "#{window_index}" 2>/dev/null)
    [ -n "$widx" ] && tmux capture-pane -p -t "${rest}:${widx}" -S -20 2>/dev/null \
      || printf "preview unavailable\n"
elif [ "$type" = "window" ]; then
    sess="${rest%%:*}"
    widx="${rest#*:}"
    wins=$(tmux list-windows -t "$sess" \
      -F "  #{window_index}. #{window_name}  (#{pane_current_command})#{?window_active,  ✦,}" 2>/dev/null)
    printf "\033[38;2;20;226;26m%s\033[0m\n\n" "${sess}:${widx}"
    printf "%s\n" "$wins"
    printf "\n\033[38;2;51;51;51m─────────────────────────────\033[0m\n"
    tmux capture-pane -p -t "${sess}:${widx}" -S -20 2>/dev/null \
      || printf "preview unavailable\n"
elif [ "$type" = "sesh" ]; then
    if git -C "$rest" rev-parse --git-dir >/dev/null 2>&1; then
        branch=$(git -C "$rest" symbolic-ref --short HEAD 2>/dev/null \
                 || git -C "$rest" rev-parse --short HEAD 2>/dev/null)
        dirty=$(git -C "$rest" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [ "$dirty" -gt 0 ]; then
            dirty_mark="\033[38;2;255;100;80m  ✗ ${dirty} changed\033[0m"
        else
            dirty_mark="\033[38;2;20;226;26m  ✓\033[0m"
        fi
        printf "\033[38;2;20;226;26m %s\033[0m%b\n" "$branch" "$dirty_mark"
        printf "\033[38;2;51;51;51m────────────────────────────────\033[0m\n"
        git -C "$rest" log --color=always -8 \
          --format="%C(dim)%h%C(reset)  %C(238)%ar%C(reset)  %s" 2>/dev/null
        printf "\n\033[38;2;51;51;51m────────────────────────────────\033[0m\n"
        if command -v onefetch >/dev/null 2>&1; then
            onefetch "$rest" --no-title 2>/dev/null
        else
            sesh preview "$rest" 2>/dev/null
        fi
    else
        sesh preview "$rest" 2>/dev/null || printf "no preview available\n"
    fi
fi
PREVIEW

CURR_SESS="$(tmux display-message -p '#S' 2>/dev/null || echo 'tmux')"  # kept for ctrl-d kill context
HEADER="  Enter switch  •  ^N new session  •  ^A all  •  ^J jump  •  ^W windows  •  ^D kill  •  ^/ preview  •  alt-↑↓ scroll"

selected=$(build_all | fzf \
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
    --border-label=" 󰔎 Da Vinci Console " \
    --border-label-pos=2 \
    --input-border=rounded \
    --input-label='  Search ' \
    --input-label-pos=2 \
    --list-border=rounded \
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
    --bind "enter:transform:[[ {-1} == sep: || {-1} == skip: ]] && echo 'reload(bash $SELF --list-all)+change-list-label()' || echo 'accept'" \
    --bind "ctrl-n:execute-silent(bash '$SELF' --new-session {-1})+abort" \
    --bind "ctrl-a:reload(bash '$SELF' --list-all)+change-list-label()" \
    --bind "ctrl-j:reload(bash '$SELF' --list-jump)+change-list-label(  Jump )" \
    --bind "ctrl-w:reload(bash '$SELF' --list-windows)+change-list-label(  Windows )" \
    --bind "ctrl-d:execute-silent(bash -c 't={-1}; t=\"\${t#*:}\"; tmux kill-session -t \"\${t%%:*}\" 2>/dev/null')+reload(bash '$SELF' --list-all)+change-list-label()" \
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
    sep|skip)       : ;;
    *)              "$SESH" connect "$target" ;;
esac
