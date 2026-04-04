# Da Vinci Console Sectional Hierarchy Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the classic Da Vinci Console picker so it keeps its sectional layout while adding stronger hierarchy, global in-place search, section counts, utilities compaction, and section-jump keys.

**Architecture:** Keep the monolithic Bash entrypoint, but split the rendering flow into explicit builders for `Sessions & Windows`, `Repos`, and `Utilities`. Replace fzf’s built-in filtering with a query-driven reload path that rebuilds the sectional list for each query, preserving headers and counts without reintroducing the command-center item model.

**Tech Stack:** Bash, tmux, fzf 0.58+, git, sesh, zoxide

---

## File Map

### New files

- `tests/testlib/assert.sh`
  Minimal shell assertions for behavior tests.
- `tests/run.sh`
  Small test runner for all `_test.sh` scripts.
- `tests/unit/list_query_test.sh`
  Validates sectional query rendering, counts, and current-dir cleanup.
- `tests/unit/jump_section_test.sh`
  Validates next/previous section jump computation.

### Modified files

- `da-vinci-console.sh`
  Add query-driven rendering, explicit section builders, section counts, compact utilities block, section-jump helper, and the new fzf binds.
- `README.md`
  Update the documented layout, utilities block, search behavior, and new `[` / `]` keys.
- `install.sh`
  Keep install behavior but update the copy text if the keybinding table changes.

---

### Task 1: Add a shell test harness and a query-driven list entrypoint

**Files:**
- Create: `tests/testlib/assert.sh`
- Create: `tests/run.sh`
- Create: `tests/unit/list_query_test.sh`
- Modify: `da-vinci-console.sh`

- [ ] **Step 1: Write the failing query-view test**

```bash
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
elif [[ "$*" == *"status --porcelain"* ]]; then
  exit 0
fi
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
  mkdir -p "$tmpdir/work/api/app" "$tmpdir/work/api/file.txt"

  out="$(
    PATH="$stubbin:$PATH" \
    HOME="$tmpdir/home" \
    SESH_REPO_DIRS="$tmpdir/work:$tmpdir/home" \
      bash "$ROOT/da-vinci-console.sh" --list-query ''
  )"

  assert_contains 'Sessions & Windows (3)' "$out"
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
  if [[ "$out" == *'file.txt'* ]]; then
    printf 'expected Current Dir files to be hidden\n' >&2
    return 1
  fi
}

test_list_query_keeps_sections_and_counts
test_query_hides_empty_sections_and_files
printf 'ok - list_query\n'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/unit/list_query_test.sh`
Expected: FAIL because `tests/testlib/assert.sh` does not exist and `--list-query` is not implemented.

- [ ] **Step 3: Add the minimal harness and a passthrough `--list-query` path**

```bash
# tests/testlib/assert.sh
#!/usr/bin/env bash
set -euo pipefail

assert_eq() {
  local expected="$1"
  local actual="$2"
  if [[ "$expected" != "$actual" ]]; then
    printf 'assert_eq failed\nexpected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    return 1
  fi
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'assert_contains failed\nneedle:   %s\nhaystack: %s\n' "$needle" "$haystack" >&2
    return 1
  fi
}

# tests/run.sh
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0

for test_file in "$ROOT"/tests/unit/*_test.sh; do
  printf '==> %s\n' "$(basename "$test_file")"
  if bash "$test_file"; then
    printf 'PASS %s\n' "$(basename "$test_file")"
  else
    printf 'FAIL %s\n' "$(basename "$test_file")" >&2
    status=1
  fi
done

exit "$status"

# da-vinci-console.sh
dvc_list_query() {
  local query="${1:-}"
  if [[ -z "$query" ]]; then
    build_all
    return 0
  fi
  build_all | fzf --ansi --no-sort --filter "$query" --delimiter=$'\t|\t' --with-nth=1
}

case "${1:-}" in
  --list-query) dvc_list_query "${2:-}"; exit 0 ;;
esac
```

