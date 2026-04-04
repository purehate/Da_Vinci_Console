#!/usr/bin/env bash
set -euo pipefail

dvc_ssh_items_from_config() {
  local config_file="${1:-$HOME/.ssh/config}"
  [[ -f "$config_file" ]] || return 0

  awk '/^[Hh]ost / { for (i = 2; i <= NF; i++) print $i }' "$config_file" \
    | while IFS= read -r host; do
        [[ -z "$host" || "$host" == *"*"* || "$host" == *"?"* ]] && continue
        dvc_item_emit "ssh" "ssh:${host}" "$host" "$host ssh" "" "Utilities" "$host" "provider=ssh" "0"
      done
}
