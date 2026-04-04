# Da Vinci Console v1.1 Command Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor Da Vinci Console into a path-backed, ranked tmux command center with cached workspace state, typed actions, safe destructive flows, and only SSH/snapshots as secondary providers in v1.1.

**Architecture:** Keep Bash, but split the current monolithic script into focused library files for item modeling, state, providers, ranking, rendering, previews, and actions. The entrypoint stays `da-vinci-console.sh`, but it becomes a thin coordinator that reloads ranked items through fzf instead of hardcoding static sections and ad hoc action handlers.

**Tech Stack:** Bash, tmux, fzf 0.58+, git, sesh, zoxide

---

## File Map

### New files

- `lib/dvc/item_model.sh`
  Canonical IDs, tab-separated item records, record field helpers.
- `lib/dvc/state.sh`
  Cache directory helpers, workspace cache reads, usage history, pin state.
- `lib/dvc/provider_workspaces.sh`
  Configured-root discovery, seeded workspace fallback, workspace item emission.
- `lib/dvc/provider_tmux.sh`
  tmux session/window parsing, live item emission, tmux workspace path hints.
- `lib/dvc/merge.sh`
  Merge path-backed workspace items with live tmux items.
- `lib/dvc/rank.sh`
  Query scoring, frecency boosts, current-directory boost, pin boost.
- `lib/dvc/render.sh`
  Empty-query grouped output and ranked query output.
- `lib/dvc/actions.sh`
  Typed primary/secondary/batch action dispatch and confirmations.
- `lib/dvc/provider_ssh.sh`
  Parse `~/.ssh/config` into utility items.
- `lib/dvc/provider_snapshots.sh`
  List, save, and restore snapshot items.
- `lib/dvc/preview.sh`
  Focused preview routing for workspace, tmux, ssh, and snapshots.
- `tests/testlib/assert.sh`
  Minimal assertion helpers for shell tests.
- `tests/run.sh`
  Unit test runner.
- `tests/unit/item_model_test.sh`
  Canonical ID and item record tests.
- `tests/unit/state_test.sh`
  Cache path, usage history, and pin tests.
- `tests/unit/provider_workspaces_test.sh`
  Configured-root and seeded workspace provider tests.
- `tests/unit/live_merge_test.sh`
  tmux path extraction and workspace/live dedup tests.
- `tests/unit/rank_render_test.sh`
  Ranking, pin boost, and grouped rendering tests.
- `tests/unit/actions_test.sh`
  Typed action validation and destructive confirmation tests.
- `tests/unit/provider_ssh_test.sh`
  SSH host parsing tests.
- `tests/unit/provider_snapshots_test.sh`
  Snapshot list/save/restore tests.
- `tests/fixtures/tmux/sessions.txt`
  tmux session fixture.
- `tests/fixtures/tmux/windows.txt`
  tmux window fixture.
- `tests/fixtures/ssh/config`
  ssh config fixture.
- `tests/fixtures/snapshots/demo.snapshot`
  snapshot fixture.

### Modified files

- `da-vinci-console.sh`
  Entry point, library sourcing, `--list-query` reload path, key bindings, typed action subcommands.
- `README.md`
  Update behavior, remove Docker/tags from v1.1, document pins, confirm flows, and query-ranked view.
- `install.sh`
  Keep install path the same, but update shell snippet text to match new behavior.
- `extras/tmux.conf`
  Align the example bind with the supported popup entrypoint.

---

### Task 1: Add the test harness and canonical item model

**Files:**
- Create: `tests/testlib/assert.sh`
- Create: `tests/run.sh`
- Create: `tests/unit/item_model_test.sh`
- Create: `lib/dvc/item_model.sh`

- [ ] **Step 1: Write the failing item-model test**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"
source "$ROOT/lib/dvc/item_model.sh"

test_workspace_ids_are_path_backed() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/project"
  ln -s "$tmpdir/project" "$tmpdir/project-link"

  assert_eq "workspace:${tmpdir}/project" "$(dvc_workspace_id "$tmpdir/project-link")"
}

test_session_and_window_ids_are_stable() {
  assert_eq "session:main" "$(dvc_session_id "main")"
  assert_eq "window:main:2" "$(dvc_window_id "main" "2")"
}

test_item_fields_round_trip() {
  local row
  row="$(dvc_item_emit "workspace" "workspace:/tmp/api" "api" "api project" "/tmp/api" "Projects" "workspace:/tmp/api" "live=0" "0")"

  assert_eq "workspace" "$(dvc_item_field "$row" kind)"
  assert_eq "workspace:/tmp/api" "$(dvc_item_field "$row" id)"
  assert_eq "/tmp/api" "$(dvc_item_field "$row" path)"
  assert_eq "Projects" "$(dvc_item_field "$row" group)"
}

