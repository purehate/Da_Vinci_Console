#!/usr/bin/env bash
set -euo pipefail

dvc_render_grouped_view() {
  local row group label
  local live_rows="" project_rows="" utility_rows="" other_rows=""

  while IFS= read -r row; do
    group="$(dvc_item_field "$row" group)"
    case "$group" in
      Live) live_rows+="${row}"$'\n' ;;
      Projects) project_rows+="${row}"$'\n' ;;
      Utilities) utility_rows+="${row}"$'\n' ;;
      *) other_rows+="${row}"$'\n' ;;
    esac
  done

  dvc_render_group_block() {
    local block_group="$1"
    local block_rows="$2"
    [[ -n "$block_rows" ]] || return 0

    printf '── %s\t|\tsep:%s\n' "$block_group" "$block_group"
    while IFS= read -r row; do
      [[ -n "$row" ]] || continue
      label="$(dvc_item_field "$row" label)"
      printf '%s\t|\t%s\n' "$label" "$row"
    done <<<"$block_rows"
  }

  dvc_render_group_block "Live" "$live_rows"
  dvc_render_group_block "Projects" "$project_rows"
  dvc_render_group_block "Utilities" "$utility_rows"
  dvc_render_group_block "Other" "$other_rows"
}
