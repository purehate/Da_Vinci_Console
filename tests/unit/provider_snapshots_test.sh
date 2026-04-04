#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"
source "$ROOT/lib/dvc/item_model.sh"
source "$ROOT/lib/dvc/provider_snapshots.sh"

test_snapshot_provider_lists_snapshot_items() {
  local rows
  rows="$(dvc_snapshot_items "$ROOT/tests/fixtures/snapshots")"

  assert_contains $'snapshot\tsnapshot:demo' "$rows"
}

test_snapshot_provider_lists_snapshot_items
printf 'ok - provider_snapshots\n'
