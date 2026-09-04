#!/usr/bin/env bash
# tmux-agents: shared agent detection logic.
# Exposes:
#   AGENT_LABELS  - space-separated list of agent command names to watch
#   agent_records - prints one line per detected agent:
#                   name|session|window_index|window_name|pane_id|pid
#
# Agents are detected by walking each process's ancestor chain up to a tmux
# pane's top-level PID. This works whether the agent is a child of the pane
# shell or the pane command itself.

# Space-separated list of agent command names to watch. Override with $TMUX_AGENTS.
AGENT_LABELS="${TMUX_AGENTS:-pi claude codex opencode gemini aider cursor-agent grok continue qwen-code}"

_is_agent() {
  local c="$1" a
  c="${c##*/}"   # ps comm may be a full path (e.g. .../bin/codex)
  for a in $AGENT_LABELS; do
    [[ "$c" == "$a" ]] && return 0
  done
  return 1
}

agent_records() {
  local panes ps pid ppid comm cur guard info line
  panes="$(tmux list-panes -a -F '#{pane_pid}|#{session_name}|#{window_index}|#{window_name}|#{pane_id}' 2>/dev/null)"

  declare -A pane_by_pid
  local ppid sess widx wname paneid
  while IFS='|' read -r ppid sess widx wname paneid; do
    [[ -n "$ppid" ]] && pane_by_pid["$ppid"]="$sess|$widx|$wname|$paneid"
  done <<< "$panes"

  declare -A ppid_by_pid comm_by_pid
  while read -r pid ppid comm; do
    ppid_by_pid["$pid"]="$ppid"
    comm_by_pid["$pid"]="$comm"
  done < <(ps -axo pid=,ppid=,comm=)

  local out=() name
  for pid in "${!comm_by_pid[@]}"; do
    if _is_agent "${comm_by_pid[$pid]}"; then
      cur="$pid"
      guard=0
      while (( guard < 60 )); do
        info="${pane_by_pid[$cur]:-}"
        if [[ -n "$info" ]]; then
          name="${comm_by_pid[$pid]##*/}"
          out+=( "${name}|${info}|${pid}" )
          break
        fi
        ppid="${ppid_by_pid[$cur]:-}"
        if [[ -z "$ppid" || "$ppid" == "$cur" || "$ppid" == "0" ]]; then break; fi
        cur="$ppid"
        (( guard++ ))
      done
    fi
  done

  # One entry per pane (dedupe nested/multiple agent processes in one pane).
  declare -A seen
  local rest
  for line in "${out[@]}"; do
    name="${line%%|*}"
    rest="${line#*|}"
    paneid="${rest##*|}"
    if [[ -z "${seen[$paneid]:-}" ]]; then
      seen[$paneid]=1
      printf '%s\n' "$line"
    fi
  done
}

# working_light - animated "working" indicator (quarter-spinner).
# Phase rotates with the wall-clock so any refresh shows the next step.
# Uses ◓◑◒◔ so ◐ stays reserved for the focused state.
working_light() {
    local s=$(( $(date +%s) / 2 % 4 ))
    case "$s" in
        0) printf '◓' ;; 1) printf '◑' ;; 2) printf '◒' ;; 3) printf '◔' ;;
    esac
}

# agent_color <name> - brand colour for an agent (raw ANSI fg, or empty).
# Lets the picker/preview tint each agent's name its own brand colour.
agent_color() {
    case "${1,,}" in
        pi*|cursor*)         printf '\033[38;2;20;226;26m'  ;; # green
        claude*)             printf '\033[38;2;232;158;66m'  ;; # orange
        codex*)              printf '\033[38;2;255;123;114m' ;; # red
        gemini*)             printf '\033[38;2;88;166;255m'  ;; # blue
        aider*)              printf '\033[38;2;247;118;186m' ;; # pink
        opencode*)           printf '\033[38;2;51;204;204m'  ;; # teal
        grok*)               printf '\033[38;2;188;140;255m' ;; # purple
        qwen*)               printf '\033[38;2;51;204;255m'  ;; # cyan
        continue*)           printf '\033[38;2;139;148;158m' ;; # gray
        *)                   printf '' ;;
    esac
}
