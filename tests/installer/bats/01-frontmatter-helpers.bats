#!/usr/bin/env bats
# 01-frontmatter-helpers.bats — Unit tests for scripts/lib/frontmatter.sh and slug.sh helpers.
#
# Tests: get_field, get_body, get_array, get_owns_dirs, fm_check, fm_has_field, slugify.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  LIB_DIR="$REPO_ROOT/scripts/lib"
  FIXTURES="$REPO_ROOT/tests/installer/fixtures"

  # Source the helpers (they only define functions, no side effects)
  # shellcheck disable=SC1091
  . "$LIB_DIR/frontmatter.sh"
  # shellcheck disable=SC1091
  . "$LIB_DIR/slug.sh"

  MINIMAL="$FIXTURES/skills/roles/minimal-agent/SKILL.md"
  FULL="$FIXTURES/skills/roles/full-agent/SKILL.md"
  WITH_REFS="$FIXTURES/skills/roles/with-references/SKILL.md"
  CC_ONLY="$FIXTURES/skills/meta/cc-only/SKILL.md"
  MALFORMED_CLOSE="$FIXTURES/malformed/no-closing-fence.md"
  MALFORMED_OPEN="$FIXTURES/malformed/no-opening-fence.md"
}

# ---------------------------------------------------------------------------
# get_field — scalar field extraction
# ---------------------------------------------------------------------------

@test "get_field: extracts 'name' from minimal-agent" {
  result="$(get_field "name" "$MINIMAL")"
  [ "$result" = "minimal-agent" ]
}

@test "get_field: extracts 'version' from minimal-agent" {
  result="$(get_field "version" "$MINIMAL")"
  [ "$result" = "1.0.0" ]
}

@test "get_field: extracts 'description' collapsed to one line from minimal-agent" {
  result="$(get_field "description" "$MINIMAL")"
  [ -n "$result" ]
  # Collapsed: no embedded newlines
  lines=$(printf '%s' "$result" | wc -l)
  [ "$lines" -eq 0 ]
}

@test "get_field: extracts 'name' from full-agent" {
  result="$(get_field "name" "$FULL")"
  [ "$result" = "full-agent" ]
}

@test "get_field: extracts 'version' from full-agent" {
  result="$(get_field "version" "$FULL")"
  [ "$result" = "2.1.0" ]
}

@test "get_field: extracts 'requires_claude_code' boolean as 'true'" {
  result="$(get_field "requires_claude_code" "$CC_ONLY")"
  [ "$result" = "true" ]
}

@test "get_field: extracts 'requires_claude_code' from full-agent as 'false'" {
  result="$(get_field "requires_claude_code" "$FULL")"
  [ "$result" = "false" ]
}

@test "get_field: extracts 'min_plan' from full-agent" {
  result="$(get_field "min_plan" "$FULL")"
  [ "$result" = "starter" ]
}

@test "get_field: returns empty for absent field" {
  result="$(get_field "nonexistent_field" "$MINIMAL")"
  [ -z "$result" ]
}

@test "get_field: returns empty on file with no opening fence" {
  result="$(get_field "name" "$MALFORMED_OPEN")"
  [ -z "$result" ]
}

# ---------------------------------------------------------------------------
# get_array — array field extraction
# ---------------------------------------------------------------------------

@test "get_array: extracts allowed_tools from full-agent, one per line" {
  result="$(get_array "allowed_tools" "$FULL")"
  [ -n "$result" ]
  # Should contain 'Read' as one element
  echo "$result" | grep -qxF "Read"
  echo "$result" | grep -qxF "Write"
  echo "$result" | grep -qxF "Bash"
}

@test "get_array: extracts composes_with from full-agent" {
  result="$(get_array "composes_with" "$FULL")"
  echo "$result" | grep -qxF "minimal-agent"
}

@test "get_array: returns empty for field absent from minimal-agent" {
  result="$(get_array "allowed_tools" "$MINIMAL")"
  [ -z "$result" ]
}

# ---------------------------------------------------------------------------
# get_owns_dirs — nested owns.directories extraction
# ---------------------------------------------------------------------------

