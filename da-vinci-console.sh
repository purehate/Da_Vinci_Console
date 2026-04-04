#!/usr/bin/env bash
# sesh_picker.sh — TrustedSec session/window picker
set -u

SESH="sesh"
command -v sesh >/dev/null 2>&1 || SESH="$HOME/go/bin/sesh"
command -v "$SESH" >/dev/null 2>&1 || { echo "sesh not found" >&2; exit 1; }

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/dvc/item_model.sh"
source "$SCRIPT_DIR/lib/dvc/state.sh"
source "$SCRIPT_DIR/lib/dvc/provider_workspaces.sh"
source "$SCRIPT_DIR/lib/dvc/provider_tmux.sh"
source "$SCRIPT_DIR/lib/dvc/merge.sh"
source "$SCRIPT_DIR/lib/dvc/rank.sh"
source "$SCRIPT_DIR/lib/dvc/render.sh"

# ── Colors ───────────────────────────────────────────────────────────────────
C_GREEN="\033[38;2;20;226;26m"
C_GREY="\033[38;2;123;132;150m"
C_DIM="\033[38;2;51;51;51m"
C_WHITE="\033[38;2;220;220;220m"
C_BRIGHT="\033[38;2;255;255;255m"
C_RED="\033[38;2;255;100;80m"
C_YELLOW="\033[38;2;255;200;60m"
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

relative_time() {
    local now diff s="$1"
    now=$(date +%s)
    diff=$(( now - s ))
    if   (( diff < 60 ));    then echo "just now"
    elif (( diff < 3600 ));  then echo "$(( diff / 60 ))m ago"
    elif (( diff < 86400 )); then echo "$(( diff / 3600 ))h ago"
    else                          echo "$(( diff / 86400 ))d ago"
    fi
}

lang_icon_for() {
    local d="$1"
    [[ -f "$d/Cargo.toml" ]]                                                     && echo "" && return
    [[ -f "$d/package.json" ]]                                                    && echo "" && return
    [[ -f "$d/go.mod" ]]                                                         && echo "" && return
    [[ -f "$d/requirements.txt" || -f "$d/pyproject.toml" || -f "$d/setup.py" ]] && echo "" && return
    [[ -f "$d/composer.json" ]]                                                   && echo "" && return
    [[ -f "$d/pom.xml" || -f "$d/build.gradle" || -f "$d/build.gradle.kts" ]]   && echo "" && return
    [[ -f "$d/Gemfile" ]]                                                        && echo "" && return
    [[ -f "$d/CMakeLists.txt" ]]                                                 && echo "" && return
    echo ""
}

repo_color() {
    local repo="$1" d work_dirs="${SESH_WORK_DIRS:-$HOME/DEVELOPMENT}"
    local IFS=':'
    for d in $work_dirs; do
        d="${d/#\~/$HOME}"
        [[ "$repo" == "$d"* ]] && echo "$C_WORK" && return
    done
    echo "$C_PERS"
}

