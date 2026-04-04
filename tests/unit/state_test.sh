#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"
source "$ROOT/lib/dvc/state.sh"

test_state_dir_uses_xdg_cache_home() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  XDG_CACHE_HOME="$tmpdir/cache"
  HOME="$tmpdir/home"

  assert_eq "$tmpdir/cache/da-vinci-console" "$(dvc_state_dir)"
}

test_record_open_updates_count_and_timestamp() {
  local tmpdir id usage_file row
  tmpdir="$(mktemp -d)"
  XDG_CACHE_HOME="$tmpdir/cache"
  HOME="$tmpdir/home"
  id="workspace:/tmp/api"

  dvc_record_open "$id" 100
  dvc_record_open "$id" 125

  usage_file="$(dvc_usage_file)"
  row="$(grep "^${id}" "$usage_file")"

  assert_contains $'\t125\t2' "$row"
}

test_pin_round_trip() {
  local tmpdir id
  tmpdir="$(mktemp -d)"
  XDG_CACHE_HOME="$tmpdir/cache"
  HOME="$tmpdir/home"
  id="workspace:/tmp/api"

  dvc_set_pin "$id" 1
  assert_eq "1" "$(dvc_is_pinned "$id")"

  dvc_set_pin "$id" 0
  assert_eq "0" "$(dvc_is_pinned "$id")"
}

test_state_dir_uses_xdg_cache_home
test_record_open_updates_count_and_timestamp
test_pin_round_trip
printf 'ok - state\n'