- [ ] **Step 4: Replace the passthrough implementation with explicit per-section rendering**

```bash
dvc_filter_rows() {
  local query="$1"
  if [[ -z "$query" ]]; then
    cat
  else
    fzf --ansi --no-sort --filter "$query" --delimiter=$'\t|\t' --with-nth=1
  fi
}

dvc_count_rows() {
  awk -F '\t\\|\\t' 'NF > 1 && $2 !~ /^(sep|skip):/ { count++ } END { print count + 0 }'
}

dvc_render_section() {
  local label="$1"
  local rows="$2"
  local count
  count="$(printf '%s' "$rows" | dvc_count_rows)"
  [[ "$count" -eq 0 ]] && return 0
  section_sep " ${label} (${count}) "
  printf '%s' "$rows"
}

dvc_list_query() {
  local query="${1:-}"
  local sessions repos utilities

  sessions="$(build_sessions | dvc_filter_rows "$query")"
  repos="$(build_repos | dvc_filter_rows "$query")"
  utilities="$(build_utilities | dvc_filter_rows "$query")"

  dvc_render_section "Sessions & Windows" "$sessions"
  dvc_render_section "Repos" "$repos"
  dvc_render_section "Utilities" "$utilities"
}
```

- [ ] **Step 5: Run the new tests**

Run: `bash tests/unit/list_query_test.sh && bash tests/run.sh`
Expected:

```text
ok - list_query
==> list_query_test.sh
ok - list_query
PASS list_query_test.sh
```

- [ ] **Step 6: Commit**

```bash
git add tests/testlib/assert.sh tests/run.sh tests/unit/list_query_test.sh da-vinci-console.sh
git commit -m "feat: add sectional query rendering"
```

### Task 2: Rebuild the utilities block and clean up Current Dir rows

**Files:**
- Modify: `da-vinci-console.sh`
- Modify: `tests/unit/list_query_test.sh`

- [ ] **Step 1: Extend the failing test for compact utilities**

```bash
test_utilities_block_uses_subsections() {
  local tmpdir stubbin out
  tmpdir="$(mktemp -d)"
  stubbin="$tmpdir/bin"
  make_stubbin "$stubbin"
  mkdir -p "$tmpdir/home/.ssh" "$tmpdir/work/api/.git" "$tmpdir/work/api/app"
  printf 'Host prod\n  HostName prod.example\n' > "$tmpdir/home/.ssh/config"

  out="$(
    PATH="$stubbin:$PATH" \
    HOME="$tmpdir/home" \
    SESH_REPO_DIRS="$tmpdir/work" \
      bash "$ROOT/da-vinci-console.sh" --list-query ''
  )"

  assert_contains 'Utilities (2)' "$out"
  assert_contains 'Current Dir (1)' "$out"
  assert_contains 'SSH (1)' "$out"
  if [[ "$out" == *'Docker ('* ]]; then
    printf 'expected Docker subsection to be hidden when empty\n' >&2
    return 1
  fi
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/unit/list_query_test.sh`
Expected: FAIL because utilities are still rendered as separate top-level sections.

- [ ] **Step 3: Add an explicit utilities builder**