# ── List builders ────────────────────────────────────────────────────────────
build_sessions() {
    local first=1
    while IFS='|' read -r sname wins att activity; do
        local icon wlabel att_mark age_str
        [[ "$first" == "1" ]] && first=0 || session_div
        icon=$(icon_for "$sname")
        wlabel=$([[ "$wins" == "1" ]] && echo "1 window" || echo "${wins} windows")
        att_mark=$([[ "$att" == "1" ]] && echo " ${C_GREEN}●${C_RESET}" || echo "")
        age_str=""
        [[ -n "$activity" && "$activity" != "0" ]] && age_str="  ${C_DIM}$(relative_time "$activity")${C_RESET}"
        local stags tag_str=""
        stags=$(tags_for_session "$sname")
        [[ -n "$stags" ]] && tag_str="  ${C_YELLOW}[${stags}]${C_RESET}"
        printf "${C_BRIGHT}${icon:+$icon }${sname}${C_RESET}  ${C_GREY}${wlabel}${C_RESET}${att_mark}${age_str}${tag_str}${SEP}session:${sname}\n"

        while IFS='|' read -r widx wname wcmd wactive wpath; do
            local wicon pshort mark
            wicon=$(icon_for "$wcmd"); [[ -z "$wicon" ]] && wicon=$(icon_for "$wname")
            pshort=$(short_path "$wpath")
            mark=$([[ "$wactive" == "1" ]] && echo " ${C_GREEN}✦${C_RESET}" || echo "")
            printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE}${wicon:+$wicon }${wname}${C_RESET}  ${C_GREY}${sname}:${widx}  ${wcmd}  ${pshort}${C_RESET}${mark}${SEP}window:${sname}:${widx}\n"
        done < <(tmux list-windows -t "$sname" \
          -F "#{window_index}|#{window_name}|#{pane_current_command}|#{window_active}|#{pane_current_path}" 2>/dev/null)
    done < <(tmux list-sessions -F "#{session_name}|#{session_windows}|#{?session_attached,1,0}|#{session_activity}" 2>/dev/null \
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
        local icon lang pshort name color branch branch_str
        icon=$(icon_for "$(basename "$repo")")
        lang=$(lang_icon_for "$repo")
        pshort=$(short_path "$repo")
        name=$(basename "$repo")
        color=$(repo_color "$repo")
        branch=$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null \
                 || git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo "")
        branch_str=$([[ -n "$branch" ]] && echo "  ${C_DIM}${branch}${C_RESET}" || echo "")
        dirty=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        dirty_str=""
        if [[ "$dirty" -gt 0 ]]; then
            dirty_str="  ${C_RED}✗ ${dirty}${C_RESET}"
        fi
        if echo "$active_sessions" | grep -qx "$name" 2>/dev/null; then
            printf "${C_GREEN}${icon:+$icon }${pshort}${C_RESET}${branch_str}${dirty_str}  ${C_GREEN}● ${lang}${C_RESET}${SEP}session:${name}\n"
        else
            printf "${color}${icon:+$icon }${pshort}${C_RESET}${branch_str}${dirty_str}  ${C_GREY}${lang}${C_RESET}${SEP}sesh:${repo}\n"
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
C_WORK="\033[38;2;100;160;255m"   # steel blue  — work repos
C_PERS="\033[38;2;180;140;255m"   # soft purple — personal repos

section_sep() {
    printf "${C_BORDER}──${C_RESET} ${C_WHITE}${1}${C_RESET} ${C_BORDER}$(printf '─%.0s' {1..52})${C_RESET}${SEP}sep:\n"
}

session_div() {
    printf "${C_DIM}   $(printf '╌%.0s' {1..58})${C_RESET}${SEP}sep:\n"
}

build_docker() {
    command -v docker >/dev/null 2>&1 || return
    local cid cname cimage cstatus
    while IFS='|' read -r cid cname cimage cstatus; do
        [[ -z "$cid" ]] && continue
        printf "${C_WHITE} ${cname}${C_RESET}  ${C_GREY}${cimage}  ${cstatus}${C_RESET}${SEP}docker:${cid}:${cname}\n"
    done < <(docker ps --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}' 2>/dev/null)
}

build_ssh() {
    local ssh_config="${HOME}/.ssh/config"
    [[ -f "$ssh_config" ]] || return
    awk '/^[Hh]ost / { for (i=2; i<=NF; i++) print $i }' "$ssh_config" 2>/dev/null \
      | while IFS= read -r host; do
            # Skip wildcards and empty
            [[ -z "$host" || "$host" == *"*"* || "$host" == *"?"* ]] && continue
            printf "${C_WHITE}󰣀 ${host}${C_RESET}${SEP}ssh:${host}\n"
        done
}

# ── Session tags ──────────────────────────────────────────────────────────────
TAGS_FILE="${HOME}/.config/tmux/session-tags.conf"