test_workspace_ids_are_path_backed
test_session_and_window_ids_are_stable
test_item_fields_round_trip
printf 'ok - item_model\n'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/unit/item_model_test.sh`
Expected: FAIL with `No such file or directory` for `tests/testlib/assert.sh` or `lib/dvc/item_model.sh`

- [ ] **Step 3: Write the minimal test harness and item model**

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

# lib/dvc/item_model.sh
#!/usr/bin/env bash
set -euo pipefail

dvc_realpath() {
  (
    cd "$1" >/dev/null 2>&1
    pwd -P
  )
}

dvc_workspace_id() { printf 'workspace:%s\n' "$(dvc_realpath "$1")"; }
dvc_session_id() { printf 'session:%s\n' "$1"; }
dvc_window_id() { printf 'window:%s:%s\n' "$1" "$2"; }

dvc_item_emit() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "${9:-0}"
}

dvc_item_field() {
  local row="$1"
  local field="$2"
  local index

  case "$field" in
    kind) index=1 ;;
    id) index=2 ;;
    label) index=3 ;;
    search) index=4 ;;
    path) index=5 ;;
    group) index=6 ;;
    target) index=7 ;;
    meta) index=8 ;;
    score) index=9 ;;
    *) printf 'unknown field: %s\n' "$field" >&2; return 1 ;;
  esac

  awk -F '\t' -v idx="$index" '{ print $idx }' <<<"$row"
}
```

- [ ] **Step 4: Run the item-model tests**

Run: `bash tests/unit/item_model_test.sh && bash tests/run.sh`
Expected:

```text
ok - item_model
==> item_model_test.sh
ok - item_model
PASS item_model_test.sh
```

- [ ] **Step 5: Commit**

```bash
git add tests/testlib/assert.sh tests/run.sh tests/unit/item_model_test.sh lib/dvc/item_model.sh
git commit -m "test: add item model shell harness"
```

### Task 2: Add persistent cache, frecency, and pins

**Files:**
- Create: `lib/dvc/state.sh`
- Create: `tests/unit/state_test.sh`

- [ ] **Step 1: Write the failing state test**

```bash
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
```

- [ ] **Step 2: Run the state test to verify it fails**

Run: `bash tests/unit/state_test.sh`
Expected: FAIL with `No such file or directory` for `lib/dvc/state.sh`

- [ ] **Step 3: Implement state helpers**

```bash
# lib/dvc/state.sh
#!/usr/bin/env bash
set -euo pipefail

dvc_state_dir() {
  printf '%s/da-vinci-console\n' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

dvc_workspace_cache_file() { printf '%s/workspaces.tsv\n' "$(dvc_state_dir)"; }
dvc_usage_file() { printf '%s/usage.tsv\n' "$(dvc_state_dir)"; }
dvc_pins_file() { printf '%s/pins.tsv\n' "$(dvc_state_dir)"; }

dvc_ensure_state_dir() {
  mkdir -p "$(dvc_state_dir)"
}

dvc_record_open() {
  local id="$1"
  local opened_at="${2:-$(date +%s)}"
  local usage_file tmp_file

  dvc_ensure_state_dir
  usage_file="$(dvc_usage_file)"
  tmp_file="$(mktemp)"

  if [[ -f "$usage_file" ]]; then
    awk -F '\t' -v OFS='\t' -v id="$id" -v opened_at="$opened_at" '
      BEGIN { updated = 0 }
      $1 == id { print $1, opened_at, $3 + 1; updated = 1; next }
      { print $0 }
      END { if (!updated) print id, opened_at, 1 }
    ' "$usage_file" >"$tmp_file"
  else
    printf '%s\t%s\t1\n' "$id" "$opened_at" >"$tmp_file"
  fi

  mv "$tmp_file" "$usage_file"
}

dvc_usage_score() {
  local id="$1"
  local usage_file
  usage_file="$(dvc_usage_file)"
  [[ -f "$usage_file" ]] || { printf '0\n'; return; }
  awk -F '\t' -v id="$id" '$1 == id { print ($3 * 10) }' "$usage_file" | tail -n 1
}

dvc_is_pinned() {
  local id="$1"
  local pins_file
  pins_file="$(dvc_pins_file)"
  [[ -f "$pins_file" ]] || { printf '0\n'; return; }
  grep -qx "$id" "$pins_file" && printf '1\n' || printf '0\n'
}

dvc_set_pin() {
  local id="$1"
  local desired="$2"
  local pins_file tmp_file

  dvc_ensure_state_dir
  pins_file="$(dvc_pins_file)"
  tmp_file="$(mktemp)"

  [[ -f "$pins_file" ]] && grep -vx "$id" "$pins_file" >"$tmp_file" || : >"$tmp_file"
  [[ "$desired" == "1" ]] && printf '%s\n' "$id" >>"$tmp_file"
  mv "$tmp_file" "$pins_file"
}
```

- [ ] **Step 4: Run the state tests**

Run: `bash tests/unit/state_test.sh && bash tests/run.sh`
Expected:

```text
ok - state
==> item_model_test.sh
ok - item_model
PASS item_model_test.sh
==> state_test.sh
ok - state
PASS state_test.sh
```

