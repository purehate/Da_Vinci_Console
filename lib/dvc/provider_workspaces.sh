#!/usr/bin/env bash
set -euo pipefail

dvc_cached_workspace_paths() {
  local cache_file
  cache_file="$(dvc_workspace_cache_file)"
  [[ -f "$cache_file" ]] || return 0

  cut -f1 "$cache_file"
}

dvc_tmux_workspace_paths() {
  :
}

dvc_sesh_workspace_paths() {
  local sesh_bin="${SESH:-sesh}"
  command -v "$sesh_bin" >/dev/null 2>&1 || return 0
  "$sesh_bin" list -c -z 2>/dev/null || :
}

dvc_zoxide_workspace_paths() {
  command -v zoxide >/dev/null 2>&1 || return 0
  zoxide query -l 2>/dev/null || :
}

dvc_seed_workspace_paths() {
  local current_dir="${1:-}"

  [[ -n "$current_dir" && -d "$current_dir" ]] && printf '%s\n' "$current_dir"
  dvc_cached_workspace_paths
  dvc_tmux_workspace_paths
  dvc_sesh_workspace_paths
  dvc_zoxide_workspace_paths
}

dvc_discover_workspace_paths() {
  local root
  local IFS=':'

  for root in ${SESH_REPO_DIRS:-}; do
    root="${root/#\~/$HOME}"
    [[ -d "$root" ]] || continue
    find "$root" -maxdepth 3 -name .git -type d 2>/dev/null | sed 's|/.git$||'
  done
}

dvc_list_workspace_paths() {
  local current_dir="${1:-}"

  if [[ -n "${SESH_REPO_DIRS:-}" ]]; then
    dvc_discover_workspace_paths | awk '!seen[$0]++'
  else
    dvc_seed_workspace_paths "$current_dir" | awk 'NF && !seen[$0]++'
  fi
}

dvc_workspace_items() {
  local current_dir="${1:-}"

  while IFS= read -r path; do
    [[ -d "$path" ]] || continue

    local real_path label id
    real_path="$(dvc_realpath "$path")"
    label="$(basename "$real_path")"
    id="$(dvc_workspace_id "$real_path")"

    dvc_item_emit "workspace" "$id" "$label" "$label $real_path" "$real_path" "Projects" "$id" "live=0" "0"
  done < <(dvc_list_workspace_paths "$current_dir")
}
