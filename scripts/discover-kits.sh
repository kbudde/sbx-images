#!/usr/bin/env bash
# Print every kit directory at the repo root, one per line, sorted.
#
# A kit is any directory containing <dir>/<dir>.yaml (e.g. opencode2/opencode2.yaml).
# `agent/` is not a kit because it has no matching <dir>/<dir>.yaml.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR/.."

for d in */; do
  [ -d "$d" ] || continue
  name="${d%/}"
  [ -f "$name/$name.yaml" ] || continue
  printf '%s\n' "$name"
done | sort -u