@test "get_owns_dirs: extracts directories from full-agent" {
  result="$(get_owns_dirs "$FULL")"
  [ -n "$result" ]
  # Should contain the fixture directory
  echo "$result" | grep -q "tests/installer/fixtures/output/"
}

@test "get_owns_dirs: returns empty for minimal-agent (no owns)" {
  result="$(get_owns_dirs "$MINIMAL")"
  [ -z "$result" ]
}

# ---------------------------------------------------------------------------
# get_body — everything after closing ---
# ---------------------------------------------------------------------------

@test "get_body: returns non-empty body for minimal-agent" {
  result="$(get_body "$MINIMAL")"
  [ -n "$result" ]
}

@test "get_body: body does not contain frontmatter fields" {
  result="$(get_body "$MINIMAL")"
  # The frontmatter name field should not appear as 'name: minimal-agent'
  ! echo "$result" | grep -q "^name: minimal-agent"
}

@test "get_body: body starts with the first non-frontmatter line" {
  result="$(get_body "$MINIMAL")"
  # First line of body should be empty or start with ##
  first_line="$(echo "$result" | head -1)"
  # Empty line OR a markdown header is expected
  [ -z "$first_line" ] || echo "$first_line" | grep -q "^#"
}

@test "get_body: body for with-references contains Reference Handling Matrix section" {
  result="$(get_body "$WITH_REFS")"
  echo "$result" | grep -q "Reference Handling Matrix"
}

# ---------------------------------------------------------------------------
# fm_check — frontmatter wellformedness
# ---------------------------------------------------------------------------

@test "fm_check: passes on minimal-agent (well-formed)" {
  fm_check "$MINIMAL"
}

@test "fm_check: passes on full-agent (well-formed)" {
  fm_check "$FULL"
}

@test "fm_check: fails with exit 1 on no-closing-fence" {
  run fm_check "$MALFORMED_CLOSE"
  [ "$status" -eq 1 ]
}

@test "fm_check: fails with exit 1 on no-opening-fence" {
  run fm_check "$MALFORMED_OPEN"
  [ "$status" -eq 1 ]
}

@test "fm_check: prints error to stderr on malformed file" {
  run fm_check "$MALFORMED_CLOSE"
  [ "$status" -eq 1 ]
  # stderr should mention the file
  echo "$output" | grep -qi "error\|missing\|closing"
}

# ---------------------------------------------------------------------------
# fm_has_field — field presence check
# ---------------------------------------------------------------------------

@test "fm_has_field: returns 0 (true) for 'name' in minimal-agent" {
  fm_has_field "name" "$MINIMAL"
}

@test "fm_has_field: returns 0 (true) for 'requires_claude_code' in cc-only" {
  fm_has_field "requires_claude_code" "$CC_ONLY"
}

@test "fm_has_field: returns 1 (false) for 'requires_claude_code' in minimal-agent" {
  run fm_has_field "requires_claude_code" "$MINIMAL"
  [ "$status" -eq 1 ]
}

@test "fm_has_field: returns 1 (false) for absent field" {
  run fm_has_field "nonexistent_xyz" "$MINIMAL"
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# slugify — string to kebab-case
# ---------------------------------------------------------------------------

@test "slugify: lowercases and hyphenates 'Backend Agent'" {
  result="$(slugify "Backend Agent")"
  [ "$result" = "backend-agent" ]
}

@test "slugify: handles slash in 'UX/UI'" {
  result="$(slugify "UX/UI")"
  [ "$result" = "ux-ui" ]
}

@test "slugify: collapses multiple separators in 'My--Skill__Name'" {
  result="$(slugify "My--Skill__Name")"
  [ "$result" = "my-skill-name" ]
}

@test "slugify: strips leading and trailing hyphens from '-leading-trailing-'" {
  result="$(slugify "-leading-trailing-")"
  [ "$result" = "leading-trailing" ]
}

@test "slugify: handles all-lowercase input unchanged (minus special chars)" {
  result="$(slugify "already-kebab")"
  [ "$result" = "already-kebab" ]
}

@test "slugify: handles numbers correctly '2fa-agent'" {
  result="$(slugify "2FA Agent")"
  [ "$result" = "2fa-agent" ]
}
