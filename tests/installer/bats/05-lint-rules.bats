#!/usr/bin/env bats
# 05-lint-rules.bats — Validate scripts/lint-skills.sh rules against fixtures.
#
# Contract: lint-rules.md v1.1.0
# Key: description length is WARN-only (never ERROR) per v1.1.0 changelog.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  LINT="$REPO_ROOT/scripts/lint-skills.sh"
  FIXTURES="$REPO_ROOT/tests/installer/fixtures"
  VALID_SKILLS="$FIXTURES/skills"
  MALFORMED="$FIXTURES/malformed"

  # Temp dir for lint output
  TMPDIR_LINT="$(mktemp -d /tmp/ats-lint.XXXXXX)"
}

teardown() {
  rm -rf "$TMPDIR_LINT"
}

# ---------------------------------------------------------------------------
# Clean fixture: valid skills pass with exit 0
# ---------------------------------------------------------------------------

@test "lint: minimal-agent passes with exit 0" {
  run bash "$LINT" "$VALID_SKILLS/roles/minimal-agent/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "lint: full-agent passes with exit 0" {
  run bash "$LINT" "$VALID_SKILLS/roles/full-agent/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "lint: cc-only passes with exit 0" {
  run bash "$LINT" "$VALID_SKILLS/meta/cc-only/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "lint: no-headers passes with exit 0" {
  run bash "$LINT" "$VALID_SKILLS/meta/no-headers/SKILL.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Malformed frontmatter: missing closing ---
# ---------------------------------------------------------------------------

@test "lint: missing closing --- causes ERROR and exit 1" {
  run bash "$LINT" "$MALFORMED/no-closing-fence.md"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "ERROR"
}

@test "lint: missing opening --- causes ERROR and exit 1" {
  run bash "$LINT" "$MALFORMED/no-opening-fence.md"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "ERROR"
}

# ---------------------------------------------------------------------------
# Missing required 'name' field
# ---------------------------------------------------------------------------

@test "lint: missing 'name' field causes ERROR and exit 1" {
  run bash "$LINT" "$MALFORMED/missing-name.md"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "ERROR"
  echo "$output" | grep -qi "name"
}

# ---------------------------------------------------------------------------
# Name does not match directory
# ---------------------------------------------------------------------------

@test "lint: name mismatch with directory causes ERROR and exit 1" {
  # name-mismatch-dir/ contains SKILL.md with name: wrong-name
  run bash "$LINT" "$MALFORMED/name-mismatch-dir/SKILL.md"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "ERROR"
  echo "$output" | grep -qi "does not match\|mismatch"
}

# ---------------------------------------------------------------------------
# Invalid semver version
# ---------------------------------------------------------------------------

@test "lint: invalid semver version causes ERROR and exit 1" {
  run bash "$LINT" "$MALFORMED/bad-semver.md"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "ERROR"
  echo "$output" | grep -qi "semver\|version"
}

# ---------------------------------------------------------------------------
# Description length — WARN only, never ERROR (contract v1.1.0)
# ---------------------------------------------------------------------------

@test "lint: 800-char description produces WARN not ERROR (exit 0)" {
  run bash "$LINT" "$VALID_SKILLS/meta/long-desc/SKILL.md"
  # Must exit 0 (no errors — only warnings)
  [ "$status" -eq 0 ]
  # Should have a WARN about description length
  echo "$output" | grep -qi "WARN\|warn"
}

@test "lint: 800-char description output does NOT contain ERROR" {
  run bash "$LINT" "$VALID_SKILLS/meta/long-desc/SKILL.md"
  ! echo "$output" | grep -q "^ERROR"
}

# ---------------------------------------------------------------------------
# Body word count < 50 — WARN only
# ---------------------------------------------------------------------------

@test "lint: body word count < 50 produces WARN not ERROR" {
  # Create a temp fixture with short body
  TMPSKILL_DIR="$TMPDIR_LINT/short-body"
  mkdir -p "$TMPSKILL_DIR"
  cat > "$TMPSKILL_DIR/SKILL.md" <<'EOF'
---
name: short-body
version: 1.0.0
description: Apply short-body when testing body word count warning for lint.
---

This body has fewer than fifty words total. Testing lint WARN.
EOF
  run bash "$LINT" "$TMPSKILL_DIR/SKILL.md"
  # Exit 0 (warn only, no error for short body)
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "WARN\|stub\|words"
}

# ---------------------------------------------------------------------------
# Cross-skill duplicate name — ERROR
# ---------------------------------------------------------------------------

@test "lint: duplicate name across two skills causes ERROR and exit 1" {
  # Run lint on both duplicate fixtures together
  run bash "$LINT" \
    "$VALID_SKILLS/roles/duplicate-name-a/SKILL.md" \
    "$VALID_SKILLS/roles/duplicate-name-b/SKILL.md"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "ERROR"
  echo "$output" | grep -qi "unique\|collision\|not unique"
}

@test "lint: duplicate name error message references 'collision-test'" {
  run bash "$LINT" \
    "$VALID_SKILLS/roles/duplicate-name-a/SKILL.md" \
    "$VALID_SKILLS/roles/duplicate-name-b/SKILL.md"
  echo "$output" | grep -qi "collision-test"
}

# ---------------------------------------------------------------------------
# composes_with referencing unknown skill — WARN only
# ---------------------------------------------------------------------------

@test "lint: composes_with referencing unknown skill produces WARN not ERROR" {
  TMPSKILL_DIR="$TMPDIR_LINT/ref-unknown"
  mkdir -p "$TMPSKILL_DIR"
  cat > "$TMPSKILL_DIR/SKILL.md" <<'EOF'
---
name: ref-unknown
version: 1.0.0
description: Apply ref-unknown when testing broken composes_with reference for lint warning.
composes_with:
  - nonexistent-skill-xyz
---

## Overview

This fixture skill references a nonexistent skill in composes_with. The lint script should emit a WARN about the broken reference but must NOT emit an ERROR. The exit code must be 0.

This body is long enough to pass the fifty-word word count check for the body. More words here to ensure we are safely above the threshold and the only warning is about composes_with.
EOF
  run bash "$LINT" "$TMPSKILL_DIR/SKILL.md"
  # composes_with broken ref → WARN only, exit 0
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "WARN\|warn"
  echo "$output" | grep -qi "nonexistent-skill-xyz\|unknown"
}

# ---------------------------------------------------------------------------
# --format junit produces parseable XML
# ---------------------------------------------------------------------------

@test "lint: --format junit produces XML with testsuites root element" {
  run bash "$LINT" --format junit "$VALID_SKILLS/roles/minimal-agent/SKILL.md"
  echo "$output" | grep -q '<?xml'
  echo "$output" | grep -q '<testsuites'
  echo "$output" | grep -q '</testsuites>'
}

@test "lint: --format junit XML is parseable by python3 xml.etree" {
  run bash "$LINT" --format junit "$VALID_SKILLS/roles/minimal-agent/SKILL.md"
  echo "$output" | python3 -c "import sys, xml.etree.ElementTree as ET; ET.parse(sys.stdin)"
}

@test "lint: --format junit with errors produces failure elements" {
  run bash "$LINT" --format junit "$MALFORMED/no-closing-fence.md"
  echo "$output" | grep -q '<failure'
}

# ---------------------------------------------------------------------------
# Exit code 2 on bad argument
# ---------------------------------------------------------------------------

@test "lint: unknown option exits with code 2" {
  run bash "$LINT" --unknown-flag-xyz
  [ "$status" -eq 2 ]
}

@test "lint: --format with invalid value exits with code 2" {
  run bash "$LINT" --format markdown
  [ "$status" -eq 2 ]
}
