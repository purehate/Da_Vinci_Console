#!/usr/bin/env bash
# window_agent.sh <pane_id> - annotate a window pill with its running agent
# and a status light:
#
#   " | pi ●"   working  (CPU time grew since last refresh)
#   " | pi ○"   idle     (running but no recent CPU)
#   " | pi ◐"   focused  (this is the pane you're viewing)
#
# Used from window-status-format / window-status-current-format via:
#   #(bash .../window_agent.sh #{pane_id})
# Emits nothing when no agent runs in the pane, so the pill renders unchanged.
#
# The symbol inherits the pill's colour so it stays visible on both the normal
# and current-window pill backgrounds.

set -u
pane_id="${1:-}"
[[ -n "$pane_id" ]] || exit 0

CUR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$CUR_DIR/lib.sh"

CACHE="/tmp/tmux-agents-win.${UID}.cache"

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

root="$(tmux display-message -p -t "$pane_id" '#{pane_pid}' 2>/dev/null)"
[[ -n "$root" && "$root" != "0" ]] || exit 0
current="$(tmux display-message -p '#{pane_id}' 2>/dev/null)"

# One ps pass: parent -> children and pid -> command name.
declare -A child comm
p=""
pp=""
c=""
while read -r p pp c; do
  [[ "$p" =~ ^[0-9]+$ ]] || continue
  [[ "$pp" =~ ^[0-9]+$ ]] || pp=0
  child["$pp"]="${child["$pp"]:-} $p"
  comm["$p"]="$c"
done < <(ps -axo pid=,ppid=,comm=)

# BFS from the pane's top-level pid, looking for a known agent.
declare -A seen
queue=("$root")
agent=""
agent_pid=""
nodes=0
while (( ${#queue[@]} > 0 )); do
  cur="${queue[0]}"
  queue=("${queue[@]:1}")
  [[ -n "${seen[$cur]:-}" ]] && continue
  seen["$cur"]=1
  (( nodes++ ))
  (( nodes > 500 )) && break
  cname="${comm[$cur]:-}"
  if [[ -n "$cname" ]] && _is_agent "$cname"; then
    agent="${cname##*/}"
    agent_pid="$cur"
    break
  fi
  queue+=(${child[$cur]:-})
done

[[ -n "$agent" ]] || exit 0

# Status light: focused > working > idle.
light="○"
if [[ "$pane_id" == "$current" ]]; then
  light="◐"
else
  us="$(utime_to_sec "$(ps -o utime= -p "$agent_pid" 2>/dev/null)")"
  us="${us//[^0-9]/}"
  [[ -n "$us" ]] || us=0
  prev=""
  if [[ -f "$CACHE" ]]; then
    prev="$(awk -v p="$agent_pid" '$1==p{v=$2} END{print v}' "$CACHE")"
  fi
  prev="${prev//[^0-9]/}"
  if [[ -n "$prev" && "$us" -gt "${prev:-0}" ]]; then
    light="$(working_light)"
  fi
  # Persist this agent's CPU baseline.
  : > "$CACHE.tmp"
  if [[ -s "$CACHE" ]]; then grep -v "^$agent_pid " "$CACHE" > "$CACHE.tmp"; fi
  printf '%s %s\n' "$agent_pid" "$us" >> "$CACHE.tmp"
  mv "$CACHE.tmp" "$CACHE"
fi

printf ' | %s %s' "$agent" "$light"
exit 0
