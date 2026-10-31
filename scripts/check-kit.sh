#!/usr/bin/env bash
# Validate a kit directory.
#
# Usage: scripts/check-kit.sh <kit-or-path>
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <kit>" >&2
  exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

arg=$1
if [ -d "$arg" ]; then
  dir=$(cd "$arg" && pwd)
elif [ -d "$REPO_ROOT/$arg" ]; then
  dir=$(cd "$REPO_ROOT/$arg" && pwd)
else
  echo "error: kit directory not found: $arg" >&2
  exit 1
fi

name=$(basename "$dir")
yaml="$dir/$name.yaml"
dockerfile="$dir/$name.dockerfile"

fail=0
if [ ! -f "$yaml" ]; then
  echo "error: missing $name.yaml in $dir" >&2
  fail=1
fi
if [ ! -f "$dockerfile" ]; then
  echo "error: missing $name.dockerfile in $dir" >&2
  fail=1
fi
if [ "$fail" -ne 0 ]; then
  exit 1
fi

# Required top-level fields.
for key in schemaVersion kind; do
  if ! grep -Eq "^[[:space:]]*${key}:" "$yaml"; then
    echo "error: $yaml missing top-level '$key'" >&2
    fail=1
  fi
done

# syntax is declared as a leading comment: # syntax=...
if ! grep -Eq '^[[:space:]]*#[[:space:]]*syntax[[:space:]]*=' "$yaml"; then
  echo "error: $yaml missing '# syntax=...' declaration" >&2
  fail=1
fi

# Ensure schemaVersion/kind are non-empty.
sv=$(awk '/^[[:space:]]*schemaVersion:/ {sub(/^[^:]*:[[:space:]]*/,""); gsub(/["'"'"']/,""); print; exit}' "$yaml")
kd=$(awk '/^[[:space:]]*kind:/ {sub(/^[^:]*:[[:space:]]*/,""); gsub(/["'"'"']/,""); print; exit}' "$yaml")
if [ -z "$sv" ]; then
  echo "error: schemaVersion is empty in $yaml" >&2
  fail=1
fi
if [ -z "$kd" ]; then
  echo "error: kind is empty in $yaml" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "ok: $name"
