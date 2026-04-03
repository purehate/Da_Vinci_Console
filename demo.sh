#!/usr/bin/env bash
# demo.sh — launch Da Vinci Console with fake data for screenshots
# Usage: bash demo.sh
set -u

DVC_COLOR_ACTIVE="${DVC_COLOR_ACTIVE:-#14E21A}"
DVC_COLOR_BORDER="${DVC_COLOR_BORDER:-#24b030}"
DVC_TITLE="${DVC_TITLE:- 󰔎 Da Vinci Console }"

FZF_COLORS="border:${DVC_COLOR_BORDER},fg:#b3b3b3,hl:${DVC_COLOR_ACTIVE},fg+:#e6e6e6,bg+:-1,hl+:${DVC_COLOR_ACTIVE},pointer:${DVC_COLOR_ACTIVE},header:#7b8496,marker:${DVC_COLOR_ACTIVE},spinner:${DVC_COLOR_ACTIVE},prompt:${DVC_COLOR_ACTIVE},gutter:-1,label:${DVC_COLOR_BORDER},bg:-1,preview-bg:-1"
SEP=$'\t|\t'

C_GREEN="\033[38;2;20;226;26m"
C_GREY="\033[38;2;123;132;150m"
C_DIM="\033[38;2;51;51;51m"
C_WHITE="\033[38;2;220;220;220m"
C_BRIGHT="\033[38;2;255;255;255m"
C_RESET="\033[0m"

fake_list() {
    # ── claude-work (attached) ─────────────────────────────────────────────
    printf "${C_BRIGHT}󰊠 claude-work${C_RESET}  ${C_GREY}3 windows${C_RESET} ${C_GREEN}●${C_RESET}${SEP}session:claude-work\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} console${C_RESET}  ${C_GREY}claude-work:0  claude  ~/projects/Da_Vinci_Console${C_RESET} ${C_GREEN}✦${C_RESET}${SEP}window:claude-work:0\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} editor${C_RESET}  ${C_GREY}claude-work:1  nvim  ~/projects/Da_Vinci_Console${C_RESET}${SEP}window:claude-work:1\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} shell${C_RESET}  ${C_GREY}claude-work:2  zsh  ~/projects/Da_Vinci_Console${C_RESET}${SEP}window:claude-work:2\n"
    # ── dev-api ────────────────────────────────────────────────────────────
    printf "${C_BRIGHT}󰑮 dev-api${C_RESET}  ${C_GREY}4 windows${C_RESET}${SEP}session:dev-api\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} server${C_RESET}  ${C_GREY}dev-api:0  python  ~/projects/api${C_RESET} ${C_GREEN}✦${C_RESET}${SEP}window:dev-api:0\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} logs${C_RESET}  ${C_GREY}dev-api:1  zsh  ~/projects/api${C_RESET}${SEP}window:dev-api:1\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} tests${C_RESET}  ${C_GREY}dev-api:2  zsh  ~/projects/api${C_RESET}${SEP}window:dev-api:2\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} editor${C_RESET}  ${C_GREY}dev-api:3  nvim  ~/projects/api${C_RESET}${SEP}window:dev-api:3\n"
    # ── lazygit ────────────────────────────────────────────────────────────
    printf "${C_BRIGHT} lazygit${C_RESET}  ${C_GREY}1 window${C_RESET}${SEP}session:lazygit\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} lazygit${C_RESET}  ${C_GREY}lazygit:0  lazygit  ~/projects${C_RESET} ${C_GREEN}✦${C_RESET}${SEP}window:lazygit:0\n"
    # ── codex ──────────────────────────────────────────────────────────────
    printf "${C_BRIGHT}󰆍 codex${C_RESET}  ${C_GREY}2 windows${C_RESET}${SEP}session:codex\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE}󰆍 codex${C_RESET}  ${C_GREY}codex:0  node  ~/projects/codex${C_RESET} ${C_GREEN}✦${C_RESET}${SEP}window:codex:0\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} shell${C_RESET}  ${C_GREY}codex:1  zsh  ~${C_RESET}${SEP}window:codex:1\n"
    # ── docker-infra ───────────────────────────────────────────────────────
    printf "${C_BRIGHT} docker-infra${C_RESET}  ${C_GREY}2 windows${C_RESET}${SEP}session:docker-infra\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} lazydocker${C_RESET}  ${C_GREY}docker-infra:0  lazydocker  ~${C_RESET} ${C_GREEN}✦${C_RESET}${SEP}window:docker-infra:0\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} shell${C_RESET}  ${C_GREY}docker-infra:1  zsh  ~${C_RESET}${SEP}window:docker-infra:1\n"
    # ── odoo-dev ───────────────────────────────────────────────────────────
    printf "${C_BRIGHT} odoo-dev${C_RESET}  ${C_GREY}3 windows${C_RESET}${SEP}session:odoo-dev\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} server${C_RESET}  ${C_GREY}odoo-dev:0  python  ~/projects/odoo${C_RESET} ${C_GREEN}✦${C_RESET}${SEP}window:odoo-dev:0\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} editor${C_RESET}  ${C_GREY}odoo-dev:1  nvim  ~/projects/odoo${C_RESET}${SEP}window:odoo-dev:1\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} psql${C_RESET}  ${C_GREY}odoo-dev:2  zsh  ~/projects/odoo${C_RESET}${SEP}window:odoo-dev:2\n"
    # ── btop ───────────────────────────────────────────────────────────────
    printf "${C_BRIGHT} btop${C_RESET}  ${C_GREY}1 window${C_RESET}${SEP}session:btop\n"
    printf "  ${C_DIM}╰─${C_RESET} ${C_WHITE} btop${C_RESET}  ${C_GREY}btop:0  btop  ~${C_RESET} ${C_GREEN}✦${C_RESET}${SEP}window:btop:0\n"
}

FAKE_PREVIEW='
target={-1}
type="${target%%:*}"
rest="${target#*:}"
if [ "$type" = "session" ]; then
    printf "\033[38;2;20;226;26m%s\033[0m\n\n" "$rest"
    printf "  0. console  (claude)\n"
    printf "  1. editor  (nvim)  ✦\n"
    printf "  2. shell  (zsh)\n"
    printf "\n\033[38;2;51;51;51m─────────────────────────────\033[0m\n"
    printf " ~/projects/Da_Vinci_Console\n"
    printf " ❯ bash da-vinci-console.sh\n"
    printf "  [demo mode — no real tmux sessions]\n"
elif [ "$type" = "window" ]; then
    printf "%s\n\n" "$rest"
    printf "  0. console  (claude)\n"
    printf "  1. editor  (nvim)  ✦\n"
    printf "\n\033[38;2;51;51;51m─────────────────────────────\033[0m\n"
    printf " ~/projects/Da_Vinci_Console\n"
    printf " ❯ nvim README.md\n"
fi
'

HEADER="  Enter switch  •  ^J jump  •  ^W windows  •  ^S sessions  •  ^D kill  •  ^/ preview  •  alt-↑↓ scroll"

fake_list | fzf \
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
    --preview-window 'right:50%' \
    --preview "$FAKE_PREVIEW" \
    > /dev/null

echo "(demo — no action taken)"
