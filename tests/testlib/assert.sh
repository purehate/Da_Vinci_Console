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
