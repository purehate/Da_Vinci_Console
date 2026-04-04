#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"
source "$ROOT/lib/dvc/item_model.sh"
source "$ROOT/lib/dvc/actions.sh"

test_workspace_primary_action_prefers_live_target() {
  local row
  row="$(dvc_item_emit "workspace" "workspace:/tmp/api" "api" "api" "/tmp/api" "Live" "main:1" "live=1" "10")"

  tmux() { printf 'switch-client:%s\n' "$*"; }
  assert_contains 'switch-client:switch-client -t main:1' "$(dvc_dispatch_primary_action "$row")"
}

test_multi_kill_rejects_non_killable_kinds() {
  local rows result
  rows="$(printf '%s\n%s\n' \
    "$(dvc_item_emit "window" "window:main:1" "editor" "editor" "/tmp/api" "Live" "main:1" "active=1" "0")" \
    "$(dvc_item_emit "workspace" "workspace:/tmp/api" "api" "api" "/tmp/api" "Projects" "workspace:/tmp/api" "live=0" "0")")"

  if result="$(printf '%s\n' "$rows" | dvc_validate_batch_action "kill" 2>&1)"; then
    printf 'expected validate_batch_action to fail\n' >&2
    return 1
  fi

  assert_contains 'workspace' "$result"
}

test_attached_session_kill_requires_force() {
  local row
  row="$(dvc_item_emit "session" "session:main" "main" "main" "" "Live" "main" "attached=1" "0")"

  assert_eq "blocked" "$(dvc_guard_destructive_action "kill" "$row" "0")"
  assert_eq "allowed" "$(dvc_guard_destructive_action "kill" "$row" "1")"
}

test_workspace_primary_action_prefers_live_target
test_multi_kill_rejects_non_killable_kinds
test_attached_session_kill_requires_force
printf 'ok - actions\n'
