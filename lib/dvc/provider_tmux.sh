#!/usr/bin/env bash
set -euo pipefail

dvc_tmux_workspace_paths_from_stream() {
  local windows_file="$1"
  awk -F '|' '{ print $6 }' "$windows_file" | awk 'NF && !seen[$0]++'
}

dvc_tmux_workspace_paths() {
  tmux list-windows -a -F '#{session_name}|#{window_index}|#{window_name}|#{pane_current_command}|#{window_active}|#{pane_current_path}' 2>/dev/null \
    | awk -F '|' '{ print $6 }' \
    | awk 'NF && !seen[$0]++'
}

dvc_live_items_from_tmux_stream() {
  local sessions_file="$1"
  local windows_file="$2"

  while IFS='|' read -r session_name _windows attached _activity; do
    dvc_item_emit "session" "$(dvc_session_id "$session_name")" "$session_name" "$session_name" "" "Live" "$session_name" "attached=${attached}" "0"
  done <"$sessions_file"

  while IFS='|' read -r session_name window_index window_name command active path; do
    dvc_item_emit "window" "$(dvc_window_id "$session_name" "$window_index")" "$window_name" "$session_name $window_name $command $path" "$path" "Live" "${session_name}:${window_index}" "active=${active}" "0"
  done <"$windows_file"
}

dvc_live_items() {
  local sessions_file windows_file
  sessions_file="$(mktemp)"
  windows_file="$(mktemp)"

  tmux list-sessions -F '#{session_name}|#{session_windows}|#{?session_attached,1,0}|#{session_activity}' 2>/dev/null >"$sessions_file"
  tmux list-windows -a -F '#{session_name}|#{window_index}|#{window_name}|#{pane_current_command}|#{window_active}|#{pane_current_path}' 2>/dev/null >"$windows_file"

  dvc_live_items_from_tmux_stream "$sessions_file" "$windows_file"
}
