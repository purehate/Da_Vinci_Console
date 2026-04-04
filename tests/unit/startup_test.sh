#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"

test_picker_startup_reaches_fzf() {
  local tmpdir stubbin logfile status
  tmpdir="$(mktemp -d)"
  stubbin="$tmpdir/bin"
  logfile="$tmpdir/fzf.log"

  mkdir -p "$stubbin" "$tmpdir/home" "$tmpdir/repos"

  cat > "$stubbin/fzf" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf 'called\n' > "$DVC_FZF_LOG"
exit 0
EOF
  chmod +x "$stubbin/fzf"

  cat > "$stubbin/sesh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$stubbin/sesh"

  status=0
  PATH="$stubbin:$PATH" \
  HOME="$tmpdir/home" \
  DVC_FZF_LOG="$logfile" \
  SESH_REPO_DIRS="$tmpdir/repos" \
    bash "$ROOT/da-vinci-console.sh" >/dev/null 2>&1 || status=$?

  assert_eq "0" "$status"
  [[ -f "$logfile" ]] || {
    printf 'expected startup path to invoke fzf\n' >&2
    return 1
  }
}

test_picker_startup_reaches_fzf
printf 'ok - startup\n'
