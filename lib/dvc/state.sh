#!/usr/bin/env bash
set -euo pipefail

dvc_state_dir() {
  printf '%s/da-vinci-console\n' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

dvc_workspace_cache_file() {
  printf '%s/workspaces.tsv\n' "$(dvc_state_dir)"
}

dvc_usage_file() {
  printf '%s/usage.tsv\n' "$(dvc_state_dir)"
}

dvc_pins_file() {
  printf '%s/pins.tsv\n' "$(dvc_state_dir)"
}

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
  [[ -f "$usage_file" ]] || {
    printf '0\n'
    return
  }

  awk -F '\t' -v id="$id" '$1 == id { print ($3 * 10) }' "$usage_file" | tail -n 1
}

dvc_is_pinned() {
  local id="$1"
  local pins_file

  pins_file="$(dvc_pins_file)"
  [[ -f "$pins_file" ]] || {
    printf '0\n'
    return
  }

  grep -qx "$id" "$pins_file" && printf '1\n' || printf '0\n'
}

dvc_set_pin() {
  local id="$1"
  local desired="$2"
  local pins_file tmp_file

  dvc_ensure_state_dir
  pins_file="$(dvc_pins_file)"
  tmp_file="$(mktemp)"

  if [[ -f "$pins_file" ]]; then
    grep -vx "$id" "$pins_file" >"$tmp_file" || true
  else
    : >"$tmp_file"
  fi

  [[ "$desired" == "1" ]] && printf '%s\n' "$id" >>"$tmp_file"
  mv "$tmp_file" "$pins_file"
}
