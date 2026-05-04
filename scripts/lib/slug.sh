#!/usr/bin/env bash
# lib/slug.sh — Slug / string utilities for AllTheSkillsAllTheAgents scripts.
#
# Usage:
#   . "$(dirname "$0")/lib/slug.sh"

# ---------------------------------------------------------------------------
# slugify <string>
# Convert a string to lowercase kebab-case.  "My Skill" -> "my-skill"
# Safe for bash 3.2 — no bash 4 case transforms.
# ---------------------------------------------------------------------------
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g' \
    | sed 's/--*/-/g' \
    | sed 's/^-//;s/-$//'
}

# ---------------------------------------------------------------------------
# repeat_char <char> <n>
# Print <char> repeated <n> times with no newline.
# Bash 3.2-safe (no printf %*s trick with odd chars).
# ---------------------------------------------------------------------------
repeat_char() {
  local char="$1" n="$2" i
  for (( i=0; i<n; i++ )); do printf '%s' "$char"; done
}