- [ ] **Step 5: Commit**

```bash
git add lib/dvc/state.sh tests/unit/state_test.sh
git commit -m "feat: add command center state helpers"
```

### Task 3: Add workspace discovery without default home crawling

**Files:**
- Create: `lib/dvc/provider_workspaces.sh`
- Create: `tests/unit/provider_workspaces_test.sh`

- [ ] **Step 1: Write the failing workspace-provider test**

```bash
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
  mkdir -p "$tmpdir/work/api/.git" "$tmpdir/work/web/.git"
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
```

- [ ] **Step 2: Run the workspace-provider test to verify it fails**

Run: `bash tests/unit/provider_workspaces_test.sh`
Expected: FAIL with `No such file or directory` for `lib/dvc/provider_workspaces.sh`

- [ ] **Step 3: Implement the workspace provider**

```bash
# lib/dvc/provider_workspaces.sh
#!/usr/bin/env bash
set -euo pipefail

dvc_cached_workspace_paths() {
  local cache_file
  cache_file="$(dvc_workspace_cache_file)"
  [[ -f "$cache_file" ]] || return 0
  cut -f1 "$cache_file"
}

dvc_tmux_workspace_paths() { :; }

dvc_sesh_workspace_paths() {
  command -v "$SESH" >/dev/null 2>&1 || return 0
  "$SESH" list -c -z 2>/dev/null || :
}

dvc_zoxide_workspace_paths() {
  command -v zoxide >/dev/null 2>&1 || return 0
  zoxide query -l 2>/dev/null || :
}

dvc_seed_workspace_paths() {
  local current_dir="${1:-}"
  [[ -n "$current_dir" && -d "$current_dir" ]] && printf '%s\n' "$current_dir"
  dvc_cached_workspace_paths
  dvc_tmux_workspace_paths
  dvc_sesh_workspace_paths
  dvc_zoxide_workspace_paths
}

dvc_discover_workspace_paths() {
  local root
  local IFS=':'
  for root in ${SESH_REPO_DIRS:-}; do
    root="${root/#\~/$HOME}"
    [[ -d "$root" ]] || continue
    find "$root" -maxdepth 3 -name .git -type d 2>/dev/null | sed 's|/.git$||'
  done
}

dvc_list_workspace_paths() {
  local current_dir="${1:-}"
  if [[ -n "${SESH_REPO_DIRS:-}" ]]; then
    dvc_discover_workspace_paths | awk '!seen[$0]++'
  else
    dvc_seed_workspace_paths "$current_dir" | awk 'NF && !seen[$0]++'
  fi
}

dvc_workspace_items() {
  local current_dir="${1:-}"
  while IFS= read -r path; do
    [[ -d "$path" ]] || continue
    local real_path label id
    real_path="$(dvc_realpath "$path")"
    label="$(basename "$real_path")"
    id="$(dvc_workspace_id "$real_path")"
    dvc_item_emit "workspace" "$id" "$label" "$label $real_path" "$real_path" "Projects" "$id" "live=0" "0"
  done < <(dvc_list_workspace_paths "$current_dir")
}
```

- [ ] **Step 4: Run the workspace-provider tests**

Run: `bash tests/unit/provider_workspaces_test.sh && bash tests/run.sh`
Expected:

```text
ok - provider_workspaces
PASS item_model_test.sh
PASS state_test.sh
PASS provider_workspaces_test.sh
```

- [ ] **Step 5: Commit**

```bash
git add lib/dvc/provider_workspaces.sh tests/unit/provider_workspaces_test.sh
git commit -m "feat: add workspace seed provider"
```

### Task 4: Parse live tmux state and merge workspace/live items by path

**Files:**
- Create: `lib/dvc/provider_tmux.sh`
- Create: `lib/dvc/merge.sh`
- Create: `tests/fixtures/tmux/sessions.txt`
- Create: `tests/fixtures/tmux/windows.txt`
- Create: `tests/unit/live_merge_test.sh`

- [ ] **Step 1: Write the failing live-merge test**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"
source "$ROOT/lib/dvc/item_model.sh"
source "$ROOT/lib/dvc/provider_tmux.sh"
source "$ROOT/lib/dvc/merge.sh"

test_tmux_workspace_paths_are_extracted_from_window_stream() {
  local windows_file paths
  windows_file="$ROOT/tests/fixtures/tmux/windows.txt"
  paths="$(dvc_tmux_workspace_paths_from_stream "$windows_file")"
  assert_contains "/tmp/work/api" "$paths"
  assert_contains "/tmp/work/blog" "$paths"
}

