#!/usr/bin/env bash
set -euo pipefail

dvc_query_score() {
  local query="${1,,}"
  local search="${2,,}"

  [[ -z "$query" ]] && {
    printf '0\n'
    return
  }

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

    usage="${usage:-0}"
    pin="${pin:-0}"

    [[ "$meta" == *"live=1"* || "$meta" == *"attached=1"* ]] && score=$((score + 75))
    [[ -n "$path" && "$path" == "$current_dir"* ]] && score=$((score + 25))
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
