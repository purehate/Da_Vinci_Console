#!/usr/bin/env bash
set -euo pipefail

dvc_guard_destructive_action() {
  local action="$1"
  local row="$2"
  local force="${3:-0}"
  local kind meta

  kind="$(dvc_item_field "$row" kind)"
  meta="$(dvc_item_field "$row" meta)"

  [[ "$action" != "kill" ]] && {
    printf 'allowed\n'
    return
  }

  [[ "$kind" != "session" ]] && {
    printf 'allowed\n'
    return
  }

  [[ "$meta" == *"attached=1"* && "$force" != "1" ]] && {
    printf 'blocked\n'
    return
  }

  printf 'allowed\n'
}

dvc_validate_batch_action() {
  local action="$1"
  local row kind

  while IFS= read -r row; do
    kind="$(dvc_item_field "$row" kind)"
    if [[ "$action" == "kill" && "$kind" != "session" && "$kind" != "window" ]]; then
      printf 'batch action %s does not allow kind %s\n' "$action" "$kind" >&2
      return 1
    fi
  done
}

dvc_dispatch_primary_action() {
  local row="$1"
  local kind target label path meta

  kind="$(dvc_item_field "$row" kind)"
  target="$(dvc_item_field "$row" target)"
  label="$(dvc_item_field "$row" label)"
  path="$(dvc_item_field "$row" path)"
  meta="$(dvc_item_field "$row" meta)"

  case "$kind" in
    workspace)
      if [[ "$meta" == *"live=1"* ]]; then
        tmux switch-client -t "$target"
      else
        local session_name checksum
        checksum="$(printf '%s' "$path" | cksum | awk '{print $1}')"
        session_name="${label:-workspace}-${checksum:0:6}"
        tmux new-session -d -s "$session_name" -c "$path"
        tmux switch-client -t "$session_name"
      fi
      ;;
    window)
      tmux switch-client -t "$target"
      ;;
    session)
      tmux switch-client -t "$target"
      ;;
    ssh)
      tmux new-window -n "$label" "ssh $(printf '%q' "$label")"
      ;;
    snapshot)
      dvc_snapshot_restore "$label"
      ;;
    *)
      printf 'unsupported kind: %s\n' "$kind" >&2
      return 1
      ;;
  esac
}

dvc_dispatch_primary_batch() {
  local row

  while IFS= read -r row; do
    [[ -z "$row" || "$row" == sep:* || "$row" == skip:* ]] && continue
    dvc_dispatch_primary_action "$row"
  done
}

dvc_toggle_pin_action() {
  local row="$1"
  local id pinned

  id="$(dvc_item_field "$row" id)"
  pinned="$(dvc_is_pinned "$id")"

  if [[ "$pinned" == "1" ]]; then
    dvc_set_pin "$id" 0
  else
    dvc_set_pin "$id" 1
  fi
}