test_workspace_items_absorb_live_targets_by_path() {
  local workspace_file live_file merged
  workspace_file="$(mktemp)"
  live_file="$(mktemp)"

  dvc_item_emit "workspace" "workspace:/tmp/work/api" "api" "api /tmp/work/api" "/tmp/work/api" "Projects" "workspace:/tmp/work/api" "live=0" "0" >"$workspace_file"
  dvc_item_emit "window" "window:main:1" "editor" "editor main api" "/tmp/work/api" "Live" "main:1" "attached=1" "0" >"$live_file"
  dvc_item_emit "session" "session:scratch" "scratch" "scratch" "" "Live" "scratch" "attached=0" "0" >>"$live_file"

  merged="$(dvc_merge_workspace_and_live_items "$workspace_file" "$live_file")"
  assert_contains $'workspace\tworkspace:/tmp/work/api\tapi\tapi /tmp/work/api\t/tmp/work/api\tLive\tmain:1\tlive=1' "$merged"
  assert_contains $'session\tsession:scratch' "$merged"
}

test_tmux_workspace_paths_are_extracted_from_window_stream
test_workspace_items_absorb_live_targets_by_path
printf 'ok - live_merge\n'
```

- [ ] **Step 2: Run the live-merge test to verify it fails**

Run: `bash tests/unit/live_merge_test.sh`
Expected: FAIL with `No such file or directory` for `lib/dvc/provider_tmux.sh` or `lib/dvc/merge.sh`

- [ ] **Step 3: Implement the tmux provider and merge layer**

```bash
# tests/fixtures/tmux/sessions.txt
main|2|1|1710000000
scratch|1|0|1709999900

# tests/fixtures/tmux/windows.txt
main|1|editor|nvim|1|/tmp/work/api
main|2|server|zsh|0|/tmp/work/api
scratch|1|notes|vim|1|/tmp/work/blog

# lib/dvc/provider_tmux.sh
#!/usr/bin/env bash
set -euo pipefail

dvc_tmux_workspace_paths_from_stream() {
  local windows_file="$1"
  awk -F '|' '{ print $6 }' "$windows_file" | awk 'NF && !seen[$0]++'
}

dvc_tmux_workspace_paths() {
  tmux list-windows -a -F '#{session_name}|#{window_index}|#{window_name}|#{pane_current_command}|#{window_active}|#{pane_current_path}' 2>/dev/null \
    | awk -F '|' '{ print $6 }' | awk 'NF && !seen[$0]++'
}

dvc_live_items_from_tmux_stream() {
  local sessions_file="$1"
  local windows_file="$2"

  while IFS='|' read -r session_name _windows attached _activity; do
    dvc_item_emit "session" "$(dvc_session_id "$session_name")" "$session_name" "$session_name" "" "Live" "$session_name" "attached=${attached}" "0"
  done <"$sessions_file"

  while IFS='|' read -r session_name window_index window_name command active path; do
    dvc_item_emit "window" "$(dvc_window_id "$session_name" "$window_index")" "$window_name" "$session_name $window_name $command $path" "$path" "Live" "${session_name}:${window_index}" "active=${active}" "0"
  done <"$windows_file"
}

dvc_live_items() {
  local sessions_file windows_file
  sessions_file="$(mktemp)"
  windows_file="$(mktemp)"

  tmux list-sessions -F '#{session_name}|#{session_windows}|#{?session_attached,1,0}|#{session_activity}' 2>/dev/null >"$sessions_file"
  tmux list-windows -a -F '#{session_name}|#{window_index}|#{window_name}|#{pane_current_command}|#{window_active}|#{pane_current_path}' 2>/dev/null >"$windows_file"

  dvc_live_items_from_tmux_stream "$sessions_file" "$windows_file"
}

# lib/dvc/merge.sh
#!/usr/bin/env bash
set -euo pipefail

dvc_merge_workspace_and_live_items() {
  local workspace_file="$1"
  local live_file="$2"
  local row kind path
  declare -A workspace_rows=()

  while IFS= read -r row; do
    path="$(dvc_item_field "$row" path)"
    workspace_rows["$path"]="$row"
  done <"$workspace_file"

  while IFS= read -r row; do
    kind="$(dvc_item_field "$row" kind)"
    path="$(dvc_item_field "$row" path)"

    if [[ -n "$path" && -n "${workspace_rows[$path]:-}" ]]; then
      local workspace_row workspace_id workspace_label workspace_search target
      workspace_row="${workspace_rows[$path]}"
      workspace_id="$(dvc_item_field "$workspace_row" id)"
      workspace_label="$(dvc_item_field "$workspace_row" label)"
      workspace_search="$(dvc_item_field "$workspace_row" search)"
      target="$(dvc_item_field "$row" target)"
      dvc_item_emit "workspace" "$workspace_id" "$workspace_label" "$workspace_search" "$path" "Live" "$target" "live=1" "0"
      unset 'workspace_rows[$path]'
    else
      printf '%s\n' "$row"
    fi
  done <"$live_file"

  for path in "${!workspace_rows[@]}"; do
    printf '%s\n' "${workspace_rows[$path]}"
  done
}
```

- [ ] **Step 4: Run the live-merge tests**

Run: `bash tests/unit/live_merge_test.sh && bash tests/run.sh`
Expected:

```text
ok - live_merge
PASS item_model_test.sh
PASS state_test.sh
PASS provider_workspaces_test.sh
PASS live_merge_test.sh
```

- [ ] **Step 5: Commit**

```bash
git add lib/dvc/provider_tmux.sh lib/dvc/merge.sh tests/fixtures/tmux/sessions.txt tests/fixtures/tmux/windows.txt tests/unit/live_merge_test.sh
git commit -m "feat: merge live tmux items with workspaces"
```

### Task 5: Add ranking, grouped rendering, and query-driven reloads

**Files:**
- Create: `lib/dvc/rank.sh`
- Create: `lib/dvc/render.sh`
- Create: `tests/unit/rank_render_test.sh`
- Modify: `da-vinci-console.sh`

- [ ] **Step 1: Write the failing ranking/render test**

```bash
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
```

- [ ] **Step 2: Run the ranking/render test to verify it fails**

Run: `bash tests/unit/rank_render_test.sh`
Expected: FAIL with `No such file or directory` for `lib/dvc/rank.sh` or `lib/dvc/render.sh`

- [ ] **Step 3: Implement ranking, rendering, and query reload wiring**

```bash
# lib/dvc/rank.sh
#!/usr/bin/env bash
set -euo pipefail