```bash
utility_sep() {
  printf "${C_DIM}%s${C_RESET}${SEP}sep:\n" "$1"
}

build_curdir() {
  local curdir
  curdir=$(tmux display-message -p "#{pane_current_path}" 2>/dev/null)
  [[ -z "$curdir" || ! -d "$curdir" ]] && curdir="$HOME"
  find "$curdir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | while IFS= read -r entry; do
    local icon pshort name
    icon=$(icon_for "$(basename "$entry")")
    pshort=$(short_path "$entry")
    name=$(basename "$entry")
    printf "${C_WHITE}${icon:+$icon }${pshort}${C_RESET}${SEP}sesh:${entry}\n"
  done
}

build_utilities() {
  local curdir_rows ssh_rows docker_rows
  curdir_rows="$(build_curdir)"
  ssh_rows="$(build_ssh)"
  docker_rows=""

  if command -v docker >/dev/null 2>&1 && docker ps -q 2>/dev/null | head -1 | grep -q .; then
    docker_rows="$(build_docker)"
  fi

  [[ -n "$curdir_rows" ]] && {
    utility_sep "  Current Dir ($(printf '%s' "$curdir_rows" | dvc_count_rows))"
    printf '%s' "$curdir_rows"
  }

  [[ -n "$ssh_rows" ]] && {
    utility_sep "  SSH ($(printf '%s' "$ssh_rows" | dvc_count_rows))"
    printf '%s' "$ssh_rows"
  }

  [[ -n "$docker_rows" ]] && {
    utility_sep "  Docker ($(printf '%s' "$docker_rows" | dvc_count_rows))"
    printf '%s' "$docker_rows"
  }
}
```

- [ ] **Step 4: Re-run the utilities tests**

Run: `bash tests/unit/list_query_test.sh && bash tests/run.sh`
Expected: PASS with `Current Dir (1)` and `SSH (1)` present and no Docker subsection when empty.

- [ ] **Step 5: Commit**

```bash
git add da-vinci-console.sh tests/unit/list_query_test.sh
git commit -m "feat: compact utilities and hide inert current-dir rows"
```

### Task 3: Add section-jump helpers and wire them into fzf

**Files:**
- Create: `tests/unit/jump_section_test.sh`
- Modify: `da-vinci-console.sh`

- [ ] **Step 1: Write the failing section-jump test**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"

test_jump_section_moves_to_next_and_previous_visible_header() {
  local tmpdir stubbin next prev
  tmpdir="$(mktemp -d)"
  stubbin="$tmpdir/bin"
  mkdir -p "$stubbin" "$tmpdir/home/.ssh" "$tmpdir/work/api/.git"

  cat > "$stubbin/tmux" <<'EOF'
#!/usr/bin/env bash
cmd="${1:-}"
shift || true
case "$cmd" in
  list-sessions) printf 'main|1|1|200\n' ;;
  list-windows) printf '0|editor|nvim|1|/tmp/work/api\n' ;;
  display-message) printf '/tmp/work/api\n' ;;
esac
EOF
  chmod +x "$stubbin/tmux"

  cat > "$stubbin/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"symbolic-ref --short HEAD"* ]]; then
  printf 'main\n'
fi
EOF
  chmod +x "$stubbin/git"

  cat > "$stubbin/sesh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$stubbin/sesh"

  printf 'Host prod\n  HostName prod.example\n' > "$tmpdir/home/.ssh/config"

  next="$(
    PATH="$stubbin:$PATH" \
    HOME="$tmpdir/home" \
    SESH_REPO_DIRS="$tmpdir/work" \
      bash "$ROOT/da-vinci-console.sh" --jump-section next 1 ''
  )"

  prev="$(
    PATH="$stubbin:$PATH" \
    HOME="$tmpdir/home" \
    SESH_REPO_DIRS="$tmpdir/work" \
      bash "$ROOT/da-vinci-console.sh" --jump-section prev 5 ''
  )"

  assert_eq 'pos(4)' "$next"
  assert_eq 'pos(1)' "$prev"
}

test_jump_section_moves_to_next_and_previous_visible_header
printf 'ok - jump_section\n'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/unit/jump_section_test.sh`
Expected: FAIL because `--jump-section` is not implemented.

- [ ] **Step 3: Implement the jump helper and fzf binds**

```bash
dvc_section_positions() {
  local query="${1:-}"
  dvc_list_query "$query" | awk -F '\t\\|\\t' '$2 ~ /^sep:/ { print NR }'
}

