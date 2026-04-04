#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"

test_install_copies_runtime_libs() {
  local tmpdir dest
  tmpdir="$(mktemp -d)"
  dest="$tmpdir/tmux-config"

  (
    cd "$ROOT"
    HOME="$tmpdir/home" ./install.sh "$dest" >/dev/null
  )

  [[ -x "$dest/sesh_picker.sh" ]] || {
    printf 'expected installed script to be executable\n' >&2
    return 1
  }

  [[ -f "$dest/lib/dvc/item_model.sh" ]] || {
    printf 'expected runtime lib item_model.sh to be installed\n' >&2
    return 1
  }

  [[ -f "$dest/lib/dvc/actions.sh" ]] || {
    printf 'expected runtime lib actions.sh to be installed\n' >&2
    return 1
  }
}

test_install_copies_runtime_libs
printf 'ok - install\n'
