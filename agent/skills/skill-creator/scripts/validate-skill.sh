#!/usr/bin/env bash
#
# validate-skill.sh — check a SKILL.md against opencode's skill rules.
#
# Usage: ./validate-skill.sh <path-to-skill-dir-or-SKILL.md>
# Exit:  0 = valid, 1 = problems found, 2 = bad usage.
#
# Rules enforced (see https://opencode.ai/docs/skills/):
#   - file must be named exactly SKILL.md
#   - YAML frontmatter must open on line 1 and close
#   - name: required, 1-64 chars, ^[a-z0-9]+(-[a-z0-9]+)*$, matches folder name
#   - description: required, 1-1024 chars
#   - optional: license, compatibility, metadata (flat string map)
#
# This is a lint, not a YAML parser. It catches the failure modes opencode
# actually hits: wrong filename, missing frontmatter, bad name, name/folder
# mismatch, missing or oversized description.

set -uo pipefail

usage() {
  echo "usage: $(basename "$0") <skill-dir|SKILL.md>" >&2
  exit 2
}

[ $# -eq 1 ] || usage

target=$1
if [ -d "$target" ]; then
  skill_dir=$(cd "$target" && pwd)
  file="$skill_dir/SKILL.md"
else
  file=$target
  skill_dir=$(dirname "$file")
fi

[ -f "$file" ] || { echo "FAIL: no SKILL.md at $file"; exit 1; }

problems=0
warn() { echo "WARN: $*"; }
fail() { echo "FAIL: $*"; problems=$((problems + 1)); }

base=$(basename "$file")
[ "$base" = "SKILL.md" ] || fail "filename is '$base', must be exactly 'SKILL.md'"

# Frontmatter must start on line 1.
first=$(head -n 1 "$file")
[ "$first" = "---" ] || fail "line 1 is not '---' (frontmatter must open on line 1)"

# Extract the frontmatter block (line 1 up to the next '---').
fm=$(awk 'NR==1 && $0=="---" {inb=1; next} inb && $0=="---" {exit} inb {print}' "$file")
[ -n "$fm" ] || fail "could not locate a closing '---' for the frontmatter"

field() {
  # field <key> -> raw value, stripping surrounding quotes
  printf '%s\n' "$fm" \
    | awk -v k="$1" '
        $0 ~ "^"k"[ \t]*:" {
          sub("^"k"[ \t]*:[ \t]*", "")
          gsub(/^["'"'"']|["'"'"']$/, "")
          print
          exit
        }'
}

name=$(field name)
desc=$(field description)

# --- name ---
if [ -z "$name" ]; then
  fail "frontmatter is missing 'name'"
else
  len=${#name}
  [ "$len" -ge 1 ] && [ "$len" -le 64 ] \
    || fail "name is $len chars, must be 1-64"
  if ! printf '%s' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    fail "name '$name' must match ^[a-z0-9]+(-[a-z0-9]+)*\$"
  fi
  dir_base=$(basename "$skill_dir")
  [ "$name" = "$dir_base" ] \
    || fail "name '$name' does not match folder name '$dir_base'"
fi

# --- description ---
if [ -z "$desc" ]; then
  fail "frontmatter is missing 'description' (skills without one are never shown to the model)"
else
  dlen=${#desc}
  [ "$dlen" -le 1024 ] || fail "description is $dlen chars, max 1024"
  [ "$dlen" -ge 20 ] \
    || warn "description is only $dlen chars — likely too vague to trigger reliably"
  printf '%s' "$desc" | grep -qi 'use when\|use this when\|triggers include' \
    || warn "description does not say when to use it — the model selects skills on this text alone"
fi

# --- unknown top-level frontmatter keys ---
while IFS= read -r key; do
  case "$key" in
    name|description|license|compatibility|metadata|slash) ;;
    '') ;;
    *) warn "unrecognized frontmatter key '$key' (opencode ignores it)" ;;
  esac
done <<EOF
$(printf '%s\n' "$fm" | grep -E '^[A-Za-z_][A-Za-z0-9_-]*:' | cut -d: -f1)
EOF

# --- body ---
body=$(awk 'NR==1 && $0=="---" {inb=1; next} inb && $0=="---" {inb=0; next} !inb {print}' "$file")
if [ -z "$(printf '%s' "$body" | tr -d '[:space:]')" ]; then
  fail "body is empty — frontmatter alone is not a skill"
fi
blines=$(printf '%s\n' "$body" | grep -c .)
[ "$blines" -le 500 ] \
  || warn "body is $blines non-empty lines; consider moving detail into references/"

# --- collision check against sibling skills ---
siblings=$(dirname "$skill_dir")
if [ -d "$siblings" ]; then
  dupes=$(grep -rl "^name: *$(printf '%s' "${name:-__none__}")$" "$siblings" --include=SKILL.md 2>/dev/null \
    | grep -v "^$file$")
  [ -n "$dupes" ] && warn "another skill also declares name '$name': $dupes"
fi

echo
if [ "$problems" -gt 0 ]; then
  echo "INVALID: $problems problem(s) in $file"
  exit 1
fi
echo "OK: $file (name='$name', description=${#desc} chars, body=$blines lines)"
echo "Restart opencode for the skill to be discovered."