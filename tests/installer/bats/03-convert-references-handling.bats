#!/usr/bin/env bats
# 03-convert-references-handling.bats — Verify references/ handling for each tool.
#
# The with-references fixture has 2 reference files (guide.md, glossary.md).
# Strategy per contract:
#   copy-alongside: claude-code, antigravity, gemini-cli, opencode, openclaw, copilot
#   inline-bundle:  cursor, qwen, kimi
#   skip+warn:      aider, windsurf
#
# Uses setup_file so convert runs ONCE for all 21 tests.

setup_file() {
  export REPO_ROOT
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  local SCRIPTS_DIR="$REPO_ROOT/scripts"
  local FIXTURE_SKILLS="$REPO_ROOT/tests/installer/fixtures/skills"

  export FAKEREPO
  FAKEREPO="$(mktemp -d /tmp/ats-fakerepo.XXXXXX)"
  mkdir -p "$FAKEREPO/scripts/lib"
  cp "$SCRIPTS_DIR/convert.sh"         "$FAKEREPO/scripts/convert.sh"
  cp "$SCRIPTS_DIR/lib/frontmatter.sh" "$FAKEREPO/scripts/lib/frontmatter.sh"
  cp "$SCRIPTS_DIR/lib/slug.sh"        "$FAKEREPO/scripts/lib/slug.sh"
  cp "$SCRIPTS_DIR/lib/term.sh"        "$FAKEREPO/scripts/lib/term.sh"
  cp "$SCRIPTS_DIR/lib/platform.sh"    "$FAKEREPO/scripts/lib/platform.sh"
  cp -r "$FIXTURE_SKILLS"              "$FAKEREPO/skills"

  export OUTDIR
  OUTDIR="$(mktemp -d /tmp/ats-out.XXXXXX)"

  # Run all tools once; capture all stderr
  bash "$FAKEREPO/scripts/convert.sh" --out "$OUTDIR" 2>"$OUTDIR/.stderr.all"
}

teardown_file() {
  rm -rf "$FAKEREPO" "$OUTDIR"
}

# ---------------------------------------------------------------------------
# copy-alongside tools
# ---------------------------------------------------------------------------

@test "claude-code: references/ copied alongside with-references SKILL.md" {
  [ -d "$OUTDIR/claude-code/roles/with-references/references" ]
  [ -f "$OUTDIR/claude-code/roles/with-references/references/guide.md" ]
  [ -f "$OUTDIR/claude-code/roles/with-references/references/glossary.md" ]
}

@test "antigravity: references/ copied alongside with-references SKILL.md" {
  [ -d "$OUTDIR/antigravity/with-references/references" ]
  [ -f "$OUTDIR/antigravity/with-references/references/guide.md" ]
  [ -f "$OUTDIR/antigravity/with-references/references/glossary.md" ]
}

@test "gemini-cli: references/ copied alongside with-references SKILL.md" {
  [ -d "$OUTDIR/gemini-cli/skills/with-references/references" ]
  [ -f "$OUTDIR/gemini-cli/skills/with-references/references/guide.md" ]
  [ -f "$OUTDIR/gemini-cli/skills/with-references/references/glossary.md" ]
}

@test "opencode: references copied as <slug>-references/ sibling directory" {
  [ -d "$OUTDIR/opencode/agents/with-references-references" ]
  [ -f "$OUTDIR/opencode/agents/with-references-references/guide.md" ]
  [ -f "$OUTDIR/opencode/agents/with-references-references/glossary.md" ]
}

@test "openclaw: references/ copied under the skill's directory" {
  [ -d "$OUTDIR/openclaw/with-references/references" ]
  [ -f "$OUTDIR/openclaw/with-references/references/guide.md" ]
  [ -f "$OUTDIR/openclaw/with-references/references/glossary.md" ]
}

@test "copilot: references copied as <slug>-references/ sibling directory" {
  [ -d "$OUTDIR/copilot/with-references-references" ]
  [ -f "$OUTDIR/copilot/with-references-references/guide.md" ]
  [ -f "$OUTDIR/copilot/with-references-references/glossary.md" ]
}

# ---------------------------------------------------------------------------
# inline-bundle tools — references content embedded in skill body
# ---------------------------------------------------------------------------

@test "cursor: with-references.mdc contains '## Reference: guide' header" {
  grep -q "^## Reference: guide" "$OUTDIR/cursor/rules/with-references.mdc"
}

@test "cursor: with-references.mdc contains '## Reference: glossary' header" {
  grep -q "^## Reference: glossary" "$OUTDIR/cursor/rules/with-references.mdc"
}

@test "cursor: with-references.mdc contains content from guide.md" {
  grep -q "With-References Guide" "$OUTDIR/cursor/rules/with-references.mdc"
}

@test "cursor: with-references.mdc contains content from glossary.md" {
  grep -q "With-References Glossary" "$OUTDIR/cursor/rules/with-references.mdc"
}

@test "cursor: with-references.mdc has NO separate references/ directory" {
  [ ! -d "$OUTDIR/cursor/references" ]
}

@test "qwen: with-references.md contains '## Reference: guide' header" {
  grep -q "^## Reference: guide" "$OUTDIR/qwen/agents/with-references.md"
}

@test "qwen: with-references.md contains '## Reference: glossary' header" {
  grep -q "^## Reference: glossary" "$OUTDIR/qwen/agents/with-references.md"
}

@test "qwen: with-references.md contains content from both reference files" {
  grep -q "With-References Guide" "$OUTDIR/qwen/agents/with-references.md"
  grep -q "With-References Glossary" "$OUTDIR/qwen/agents/with-references.md"
}

@test "kimi: with-references system.md contains '## Reference: guide' header" {
  grep -q "^## Reference: guide" "$OUTDIR/kimi/with-references/system.md"
}

@test "kimi: with-references system.md contains '## Reference: glossary' header" {
  grep -q "^## Reference: glossary" "$OUTDIR/kimi/with-references/system.md"
}

@test "kimi: with-references system.md contains content from both reference files" {
  grep -q "With-References Guide" "$OUTDIR/kimi/with-references/system.md"
  grep -q "With-References Glossary" "$OUTDIR/kimi/with-references/system.md"
}

# ---------------------------------------------------------------------------
# skip-and-warn tools
# ---------------------------------------------------------------------------

@test "aider: references content is NOT in CONVENTIONS.md" {
  ! grep -q "copy-alongside:" "$OUTDIR/aider/CONVENTIONS.md"
}

@test "aider: stderr contains skip note for with-references" {
  grep -q "skipped references for with-references" "$OUTDIR/.stderr.all"
}

@test "windsurf: references content is NOT in .windsurfrules" {
  ! grep -q "copy-alongside:" "$OUTDIR/windsurf/.windsurfrules"
}

@test "windsurf: stderr contains skip note for with-references" {
  grep -q "skipped references for with-references" "$OUTDIR/.stderr.all"
}
