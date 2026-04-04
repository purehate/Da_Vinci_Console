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