tags_for_session() {
    local sess="$1"
    [[ -f "$TAGS_FILE" ]] || return
    local line
    line=$(grep "^${sess}=" "$TAGS_FILE" 2>/dev/null) || return
    echo "${line#*=}"
}

build_tagged() {
    local filter_tag="$1"
    [[ -f "$TAGS_FILE" ]] || return
    local first=1
    while IFS='|' read -r sname wins att activity; do
        local stags
        stags=$(tags_for_session "$sname")
        [[ -z "$stags" ]] && continue
        if [[ -n "$filter_tag" ]] && ! echo "$stags" | tr ',' '\n' | grep -qx "$filter_tag"; then
            continue
        fi
        local icon wlabel att_mark age_str
        [[ "$first" == "1" ]] && first=0 || session_div
        icon=$(icon_for "$sname")
        wlabel=$([[ "$wins" == "1" ]] && echo "1 window" || echo "${wins} windows")
        att_mark=$([[ "$att" == "1" ]] && echo " ${C_GREEN}●${C_RESET}" || echo "")
        age_str=""
        [[ -n "$activity" && "$activity" != "0" ]] && age_str="  ${C_DIM}$(relative_time "$activity")${C_RESET}"
        local tag_str="${C_YELLOW}[${stags}]${C_RESET}"
        printf "${C_BRIGHT}${icon:+$icon }${sname}${C_RESET}  ${C_GREY}${wlabel}${C_RESET}${att_mark}${age_str}  ${tag_str}${SEP}session:${sname}\n"
    done < <(tmux list-sessions -F "#{session_name}|#{session_windows}|#{?session_attached,1,0}|#{session_activity}" 2>/dev/null \
      | sort -t'|' -k3,3r -k1,1)
}

build_all() {
    section_sep " Sessions & Windows  "
    build_sessions
    section_sep " Repos  "
    build_repos
    # Docker section — only if docker is available and containers are running
    if command -v docker >/dev/null 2>&1 && docker ps -q 2>/dev/null | head -1 | grep -q .; then
        section_sep " Docker  "
        build_docker
    fi
    # SSH bookmarks — only if ~/.ssh/config exists with hosts
    if [[ -f "${HOME}/.ssh/config" ]]; then
        section_sep "󰣀 SSH Bookmarks  "
        build_ssh
    fi
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

dvc_list_query() {
    local query="${1:-}"
    local current_dir workspace_file live_file
    current_dir=$(tmux display-message -p "#{pane_current_path}" 2>/dev/null || pwd)
    workspace_file="$(mktemp)"
    live_file="$(mktemp)"

    dvc_workspace_items "$current_dir" >"$workspace_file"
    dvc_live_items >"$live_file"

    dvc_merge_workspace_and_live_items "$workspace_file" "$live_file" \
      | dvc_rank_items "$query" "$current_dir" \
      | dvc_render_grouped_view
}

dvc_preview_row_cmd() {
    local row="${1:-}"
    [[ -z "$row" || "$row" == sep:* ]] && exit 0

    local kind path target label
    kind="$(dvc_item_field "$row" kind)"
    path="$(dvc_item_field "$row" path)"
    target="$(dvc_item_field "$row" target)"
    label="$(dvc_item_field "$row" label)"

    case "$kind" in
        workspace)
            printf "Workspace: %s\nPath: %s\n" "$label" "$path"
            git -C "$path" log --oneline -5 2>/dev/null || printf "no git preview available\n"
            ;;
        session|window)
            tmux capture-pane -p -t "$target" -S -20 2>/dev/null || printf "preview unavailable\n"
            ;;
        *)
            printf "preview unavailable\n"
            ;;
    esac
}

