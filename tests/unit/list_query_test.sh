#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"

make_stubbin() {
  local stubbin="$1"

  mkdir -p "$stubbin"

  cat > "$stubbin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
shift || true

case "$cmd" in
  list-sessions)
    printf 'main|2|1|200\n'
    printf 'dotfiles|1|0|100\n'
    ;;
  list-windows)
    if [[ "${1:-}" == "-t" && "${2:-}" == "main" ]]; then
      printf '0|editor|nvim|1|/tmp/work/api\n'
      printf '1|server|zsh|0|/tmp/work/api\n'
    elif [[ "${1:-}" == "-t" && "${2:-}" == "dotfiles" ]]; then
      printf '0|editor|nvim|1|/tmp/home/dotfiles\n'
    fi
    ;;
  display-message)
    printf '/tmp/work/api\n'
    ;;
esac
EOF
  chmod +x "$stubbin/tmux"

  cat > "$stubbin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *"symbolic-ref --short HEAD"* ]]; then
  printf 'main\n'
  exit 0
fi

if [[ "$*" == *"rev-parse --short HEAD"* ]]; then
  printf 'abc123\n'
  exit 0
fi

if [[ "$*" == *"status --porcelain"* ]]; then
  exit 0
fi

exit 0
EOF
  chmod +x "$stubbin/git"

  cat > "$stubbin/docker" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$stubbin/docker"

  cat > "$stubbin/sesh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$stubbin/sesh"

  cat > "$stubbin/zoxide" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$stubbin/zoxide"
}

test_list_query_keeps_sections_and_counts() {
  local tmpdir stubbin out

  tmpdir="$(mktemp -d)"
  stubbin="$tmpdir/bin"
  make_stubbin "$stubbin"

  mkdir -p "$tmpdir/home/.ssh" "$tmpdir/work/api/.git" "$tmpdir/home/dotfiles/.git"
  printf 'Host prod\n  HostName prod.example\n' > "$tmpdir/home/.ssh/config"
  mkdir -p "$tmpdir/work/api/app"
  : > "$tmpdir/work/api/file.txt"

  out="$(
    PATH="$stubbin:$PATH" \
    HOME="$tmpdir/home" \
    SESH_REPO_DIRS="$tmpdir/work:$tmpdir/home" \
      bash "$ROOT/da-vinci-console.sh" --list-query ''
  )"

  assert_contains 'Sessions & Windows (5)' "$out"
  assert_contains 'Repos (2)' "$out"
  assert_contains 'Utilities (2)' "$out"
  assert_contains 'Current Dir' "$out"
  assert_contains 'SSH' "$out"
}

test_query_hides_empty_sections_and_files() {
  local tmpdir stubbin out

  tmpdir="$(mktemp -d)"
  stubbin="$tmpdir/bin"
  make_stubbin "$stubbin"

  mkdir -p "$tmpdir/home/.ssh" "$tmpdir/work/api/.git"
  printf 'Host prod\n  HostName prod.example\n' > "$tmpdir/home/.ssh/config"
  mkdir -p "$tmpdir/work/api/app"
  : > "$tmpdir/work/api/file.txt"

  out="$(
    PATH="$stubbin:$PATH" \
    HOME="$tmpdir/home" \
    SESH_REPO_DIRS="$tmpdir/work" \
      bash "$ROOT/da-vinci-console.sh" --list-query 'prod'
  )"

  assert_contains 'Utilities (1)' "$out"
  assert_contains 'prod' "$out"

  if [[ "$out" == *'Sessions & Windows'* ]]; then
    printf 'expected Sessions & Windows to be hidden for prod query\n' >&2
    return 1
  fi

  if [[ "$out" == *'Repos ('* ]]; then
    printf 'expected Repos to be hidden for prod query\n' >&2
    return 1
  fi

  if [[ "$out" == *'file.txt'* ]]; then
    printf 'expected Current Dir files to be hidden\n' >&2
    return 1
  fi
}

test_list_query_keeps_sections_and_counts
test_query_hides_empty_sections_and_files
printf 'ok - list_query\n'
