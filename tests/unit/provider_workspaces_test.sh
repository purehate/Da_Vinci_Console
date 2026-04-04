#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"
source "$ROOT/lib/dvc/item_model.sh"
source "$ROOT/lib/dvc/state.sh"
source "$ROOT/lib/dvc/provider_workspaces.sh"

test_configured_roots_are_scanned() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/work/api/.git" "$tmpdir/work/web/.git" "$tmpdir/current"
  SESH_REPO_DIRS="$tmpdir/work"

  local paths
  paths="$(dvc_list_workspace_paths "$tmpdir/current")"

  assert_contains "$tmpdir/work/api" "$paths"
  assert_contains "$tmpdir/work/web" "$paths"
}

test_seed_mode_uses_cache_and_runtime_sources() {
  local tmpdir paths
  tmpdir="$(mktemp -d)"
  HOME="$tmpdir/home"
  XDG_CACHE_HOME="$tmpdir/cache"
  mkdir -p "$tmpdir/current" "$tmpdir/from-cache" "$tmpdir/from-tmux"
  mkdir -p "$(dirname "$(dvc_workspace_cache_file)")"
  printf '%s\tapi\tmain\t0\tbash\t1\n' "$tmpdir/from-cache" >"$(dvc_workspace_cache_file)"

  unset SESH_REPO_DIRS
  find() { printf 'find should not run in seed mode\n' >&2; return 99; }
  dvc_tmux_workspace_paths() { printf '%s\n' "$tmpdir/from-tmux"; }
  dvc_sesh_workspace_paths() { :; }
  dvc_zoxide_workspace_paths() { :; }

  paths="$(dvc_list_workspace_paths "$tmpdir/current")"
  assert_contains "$tmpdir/current" "$paths"
  assert_contains "$tmpdir/from-cache" "$paths"
  assert_contains "$tmpdir/from-tmux" "$paths"
}

test_configured_roots_are_scanned
test_seed_mode_uses_cache_and_runtime_sources
printf 'ok - provider_workspaces\n'
