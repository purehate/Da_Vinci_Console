#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"
source "$ROOT/lib/dvc/item_model.sh"
source "$ROOT/lib/dvc/state.sh"
source "$ROOT/lib/dvc/rank.sh"
source "$ROOT/lib/dvc/render.sh"

test_query_match_beats_unrelated_live_item() {
  local api_row scratch_row ranked
  api_row="$(dvc_item_emit "workspace" "workspace:/tmp/api" "api" "api /tmp/api" "/tmp/api" "Projects" "workspace:/tmp/api" "live=0" "0")"
  scratch_row="$(dvc_item_emit "session" "session:scratch" "scratch" "scratch shell" "" "Live" "scratch" "attached=1" "0")"

  ranked="$(printf '%s\n%s\n' "$api_row" "$scratch_row" | dvc_rank_items "api" "/tmp")"
  assert_contains $'workspace\tworkspace:/tmp/api' "$(printf '%s\n' "$ranked" | head -n 1)"
}

test_pin_boost_moves_equal_matches_up() {
  local tmpdir row_a row_b ranked
  tmpdir="$(mktemp -d)"
  XDG_CACHE_HOME="$tmpdir/cache"
  HOME="$tmpdir/home"
  dvc_set_pin "workspace:/tmp/api" 1

  row_a="$(dvc_item_emit "workspace" "workspace:/tmp/api" "api" "api /tmp/api" "/tmp/api" "Projects" "workspace:/tmp/api" "live=0" "0")"
  row_b="$(dvc_item_emit "workspace" "workspace:/tmp/app" "app" "app /tmp/app" "/tmp/app" "Projects" "workspace:/tmp/app" "live=0" "0")"

  ranked="$(printf '%s\n%s\n' "$row_a" "$row_b" | dvc_rank_items "" "/tmp")"
  assert_contains $'workspace\tworkspace:/tmp/api' "$(printf '%s\n' "$ranked" | head -n 1)"
}

test_render_default_view_inserts_group_headers() {
  local rows rendered
  rows="$(printf '%s\n%s\n' \
    "$(dvc_item_emit "session" "session:main" "main" "main" "" "Live" "main" "attached=1" "50")" \
    "$(dvc_item_emit "workspace" "workspace:/tmp/api" "api" "api" "/tmp/api" "Projects" "workspace:/tmp/api" "live=0" "40")")"
  rendered="$(printf '%s\n' "$rows" | dvc_render_grouped_view)"

  assert_contains $'sep:Live' "$rendered"
  assert_contains $'sep:Projects' "$rendered"
}

test_query_match_beats_unrelated_live_item
test_pin_boost_moves_equal_matches_up
test_render_default_view_inserts_group_headers
printf 'ok - rank_render\n'