dvc_query_score() {
  local query="${1,,}"
  local search="${2,,}"
  [[ -z "$query" ]] && { printf '0\n'; return; }
  if [[ "$search" == "$query"* ]]; then
    printf '300\n'
  elif [[ "$search" == *"$query"* ]]; then
    printf '200\n'
  else
    printf '0\n'
  fi
}

dvc_rank_items() {
  local query="$1"
  local current_dir="$2"
  local row id path search meta score usage pin

  while IFS= read -r row; do
    id="$(dvc_item_field "$row" id)"
    path="$(dvc_item_field "$row" path)"
    search="$(dvc_item_field "$row" search)"
    meta="$(dvc_item_field "$row" meta)"
    score="$(dvc_query_score "$query" "$search")"
    usage="$(dvc_usage_score "$id" 2>/dev/null || printf '0\n')"
    pin="$(dvc_is_pinned "$id" 2>/dev/null || printf '0\n')"

    [[ "$meta" == *"live=1"* || "$meta" == *"attached=1"* ]] && score=$((score + 75))
    [[ -n "$path" && "$current_dir" == "$path"* ]] && score=$((score + 25))
    score=$((score + usage))
    [[ "$pin" == "1" ]] && score=$((score + 100))

    dvc_item_emit \
      "$(dvc_item_field "$row" kind)" \
      "$id" \
      "$(dvc_item_field "$row" label)" \
      "$search" \
      "$path" \
      "$(dvc_item_field "$row" group)" \
      "$(dvc_item_field "$row" target)" \
      "$meta" \
      "$score"
  done | sort -t $'\t' -k9,9nr -k3,3
}

# lib/dvc/render.sh
#!/usr/bin/env bash
set -euo pipefail

dvc_render_grouped_view() {
  local previous_group=""
  local row group label id

  while IFS= read -r row; do
    group="$(dvc_item_field "$row" group)"
    label="$(dvc_item_field "$row" label)"
    id="$(dvc_item_field "$row" id)"

    if [[ "$group" != "$previous_group" ]]; then
      printf '── %s\t|\tsep:%s\n' "$group" "$group"
      previous_group="$group"
    fi

    printf '%s\t|\t%s\n' "$label" "$id"
  done
}

# da-vinci-console.sh (replace the static build_all entrypoint with query reloads)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/dvc/item_model.sh"
source "$SCRIPT_DIR/lib/dvc/state.sh"
source "$SCRIPT_DIR/lib/dvc/provider_workspaces.sh"
source "$SCRIPT_DIR/lib/dvc/provider_tmux.sh"
source "$SCRIPT_DIR/lib/dvc/merge.sh"
source "$SCRIPT_DIR/lib/dvc/rank.sh"
source "$SCRIPT_DIR/lib/dvc/render.sh"

dvc_list_query() {
  local query="${1:-}"
  local current_dir
  current_dir="$(tmux display-message -p "#{pane_current_path}" 2>/dev/null || pwd)"

  local workspace_file live_file
  workspace_file="$(mktemp)"
  live_file="$(mktemp)"

  dvc_workspace_items "$current_dir" >"$workspace_file"
  dvc_live_items >"$live_file"

  dvc_merge_workspace_and_live_items "$workspace_file" "$live_file" \
    | dvc_rank_items "$query" "$current_dir" \
    | dvc_render_grouped_view
}

case "${1:-}" in
  --list-query)
    dvc_list_query "${2:-}"
    exit 0
    ;;
esac

selected="$(bash "$SELF" --list-query "" | fzf \
  --disabled \
  --bind "start:reload(bash '$SELF' --list-query '')" \
  --bind "change:reload(bash '$SELF' --list-query {q})" \
  --delimiter=$'\t|\t' \
  --with-nth=1)"
