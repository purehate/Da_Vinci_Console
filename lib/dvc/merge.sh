#!/usr/bin/env bash
set -euo pipefail

dvc_merge_workspace_and_live_items() {
  local workspace_file="$1"
  local live_file="$2"
  local row path
  declare -A workspace_rows=()

  while IFS= read -r row; do
    path="$(dvc_item_field "$row" path)"
    workspace_rows["$path"]="$row"
  done <"$workspace_file"

  while IFS= read -r row; do
    path="$(dvc_item_field "$row" path)"

    if [[ -n "$path" && -n "${workspace_rows[$path]:-}" ]]; then
      local workspace_row workspace_id workspace_label workspace_search target
      workspace_row="${workspace_rows[$path]}"
      workspace_id="$(dvc_item_field "$workspace_row" id)"
      workspace_label="$(dvc_item_field "$workspace_row" label)"
      workspace_search="$(dvc_item_field "$workspace_row" search)"
      target="$(dvc_item_field "$row" target)"

      dvc_item_emit "workspace" "$workspace_id" "$workspace_label" "$workspace_search" "$path" "Live" "$target" "live=1" "0"
      unset 'workspace_rows[$path]'
    else
      printf '%s\n' "$row"
    fi
  done <"$live_file"

  for path in "${!workspace_rows[@]}"; do
    printf '%s\n' "${workspace_rows[$path]}"
  done
}