dvc_jump_section() {
  local direction="$1"
  local current_index="$2"
  local query="${3:-}"
  local positions target first last

  mapfile -t positions < <(dvc_section_positions "$query")
  [[ "${#positions[@]}" -eq 0 ]] && { printf 'ignore'; return 0; }

  first="${positions[0]}"
  last="${positions[${#positions[@]}-1]}"
  target="$first"

  if [[ "$direction" == "next" ]]; then
    for pos in "${positions[@]}"; do
      if (( pos > current_index + 1 )); then
        target="$pos"
        break
      fi
    done
  else
    target="$first"
    for pos in "${positions[@]}"; do
      (( pos >= current_index + 1 )) && break
      target="$pos"
    done
  fi

  printf 'pos(%s)' "$target"
}

case "${1:-}" in
  --jump-section) dvc_jump_section "$2" "$3" "${4:-}"; exit 0 ;;
esac

selected=$(bash "$SELF" --list-query "" | fzf \
  --disabled \
  --bind "start:reload-sync(bash '$SELF' --list-query '')" \
  --bind "change:reload-sync(bash '$SELF' --list-query {q})" \
  --bind "]:transform:bash '$SELF' --jump-section next {n} {q}" \
  --bind "[:transform:bash '$SELF' --jump-section prev {n} {q}" \
  # keep existing binds
)
```

- [ ] **Step 4: Run the jump tests and the full test suite**

Run: `bash tests/unit/jump_section_test.sh && bash tests/run.sh`
Expected:

```text
ok - jump_section
==> jump_section_test.sh
ok - jump_section
PASS jump_section_test.sh
==> list_query_test.sh
ok - list_query
PASS list_query_test.sh
```

- [ ] **Step 5: Commit**

```bash
git add da-vinci-console.sh tests/unit/jump_section_test.sh
git commit -m "feat: add sectional jump navigation"
```

### Task 4: Refresh the visible hierarchy and docs, then verify the installed build

**Files:**
- Modify: `da-vinci-console.sh`
- Modify: `README.md`
- Modify: `install.sh`

- [ ] **Step 1: Adjust headers, spacing, and help text**

```bash
HEADER="  Enter switch  •  Tab select  •  ^N new  •  [ prev section  •  ] next section
  ^A all  •  ^J jump  •  ^W windows  •  ^G tags  •  ^B snap  •  ^O restore  •  ^/ preview"

section_sep() {
  printf "${C_BORDER}━━${C_RESET} ${C_BRIGHT}%s${C_RESET} ${C_BORDER}$(printf '━%.0s' {1..46})${C_RESET}${SEP}sep:\n" "$1"
}

utility_sep() {
  printf "${C_DIM}  %s${C_RESET}${SEP}sep:\n" "$1"
}
```

- [ ] **Step 2: Update the README to match the new behavior**

```md
- **Structured hierarchy** — Sessions & Windows at the top, Repos beneath, and a compact Utilities block for Current Dir / SSH / Docker
- **Global in-place search** — typing filters rows inside each section instead of collapsing into one mixed list
- **Section jump keys** — `[` and `]` jump between visible sections
- **Current Dir cleanup** — directories only; inert files are hidden
```

- [ ] **Step 3: Run verification on the worktree build**

Run: `bash tests/run.sh && bash -n da-vinci-console.sh install.sh`
Expected:

```text
==> jump_section_test.sh
ok - jump_section
PASS jump_section_test.sh
==> list_query_test.sh
ok - list_query
PASS list_query_test.sh
```

- [ ] **Step 4: Install and smoke-test the live picker**

Run:

```bash
./install.sh
~/.config/tmux/sesh_picker.sh
```

Expected:

- installer prints `✓ Installed: /home/smiley/.config/tmux/sesh_picker.sh`
- the picker opens in a PTY and shows `Sessions & Windows (...)`, `Repos (...)`, and `Utilities (...)`

- [ ] **Step 5: Commit**

```bash
git add da-vinci-console.sh README.md install.sh
git commit -m "feat: refresh classic picker hierarchy"
```