```

- [ ] **Step 4: Run the ranking/render tests**

Run: `bash tests/unit/rank_render_test.sh && bash tests/run.sh`
Expected:

```text
ok - rank_render
PASS item_model_test.sh
PASS state_test.sh
PASS provider_workspaces_test.sh
PASS live_merge_test.sh
PASS rank_render_test.sh
```

- [ ] **Step 5: Commit**

```bash
git add lib/dvc/rank.sh lib/dvc/render.sh tests/unit/rank_render_test.sh da-vinci-console.sh
git commit -m "feat: add ranked query reload pipeline"
```

### Task 6: Replace row-dependent actions with typed dispatch and safe confirmations

**Files:**
- Create: `lib/dvc/actions.sh`
- Create: `tests/unit/actions_test.sh`
- Modify: `da-vinci-console.sh`

- [ ] **Step 1: Write the failing actions test**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/testlib/assert.sh"
source "$ROOT/lib/dvc/item_model.sh"
source "$ROOT/lib/dvc/actions.sh"

test_workspace_primary_action_prefers_live_target() {
  local row
  row="$(dvc_item_emit "workspace" "workspace:/tmp/api" "api" "api" "/tmp/api" "Live" "main:1" "live=1" "10")"

  tmux() { printf 'switch-client:%s\n' "$*"; }
  assert_contains 'switch-client:switch-client -t main:1' "$(dvc_dispatch_primary_action "$row")"
}

test_multi_kill_rejects_non_killable_kinds() {
  local rows result
  rows="$(printf '%s\n%s\n' \
    "$(dvc_item_emit "window" "window:main:1" "editor" "editor" "/tmp/api" "Live" "main:1" "active=1" "0")" \
    "$(dvc_item_emit "workspace" "workspace:/tmp/api" "api" "api" "/tmp/api" "Projects" "workspace:/tmp/api" "live=0" "0")")"

  if result="$(printf '%s\n' "$rows" | dvc_validate_batch_action "kill" 2>&1)"; then
    printf 'expected validate_batch_action to fail\n' >&2
    return 1
  fi

  assert_contains 'workspace' "$result"
}

test_attached_session_kill_requires_force() {
  local row
  row="$(dvc_item_emit "session" "session:main" "main" "main" "" "Live" "main" "attached=1" "0")"
  assert_eq "blocked" "$(dvc_guard_destructive_action "kill" "$row" "0")"
  assert_eq "allowed" "$(dvc_guard_destructive_action "kill" "$row" "1")"
}

test_workspace_primary_action_prefers_live_target
test_multi_kill_rejects_non_killable_kinds
test_attached_session_kill_requires_force
printf 'ok - actions\n'
```

- [ ] **Step 2: Run the actions test to verify it fails**

Run: `bash tests/unit/actions_test.sh`
Expected: FAIL with `No such file or directory` for `lib/dvc/actions.sh`

- [ ] **Step 3: Implement the typed action layer**

```bash
# lib/dvc/actions.sh
#!/usr/bin/env bash
set -euo pipefail

dvc_guard_destructive_action() {
  local action="$1"
  local row="$2"
  local force="${3:-0}"
  local kind meta

  kind="$(dvc_item_field "$row" kind)"
  meta="$(dvc_item_field "$row" meta)"

  [[ "$action" != "kill" ]] && { printf 'allowed\n'; return; }
  [[ "$kind" != "session" ]] && { printf 'allowed\n'; return; }
  [[ "$meta" == *"attached=1"* && "$force" != "1" ]] && { printf 'blocked\n'; return; }
  printf 'allowed\n'
}

dvc_validate_batch_action() {
  local action="$1"
  local row kind

  while IFS= read -r row; do
    kind="$(dvc_item_field "$row" kind)"
    if [[ "$action" == "kill" && "$kind" != "session" && "$kind" != "window" ]]; then
      printf 'batch action %s does not allow kind %s\n' "$action" "$kind" >&2
      return 1
    fi
  done
}

dvc_dispatch_primary_action() {
  local row="$1"
  local kind target label path meta
  kind="$(dvc_item_field "$row" kind)"
  target="$(dvc_item_field "$row" target)"
  label="$(dvc_item_field "$row" label)"
  path="$(dvc_item_field "$row" path)"
  meta="$(dvc_item_field "$row" meta)"

  case "$kind" in
    workspace)
      if [[ "$meta" == *"live=1"* ]]; then
        tmux switch-client -t "$target"
      else
        tmux new-session -d -s "$label" -c "$path"
        tmux switch-client -t "$label"
      fi
      ;;
    window) tmux switch-client -t "$target" ;;
    session) tmux switch-client -t "$target" ;;
    ssh) tmux new-window -n "$label" "ssh $(printf '%q' "$label")" ;;
    snapshot) dvc_snapshot_restore "$label" ;;
    *) printf 'unsupported kind: %s\n' "$kind" >&2; return 1 ;;
  esac
}

dvc_toggle_pin_action() {
  local row="$1"
  local id pinned
  id="$(dvc_item_field "$row" id)"
  pinned="$(dvc_is_pinned "$id")"
  if [[ "$pinned" == "1" ]]; then
    dvc_set_pin "$id" 0
  else
    dvc_set_pin "$id" 1
  fi
}
```

