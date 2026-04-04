#!/usr/bin/env bash
set -euo pipefail

dvc_preview_row() {
  local row="$1"
  local kind path target label

  kind="$(dvc_item_field "$row" kind)"
  path="$(dvc_item_field "$row" path)"
  target="$(dvc_item_field "$row" target)"
  label="$(dvc_item_field "$row" label)"

  case "$kind" in
    workspace)
      printf 'Workspace: %s\nPath: %s\n' "$label" "$path"
      git -C "$path" log --oneline -5 2>/dev/null || printf 'no git preview available\n'
      ;;
    session|window)
      tmux capture-pane -p -t "$target" -S -20 2>/dev/null || printf 'preview unavailable\n'
      ;;
    ssh)
      awk -v host="$label" '
        BEGIN { active = 0 }
        /^[Hh]ost / {
          active = 0
          for (i = 2; i <= NF; i++) {
            if ($i == host) active = 1
          }
          next
        }
        active { print }
      ' "$HOME/.ssh/config" 2>/dev/null
      ;;
    snapshot)
      grep '^window|' "$(dvc_snapshot_dir)/${label}.snapshot" 2>/dev/null || :
      ;;
    *)
      printf 'preview unavailable\n'
      ;;
  esac
}
