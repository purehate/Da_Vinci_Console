#!/usr/bin/env bash
# tmux-agents: jump to a running agent's pane.
# Bound to <prefix> + a. Lists detected agents; picking one switches the
# current client to that session and focuses the agent's pane.

set -u
CUR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$CUR_DIR/lib.sh"

declare -a lines
while IFS='|' read -r name sess widx wname paneid pid; do
  [[ -n "$name" ]] || continue
  loc="$(printf '%s' "$wname" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  lines+=( "${name}|${sess}|${widx}:${loc}	${paneid}" )
done < <(agent_records)

if (( ${#lines[@]} == 0 )); then
  tmux display-message "tmux-agents: no agents detected"
  exit 0
fi

pick=""
paneid=""
sess=""
rest=""
if command -v fzf >/dev/null 2>&1; then
  pick="$(printf '%s\n' "${lines[@]}" | fzf --no-multi --layout=reverse --prompt='agent > ')"
  [[ -n "$pick" ]] || exit 0
  paneid="${pick##*$'\t'}"
  rest="${pick%%$'\t'*}"
  IFS='|' read -r _ sess _ <<< "$rest"
else
  tmux display-message "tmux-agents: install fzf for an interactive picker"
  exit 0
fi

# Move this client to the agent's session and focus its pane.
tmux switch-client -t "$sess" 2>/dev/null
tmux select-pane -t "$paneid"