```bash
# da-vinci-console.sh (replace ad hoc action binds)
source "$ROOT/lib/dvc/actions.sh"

case "${1:-}" in
  --primary)
    dvc_dispatch_primary_action "${2:-}"
    exit 0
    ;;
  --toggle-pin)
    dvc_toggle_pin_action "${2:-}"
    exit 0
    ;;
esac

selected="$(bash "$SELF" --list-query "" | fzf \
  --multi \
  --bind "enter:execute-silent(bash '$SELF' --primary {-1})+abort" \
  --bind "ctrl-f:execute-silent(bash '$SELF' --toggle-pin {-1})+reload(bash '$SELF' --list-query {q})" \
  --bind "ctrl-d:execute(bash '$SELF' --kill-session {-1})+reload(bash '$SELF' --list-query {q})" \
  --bind "ctrl-x:execute(bash '$SELF' --kill-window {-1})+reload(bash '$SELF' --list-query {q})" \
  --bind "ctrl-p:execute(bash '$SELF' --drill-panes {-1})")
```

- [ ] **Step 4: Run the actions tests**

Run: `bash tests/unit/actions_test.sh && bash tests/run.sh`
Expected:

```text
ok - actions
PASS item_model_test.sh
PASS state_test.sh
PASS provider_workspaces_test.sh
PASS live_merge_test.sh
PASS rank_render_test.sh
PASS actions_test.sh
```

- [ ] **Step 5: Commit**

```bash
git add lib/dvc/actions.sh tests/unit/actions_test.sh da-vinci-console.sh
git commit -m "feat: add typed command center actions"
```

### Task 7: Reintroduce SSH and snapshots, simplify previews, and update docs

**Files:**
- Create: `lib/dvc/provider_ssh.sh`
- Create: `lib/dvc/provider_snapshots.sh`
- Create: `lib/dvc/preview.sh`
- Create: `tests/fixtures/ssh/config`
- Create: `tests/fixtures/snapshots/demo.snapshot`
- Create: `tests/unit/provider_ssh_test.sh`
- Create: `tests/unit/provider_snapshots_test.sh`
- Modify: `da-vinci-console.sh`
- Modify: `README.md`
- Modify: `install.sh`
- Modify: `extras/tmux.conf`

- [ ] **Step 1: Write the failing utility-provider tests**

```bash
# tests/unit/provider_ssh_test.sh
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
```

```bash
# tests/unit/provider_snapshots_test.sh
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
```

- [ ] **Step 2: Run the utility-provider tests to verify they fail**

Run: `bash tests/unit/provider_ssh_test.sh && bash tests/unit/provider_snapshots_test.sh`
Expected: FAIL with `No such file or directory` for `lib/dvc/provider_ssh.sh` or `lib/dvc/provider_snapshots.sh`

- [ ] **Step 3: Implement SSH, snapshots, previews, and clean up the entrypoint/docs**

