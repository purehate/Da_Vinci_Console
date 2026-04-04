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
    printf '%s\n' "$DVC_TEST_CURDIR"
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

test_jump_section_moves_between_visible_top_level_sections() {
  local tmpdir stubbin next prev

  tmpdir="$(mktemp -d)"
  stubbin="$tmpdir/bin"
  make_stubbin "$stubbin"

  mkdir -p "$tmpdir/home/.ssh" "$tmpdir/work/api/.git" "$tmpdir/home/dotfiles/.git"
  printf 'Host prod\n  HostName prod.example\n' > "$tmpdir/home/.ssh/config"

  next="$(
    PATH="$stubbin:$PATH" \
    HOME="$tmpdir/home" \
    DVC_TEST_CURDIR="$tmpdir/home" \
    SESH_REPO_DIRS="$tmpdir/work:$tmpdir/home" \
      bash "$ROOT/da-vinci-console.sh" --jump-section next 1 ''
  )"

  prev="$(
    PATH="$stubbin:$PATH" \
    HOME="$tmpdir/home" \
    DVC_TEST_CURDIR="$tmpdir/home" \
    SESH_REPO_DIRS="$tmpdir/work:$tmpdir/home" \
      bash "$ROOT/da-vinci-console.sh" --jump-section prev 10 ''
  )"

  assert_eq 'pos(8)' "$next"
  assert_eq 'pos(8)' "$prev"
}

test_jump_section_moves_between_visible_top_level_sections
printf 'ok - jump_section\n'
