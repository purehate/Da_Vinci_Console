#!/usr/bin/env bash
set -euo pipefail

dvc_realpath() {
  (
    cd "$1" >/dev/null 2>&1
    pwd -P
  )
}

dvc_workspace_id() {
  printf 'workspace:%s\n' "$(dvc_realpath "$1")"
}

dvc_session_id() {
  printf 'session:%s\n' "$1"
}

dvc_window_id() {
  printf 'window:%s:%s\n' "$1" "$2"
}

dvc_item_emit() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "${9:-0}"
}

dvc_item_field() {
  local row="$1"
  local field="$2"
  local index

  case "$field" in
    kind) index=1 ;;
    id) index=2 ;;
    label) index=3 ;;
    search) index=4 ;;
    path) index=5 ;;
    group) index=6 ;;
    target) index=7 ;;
    meta) index=8 ;;
    score) index=9 ;;
    *)
      printf 'unknown field: %s\n' "$field" >&2
      return 1
      ;;
  esac

  awk -F '\t' -v idx="$index" '{ print $idx }' <<<"$row"
}