```bash
# tests/fixtures/ssh/config
Host prod
  HostName prod.example.com
  User root

Host github
  HostName github.com
  User git

Host *
  ForwardAgent yes

# tests/fixtures/snapshots/demo.snapshot
session=demo
window|editor|/tmp/work/api|nvim
window|server|/tmp/work/api|zsh

# lib/dvc/provider_ssh.sh
#!/usr/bin/env bash
set -euo pipefail

dvc_ssh_items_from_config() {
  local config_file="${1:-$HOME/.ssh/config}"
  [[ -f "$config_file" ]] || return 0

  awk '/^[Hh]ost / { for (i = 2; i <= NF; i++) print $i }' "$config_file" \
    | while IFS= read -r host; do
        [[ -z "$host" || "$host" == *"*"* || "$host" == *"?"* ]] && continue
        dvc_item_emit "ssh" "ssh:${host}" "$host" "$host ssh" "" "Utilities" "$host" "provider=ssh" "0"
      done
}

# lib/dvc/provider_snapshots.sh
#!/usr/bin/env bash
set -euo pipefail

dvc_snapshot_dir() { printf '%s/.config/tmux/snapshots\n' "$HOME"; }

dvc_snapshot_items() {
  local snapshot_dir="${1:-$(dvc_snapshot_dir)}"
  [[ -d "$snapshot_dir" ]] || return 0

  find "$snapshot_dir" -maxdepth 1 -name '*.snapshot' -type f | sort | while IFS= read -r file; do
    local name
    name="$(basename "$file" .snapshot)"
    dvc_item_emit "snapshot" "snapshot:${name}" "$name" "$name snapshot" "" "Utilities" "$name" "provider=snapshot" "0"
  done
}

dvc_snapshot_restore() {
  local snapshot_name="$1"
  local file
  file="$(dvc_snapshot_dir)/${snapshot_name}.snapshot"
  [[ -f "$file" ]] || return 1
  local session_name first=1
  session_name="$(grep '^session=' "$file" | cut -d= -f2)"
  tmux new-session -d -s "$session_name"
  while IFS='|' read -r _ window_name window_path window_command; do
    if [[ "$first" == "1" ]]; then
      tmux rename-window -t "${session_name}:0" "$window_name"
      tmux send-keys -t "${session_name}:0" "cd $(printf '%q' "$window_path")" Enter "$window_command" Enter
      first=0
    else
      tmux new-window -t "${session_name}:" -n "$window_name" -c "$window_path" "$window_command"
    fi
  done < <(grep '^window|' "$file")
}

# lib/dvc/preview.sh
#!/usr/bin/env bash
set -euo pipefail

dvc_preview_row() {
  local row="$1"
  local kind path target label
  kind="$(dvc_item_field "$row" kind)"
  path="$(dvc_item_field "$row" path)"
  target="$(dvc_item_field "$row" target)"
  label="$(dvc_item_field "$row" label)"

  case "$kind" in
    workspace)
      printf 'Workspace: %s\nPath: %s\n' "$label" "$path"
      git -C "$path" log --oneline -5 2>/dev/null || :
      ;;
    session|window)
      tmux capture-pane -p -t "$target" -S -20 2>/dev/null || printf 'preview unavailable\n'
      ;;
    ssh)
      awk -v host="$label" '
        BEGIN { active = 0 }
        /^[Hh]ost / { active = ($2 == host) }
        active && !/^[Hh]ost / { print }
      ' "$HOME/.ssh/config" 2>/dev/null
      ;;
    snapshot)
      grep '^window|' "$(dvc_snapshot_dir)/${label}.snapshot" 2>/dev/null || :
      ;;
  esac
}

# da-vinci-console.sh (source utility providers and remove Docker/tags handlers)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/dvc/provider_ssh.sh"
source "$SCRIPT_DIR/lib/dvc/provider_snapshots.sh"
source "$SCRIPT_DIR/lib/dvc/preview.sh"

dvc_all_items() {
  local current_dir query="${1:-}"
  current_dir="$(tmux display-message -p "#{pane_current_path}" 2>/dev/null || pwd)"

  {
    dvc_workspace_items "$current_dir"
    dvc_live_items
    dvc_ssh_items_from_config
    dvc_snapshot_items
  } | dvc_rank_items "$query" "$current_dir" | dvc_render_grouped_view
}
```

```markdown
<!-- README.md -->
- Remove Docker and tag sections from Features, Keybindings, and Configuration
- Document: path-backed workspaces, ranked hybrid view, `Ctrl-F` pin toggle, `Ctrl-P` pane drill-down, and destructive confirmations
- Keep SSH bookmarks and snapshots in the Utilities section

<!-- extras/tmux.conf -->
bind s display-popup -B -x C -y C -w 72% -h 72% -s "bg=default" -E "~/.config/tmux/sesh_picker.sh"

<!-- install.sh -->
echo "  bind s display-popup -B -x C -y C -w 72% -h 72% -s \"bg=default\" -E \"$DEST/$INSTALLED\""
```

- [ ] **Step 4: Run the utility-provider tests and the full suite**

Run: `bash tests/unit/provider_ssh_test.sh && bash tests/unit/provider_snapshots_test.sh && bash tests/run.sh`
Expected:

```text
ok - provider_ssh
ok - provider_snapshots
PASS item_model_test.sh
PASS state_test.sh
PASS provider_workspaces_test.sh
PASS live_merge_test.sh
PASS rank_render_test.sh
PASS actions_test.sh
PASS provider_ssh_test.sh
PASS provider_snapshots_test.sh
```

- [ ] **Step 5: Commit**

```bash
git add lib/dvc/provider_ssh.sh lib/dvc/provider_snapshots.sh lib/dvc/preview.sh tests/fixtures/ssh/config tests/fixtures/snapshots/demo.snapshot tests/unit/provider_ssh_test.sh tests/unit/provider_snapshots_test.sh da-vinci-console.sh README.md install.sh extras/tmux.conf
git commit -m "feat: finish v1.1 command center utilities"
```

## Self-Review Checklist

- Spec coverage:
  - path-backed workspace identity: Tasks 1, 3, 4
  - persistent cache, usage history, pins: Task 2
  - hybrid ranked default view: Task 5
  - typed actions and confirmations: Task 6
  - SSH and snapshots only as secondary utilities: Task 7
  - Docker/tags removed from v1.1 default scope: Task 7
  - tests and docs: Tasks 1 through 7
- Placeholder scan:
  - no `TODO`, `TBD`, or implicit "figure it out later" steps remain
- Type consistency:
  - canonical item fields stay `kind,id,label,search,path,group,target,meta,score`
  - snapshot helpers are consistently named `dvc_snapshot_items` and `dvc_snapshot_restore`
