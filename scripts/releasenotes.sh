#!/usr/bin/env bash
set -euo pipefail

CLIFF_BIN=${GIT_CLIFF:-git-cliff}
CONFIG=${GIT_CLIFF_CONFIG:-cliff.toml}

if ! command -v "$CLIFF_BIN" >/dev/null 2>&1; then
  echo "git-cliff is required but was not found in PATH" >&2
  exit 1
fi

if [ ! -f "$CONFIG" ]; then
  echo "Unable to locate git-cliff config: $CONFIG" >&2
  exit 1
fi

args=(--config "$CONFIG" --strip header)

if git describe --tags --exact-match >/dev/null 2>&1; then
  args+=(--current)
else
  args+=(--unreleased)
fi

notes="$("$CLIFF_BIN" "${args[@]}")"

if [ -z "$notes" ]; then
  exit 0
fi

first_line=$(printf '%s\n' "$notes" | head -n1)
rest=$(printf '%s\n' "$notes" | tail -n +2)

if printf '%s' "$first_line" | grep -q '^## '; then
  first_line='## Release Notes'
fi

printf '%s\n' "$first_line"
if [ -n "$rest" ]; then
  printf '%s\n' "$rest"
fi
