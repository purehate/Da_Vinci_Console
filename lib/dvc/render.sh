#!/usr/bin/env bash
set -euo pipefail

dvc_render_grouped_view() {
  local previous_group=""
  local row group label

  while IFS= read -r row; do
    group="$(dvc_item_field "$row" group)"
    label="$(dvc_item_field "$row" label)"

    if [[ "$group" != "$previous_group" ]]; then
      printf '── %s\t|\tsep:%s\n' "$group" "$group"
      previous_group="$group"
    fi

    printf '%s\t|\t%s\n' "$label" "$row"
  done
}