# ── Reload targets (called by fzf binds) ─────────────────────────────────────
case "${1:-}" in
    --list-query)    dvc_list_query "${2:-}"; exit 0 ;;
    --preview-row)   dvc_preview_row_cmd "${2:-}"; exit 0 ;;
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
    --kill-window)
        raw="${2:-}"
        [[ "$raw" == window:* ]] || exit 0
        rest="${raw#window:}"
        tmux kill-window -t "${rest%%:*}:${rest#*:}" 2>/dev/null
        exit 0
        ;;
    --rename)
        raw="${2:-}"
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
        exit 0
        ;;
    --move-window)
        raw="${2:-}"
        [[ "$raw" == window:* ]] || exit 0
        rest="${raw#window:}"
        src_sess="${rest%%:*}"
        src_widx="${rest#*:}"
        # Pick destination session via nested fzf
        dest=$(tmux list-sessions -F "#{session_name}" 2>/dev/null \
          | grep -v "^${src_sess}$" \
          | fzf --ansi --layout=reverse --height=40% --prompt="Move to session: " \
                --border=rounded --color="$FZF_COLORS" 2>/dev/null)
        [[ -z "$dest" ]] && exit 0
        tmux move-window -s "${src_sess}:${src_widx}" -t "${dest}:" 2>/dev/null
        exit 0
        ;;
    --new-blank-session)
        name="${2:-}"
        [[ -z "$name" ]] && exit 0
        tmux new-session -d -s "$name" 2>/dev/null || true
        tmux switch-client -t "$name" 2>/dev/null
        exit 0
        ;;
    --snapshot)
        raw="${2:-}"
        type="${raw%%:*}"
        rest="${raw#*:}"
        [[ "$type" == "session" || "$type" == "window" ]] || exit 0
        snap_dir="${HOME}/.config/tmux/snapshots"
        mkdir -p "$snap_dir"
        sess="$rest"
        [[ "$type" == "window" ]] && sess="${rest%%:*}"
        snap_file="${snap_dir}/${sess}.snapshot"
        {
            echo "# Da Vinci Console snapshot: ${sess}"
            echo "# Created: $(date -Iseconds)"
            echo "session=$sess"
            tmux list-windows -t "$sess" \
              -F "window|#{window_name}|#{pane_current_path}|#{pane_current_command}|#{window_layout}" 2>/dev/null
        } > "$snap_file"
        exit 0
        ;;
    --restore-snapshot)
        snap_dir="${HOME}/.config/tmux/snapshots"
        [[ -d "$snap_dir" ]] || { echo "No snapshots found" >&2; exit 0; }
        snap=$(ls -1 "$snap_dir"/*.snapshot 2>/dev/null \
          | xargs -I{} basename {} .snapshot \
          | fzf --ansi --layout=reverse --height=40% --prompt="Restore snapshot: " \
                --border=rounded --color="$FZF_COLORS" 2>/dev/null)
        [[ -z "$snap" ]] && exit 0
        snap_file="${snap_dir}/${snap}.snapshot"
        [[ -f "$snap_file" ]] || exit 0
        sess=$(grep "^session=" "$snap_file" | cut -d= -f2)
        tmux new-session -d -s "$sess" 2>/dev/null || true
        first=1
        while IFS='|' read -r _ wname wpath wcmd _layout; do
            if [[ "$first" == "1" ]]; then
                tmux rename-window -t "${sess}:0" "$wname" 2>/dev/null
                tmux send-keys -t "${sess}:0" "cd $(printf '%q' "$wpath")" Enter 2>/dev/null
                first=0
            else
                tmux new-window -t "${sess}:" -n "$wname" -c "$wpath" 2>/dev/null
            fi
        done < <(grep "^window|" "$snap_file")
        tmux switch-client -t "$sess" 2>/dev/null
        exit 0
        ;;
    --drill-panes)
        raw="${2:-}"
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
          -F "#{pane_index}  #{pane_current_command}  #{pane_current_path}  #{pane_width}x#{pane_height}#{?pane_active,  ✦,}" 2>/dev/null \
          | fzf --ansi --layout=reverse --height=40% --prompt="Select pane: " \
                --border=rounded --color="$FZF_COLORS" \
                --preview "tmux capture-pane -p -t '${sess}:${widx}.{1}' -S -20 2>/dev/null" \
                --preview-window='right:50%' 2>/dev/null)
        [[ -z "$pane_sel" ]] && exit 0
        pidx="${pane_sel%%  *}"
        pidx="${pidx%% *}"
        tmux select-pane -t "${sess}:${widx}.${pidx}" 2>/dev/null
        tmux switch-client -t "${sess}:${widx}" 2>/dev/null
        exit 0
        ;;
    --multi-open)
        # Reads newline-separated selections from stdin
        while IFS= read -r line; do
            target="${line##*$'\t|\t'}"
            type="${target%%:*}"
            rest="${target#*:}"
            case "$type" in
                sesh)
                    name="$(basename "$rest")"
                    tmux new-session -d -s "$name" -c "$rest" 2>/dev/null || true
                    ;;
                session) tmux switch-client -t "$rest" 2>/dev/null ;;
                window)  tmux switch-client -t "$rest" 2>/dev/null ;;
                docker)
                    cid="${rest%%:*}"
                    cname="${rest#*:}"
                    tmux new-window -n "$cname" "docker exec -it $(printf '%q' "$cid") sh -c 'exec bash 2>/dev/null || exec sh'" 2>/dev/null
                    ;;
                ssh)
                    tmux new-window -n "$rest" "ssh $(printf '%q' "$rest")" 2>/dev/null
                    ;;
            esac
        done
        exit 0
        ;;
    --multi-kill)
        while IFS= read -r line; do
            target="${line##*$'\t|\t'}"
            type="${target%%:*}"
            rest="${target#*:}"
            case "$type" in
                window)
                    tmux kill-window -t "${rest%%:*}:${rest#*:}" 2>/dev/null
                    ;;
                session)
                    tmux kill-session -t "$rest" 2>/dev/null
                    ;;
            esac
        done
        exit 0
        ;;
    --list-docker)  build_docker;  exit 0 ;;
    --list-ssh)     build_ssh;     exit 0 ;;
    --list-tags)
        tag="${2:-}"
        build_tagged "$tag"
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
elif [ "$type" = "docker" ]; then
    cid="${rest%%:*}"
    cname="${rest#*:}"
    printf "\033[38;2;20;226;26m %s\033[0m\n\n" "$cname"
    docker inspect --format '  Image:   {{.Config.Image}}
  Status:  {{.State.Status}}
  Started: {{.State.StartedAt}}
  Ports:   {{range $p, $c := .NetworkSettings.Ports}}{{$p}} {{end}}
  Mounts:  {{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' "$cid" 2>/dev/null
    printf "\n\033[38;2;51;51;51m────────────────────────────────\033[0m\n"
    docker logs --tail 15 "$cid" 2>/dev/null
elif [ "$type" = "ssh" ]; then
    printf "\033[38;2;20;226;26m󰣀 %s\033[0m\n\n" "$rest"
    # Show ssh_config details for this host
    awk -v host="$rest" '
        BEGIN { found=0 }
        /^[Hh]ost / {
            if (found) exit
            split($0, a, " ")
            for (i=2; i<=length(a); i++) { if (a[i] == host) found=1 }
        }
        found && !/^[Hh]ost / { print "  " $0 }
    ' ~/.ssh/config 2>/dev/null
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
HEADER="  Enter switch  •  Tab select  •  ^N new  •  ^X kill  •  ^D kill sess  •  ^R rename  •  ^S move win
  ^A all  •  ^J jump  •  ^W windows  •  ^G tags  •  ^B snap  •  ^O restore  •  ^/ preview  •  alt-↑↓ scroll"

selected=$(bash "$SELF" --list-query "" | fzf \
    --ansi \
    --disabled \
    --layout=reverse \
    --height=100% \
    --no-sort \
    --multi \
    --pointer='▶' \
    --marker='◆' \
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
    --bind "start:reload(bash '$SELF' --list-query '')" \
    --bind "change:reload(bash '$SELF' --list-query {q})" \
    --bind 'tab:toggle+down,btab:toggle+up' \
    --bind 'ctrl-/:toggle-preview' \
    --bind 'alt-up:preview-up' \
    --bind 'alt-down:preview-down' \
    --bind "enter:transform:[[ {-1} == sep:* || {-1} == skip:* ]] && echo 'reload(bash $SELF --list-query {q})+change-list-label()' || echo 'accept'" \
    --bind "ctrl-n:transform:[[ {-1} == sesh:* ]] && echo 'execute-silent(bash \"$SELF\" --new-session {-1})+abort' || echo 'execute(read -p \"Session name: \" n && bash \"$SELF\" --new-blank-session \"\$n\")+abort'" \
    --bind "ctrl-x:execute-silent(bash '$SELF' --kill-window {-1})+reload(bash '$SELF' --list-all)" \
    --bind "ctrl-a:reload(bash '$SELF' --list-all)+change-list-label()" \
    --bind "ctrl-j:reload(bash '$SELF' --list-jump)+change-list-label(  Jump )" \
    --bind "ctrl-w:reload(bash '$SELF' --list-windows)+change-list-label(  Windows )" \
    --bind "ctrl-g:reload(bash '$SELF' --list-tags)+change-list-label(  Tags )" \
    --bind "ctrl-d:execute-silent(bash -c 't={-1}; t=\"\${t#*:}\"; tmux kill-session -t \"\${t%%:*}\" 2>/dev/null')+reload(bash '$SELF' --list-all)+change-list-label()" \
    --bind "ctrl-r:execute(bash '$SELF' --rename {-1})+reload(bash '$SELF' --list-all)" \
    --bind "ctrl-s:execute(bash '$SELF' --move-window {-1})+reload(bash '$SELF' --list-all)" \
    --bind "ctrl-b:execute-silent(bash '$SELF' --snapshot {-1})+reload(bash '$SELF' --list-all)" \
    --bind "ctrl-o:execute(bash '$SELF' --restore-snapshot)+abort" \
    --preview-window 'right:50%' \
    --preview "bash '$SELF' --preview-row {-1}" \
)

[[ -z "$selected" ]] && exit 0

# Count selections — if multiple, batch-open them
sel_count=$(echo "$selected" | wc -l | tr -d ' ')
if [[ "$sel_count" -gt 1 ]]; then
    echo "$selected" | bash "$SELF" --multi-open
    exit 0
fi

target="${selected##*$'\t|\t'}"
[[ "$target" == sep:* || "$target" == skip:* ]] && exit 0

type="$(dvc_item_field "$target" kind)"
rest="$(dvc_item_field "$target" target)"
path="$(dvc_item_field "$target" path)"

case "$type" in
    workspace)
        if [[ "$(dvc_item_field "$target" meta)" == *"live=1"* ]]; then
            tmux switch-client -t "$rest"
        else
            "$SESH" connect "$path"
        fi
        ;;
    window)
        # Drill down into panes if the window has multiple
        sess="${rest%%:*}"
        widx="${rest#*:}"
        pane_count=$(tmux list-panes -t "${sess}:${widx}" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$pane_count" -gt 1 ]]; then
            bash "$SELF" --drill-panes "$target"
        else
            tmux switch-client -t "$rest"
        fi
        ;;
    session)    tmux switch-client -t "$rest" ;;
    sesh)       "$SESH" connect "$rest" ;;
    docker)
        cid="${rest%%:*}"
        cname="${rest#*:}"
        tmux new-window -n "$cname" "docker exec -it $(printf '%q' "$cid") sh -c 'exec bash 2>/dev/null || exec sh'"
        ;;
    ssh)        tmux new-window -n "$rest" "ssh $(printf '%q' "$rest")" ;;
    sep|skip)   : ;;
    *)          "$SESH" connect "$target" ;;
esac
