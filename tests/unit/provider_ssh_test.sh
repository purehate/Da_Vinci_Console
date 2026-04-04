#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"
source "$ROOT/lib/dvc/item_model.sh"
source "$ROOT/lib/dvc/provider_ssh.sh"

test_ssh_provider_skips_wildcards() {
  local rows
  rows="$(dvc_ssh_items_from_config "$ROOT/tests/fixtures/ssh/config")"

  assert_contains $'ssh\tssh:prod' "$rows"
  assert_contains $'ssh\tssh:github' "$rows"
}

test_ssh_provider_skips_wildcards
printf 'ok - provider_ssh\n'
