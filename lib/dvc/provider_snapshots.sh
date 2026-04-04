#!/usr/bin/env bash
set -euo pipefail

dvc_snapshot_dir() {
  printf '%s/.config/tmux/snapshots\n' "$HOME"
}

dvc_snapshot_items() {
  local snapshot_dir="${1:-$(dvc_snapshot_dir)}"
  [[ -d "$snapshot_dir" ]] || return 0

  find "$snapshot_dir" -maxdepth 1 -name '*.snapshot' -type f | sort | while IFS= read -r file; do
    local name
    name="$(basename "$file" .snapshot)"
    dvc_item_emit "snapshot" "snapshot:${name}" "$name" "$name snapshot" "" "Utilities" "$name" "provider=snapshot" "0"
  done
}

dvc_snapshot_restore() {
  local snapshot_name="$1"
  local file session_name first

  file="$(dvc_snapshot_dir)/${snapshot_name}.snapshot"
  [[ -f "$file" ]] || return 1

  session_name="$(grep '^session=' "$file" | cut -d= -f2)"
  first=1

  tmux new-session -d -s "$session_name" 2>/dev/null || true
  while IFS='|' read -r _ window_name window_path window_command; do
    if [[ "$first" == "1" ]]; then
      tmux rename-window -t "${session_name}:0" "$window_name" 2>/dev/null
      tmux send-keys -t "${session_name}:0" "cd $(printf '%q' "$window_path")" Enter "$window_command" Enter 2>/dev/null
      first=0
    else
      tmux new-window -t "${session_name}:" -n "$window_name" -c "$window_path" "$window_command" 2>/dev/null
    fi
  done < <(grep '^window|' "$file")

  tmux switch-client -t "$session_name" 2>/dev/null
}
