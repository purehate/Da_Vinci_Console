#!/usr/bin/env bash
# agents_state.sh - one line per detected agent with its status light.
#
# Output (pipe-separated): name|session|window_index|window_name|pane_id|pid|light
#   light: ◐ focused (pane you're viewing), ● working (CPU grew), ○ idle
#
# Self-contained: reads tmux panes + processes directly. Used by the Da Vinci
# picker to annotate windows and render a herdr-style agents header.
set -u
CUR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$CUR_DIR/lib.sh"

CACHE="/tmp/tmux-agents-win.${UID}.cache"

declare -A cached
if [[ -f "$CACHE" ]]; then
  while read -r cp csec; do cached["$cp"]="$csec"; done < "$CACHE"
fi

CURRENT_PANE="$(tmux display-message -p '#{pane_id}' 2>/dev/null)"

utime_to_sec() {
  local t="$1" days=0 n a b c
  t="${t//[[:space:]]/}"
  if [[ "$t" == *-* ]]; then days="${t%%-*}"; t="${t#*-}"; fi
  t="${t%%.*}"
  n="${t//[^:]/}"
  case "${#n}" in
    1) IFS=: read -r a b <<< "$t"; echo $(( 10#$a * 60 + 10#$b + days * 86400 ));;
    2) IFS=: read -r a b c <<< "$t"; echo $(( 10#$a * 3600 + 10#$b * 60 + 10#$c + days * 86400 ));;
    *) echo 0;;
  esac
}

declare -A cur_secs
while IFS='|' read -r name sess widx wname paneid pid; do
  [[ -n "$name" ]] || continue
  light="○"
  if [[ "$paneid" == "$CURRENT_PANE" ]]; then
    light="◐"
  else
    us="$(utime_to_sec "$(ps -o utime= -p "$pid" 2>/dev/null)")"
    prev="${cached[$pid]:-}"
    if [[ -n "$prev" && -n "$us" && "$us" -gt "$prev" ]]; then
      light="●"
    fi
    cur_secs["$pid"]="$us"
  fi
  printf '%s|%s|%s|%s|%s|%s|%s\n' "$name" "$sess" "$widx" "$wname" "$paneid" "$pid" "$light"
done < <(agent_records)

# Persist this refresh's CPU baseline so the next call can diff against it.
: > "$CACHE"
for k in "${!cur_secs[@]}"; do
  printf '%s %s\n' "$k" "${cur_secs[$k]}" >> "$CACHE"
done
exit 0
