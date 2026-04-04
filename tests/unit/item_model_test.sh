#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"
source "$ROOT/lib/dvc/item_model.sh"

test_workspace_ids_are_path_backed() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/project"
  ln -s "$tmpdir/project" "$tmpdir/project-link"

  assert_eq "workspace:${tmpdir}/project" "$(dvc_workspace_id "$tmpdir/project-link")"
}

test_session_and_window_ids_are_stable() {
  assert_eq "session:main" "$(dvc_session_id "main")"
  assert_eq "window:main:2" "$(dvc_window_id "main" "2")"
}

test_item_fields_round_trip() {
  local row
  row="$(dvc_item_emit "workspace" "workspace:/tmp/api" "api" "api project" "/tmp/api" "Projects" "workspace:/tmp/api" "live=0" "0")"

  assert_eq "workspace" "$(dvc_item_field "$row" kind)"
  assert_eq "workspace:/tmp/api" "$(dvc_item_field "$row" id)"
  assert_eq "/tmp/api" "$(dvc_item_field "$row" path)"
  assert_eq "Projects" "$(dvc_item_field "$row" group)"
}

test_workspace_ids_are_path_backed
test_session_and_window_ids_are_stable
test_item_fields_round_trip
printf 'ok - item_model\n'
