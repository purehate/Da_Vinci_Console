#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"
source "$ROOT/lib/dvc/item_model.sh"
source "$ROOT/lib/dvc/provider_tmux.sh"
source "$ROOT/lib/dvc/merge.sh"

test_tmux_workspace_paths_are_extracted_from_window_stream() {
  local windows_file paths
  windows_file="$ROOT/tests/fixtures/tmux/windows.txt"
  paths="$(dvc_tmux_workspace_paths_from_stream "$windows_file")"

  assert_contains "/tmp/work/api" "$paths"
  assert_contains "/tmp/work/blog" "$paths"
}

test_workspace_items_absorb_live_targets_by_path() {
  local workspace_file live_file merged
  workspace_file="$(mktemp)"
  live_file="$(mktemp)"

  dvc_item_emit "workspace" "workspace:/tmp/work/api" "api" "api /tmp/work/api" "/tmp/work/api" "Projects" "workspace:/tmp/work/api" "live=0" "0" >"$workspace_file"
  dvc_item_emit "window" "window:main:1" "editor" "editor main api" "/tmp/work/api" "Live" "main:1" "attached=1" "0" >"$live_file"
  dvc_item_emit "session" "session:scratch" "scratch" "scratch" "" "Live" "scratch" "attached=0" "0" >>"$live_file"

  merged="$(dvc_merge_workspace_and_live_items "$workspace_file" "$live_file")"

  assert_contains $'workspace\tworkspace:/tmp/work/api\tapi\tapi /tmp/work/api\t/tmp/work/api\tLive\tmain:1\tlive=1' "$merged"
  assert_contains $'session\tsession:scratch' "$merged"
}

test_tmux_workspace_paths_are_extracted_from_window_stream
test_workspace_items_absorb_live_targets_by_path
printf 'ok - live_merge\n'
