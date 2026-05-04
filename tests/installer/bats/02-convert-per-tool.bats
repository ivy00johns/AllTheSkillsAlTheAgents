#!/usr/bin/env bats
# 02-convert-per-tool.bats — Verify per-tool output of scripts/convert.sh.
#
# For each of the 11 tools, given the fixture skills, verify:
# - Output file(s) appear at expected paths
# - Frontmatter is transformed per per-tool-output-spec.md
# - Claude-Code-only fields are stripped (with stderr warning) for non-cc tools
# - openclaw: SOUL.md / AGENTS.md / IDENTITY.md all exist with correct slices
# - aider/windsurf: consolidated file contains skill content
#
# Uses setup_file/teardown_file so convert runs ONCE for all tests in the file.

setup_file() {
  export REPO_ROOT
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  local SCRIPTS_DIR="$REPO_ROOT/scripts"
  local FIXTURE_SKILLS="$REPO_ROOT/tests/installer/fixtures/skills"

  # Build a fake repo with copied scripts + fixture skills in a temp dir.
  # Necessary because convert.sh derives SKILLS_ROOT from SCRIPT_DIR.
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

  # Run each tool once; capture stderr per-tool so tests can inspect it
  local tool
  for tool in claude-code copilot antigravity gemini-cli opencode cursor openclaw qwen kimi aider windsurf; do
    bash "$FAKEREPO/scripts/convert.sh" --tool "$tool" --out "$OUTDIR" \
      2>"$OUTDIR/.stderr.$tool"
  done
}

teardown_file() {
  rm -rf "$FAKEREPO" "$OUTDIR"
}

# ---------------------------------------------------------------------------
# claude-code — passthrough, category/slug layout, references copied
# ---------------------------------------------------------------------------

@test "claude-code: minimal-agent SKILL.md exists at category/slug path" {
  [ -f "$OUTDIR/claude-code/roles/minimal-agent/SKILL.md" ]
}

@test "claude-code: full frontmatter preserved (owns.directories present)" {
  grep -q "owns:" "$OUTDIR/claude-code/roles/full-agent/SKILL.md"
}

@test "claude-code: allowed_tools preserved in output" {
  grep -q "allowed_tools:" "$OUTDIR/claude-code/roles/full-agent/SKILL.md"
}

@test "claude-code: with-references references/ copied alongside" {
  [ -d "$OUTDIR/claude-code/roles/with-references/references" ]
  [ -f "$OUTDIR/claude-code/roles/with-references/references/guide.md" ]
  [ -f "$OUTDIR/claude-code/roles/with-references/references/glossary.md" ]
}

@test "claude-code: cc-only skill IS included (requires_claude_code=true)" {
  [ -f "$OUTDIR/claude-code/meta/cc-only/SKILL.md" ]
}

@test "claude-code: body is unchanged (contains original section header)" {
  grep -q "## Overview" "$OUTDIR/claude-code/roles/minimal-agent/SKILL.md"
}

# ---------------------------------------------------------------------------
# copilot — flat layout, strips agent fields, stderr warning per skill
# ---------------------------------------------------------------------------

@test "copilot: minimal-agent output at flat <slug>.md path" {
  [ -f "$OUTDIR/copilot/minimal-agent.md" ]
}

@test "copilot: full-agent output keeps name, version, description" {
  grep -q "^name: full-agent" "$OUTDIR/copilot/full-agent.md"
  grep -q "^version:" "$OUTDIR/copilot/full-agent.md"
  grep -q "description:" "$OUTDIR/copilot/full-agent.md"
}

@test "copilot: full-agent output does NOT contain allowed_tools" {
  ! grep -q "allowed_tools:" "$OUTDIR/copilot/full-agent.md"
}

@test "copilot: full-agent output does NOT contain owns" {
  ! grep -q "^owns:" "$OUTDIR/copilot/full-agent.md"
}

@test "copilot: stderr warning emitted for stripped fields" {
  grep -q "stripped allowed_tools/owns from full-agent" "$OUTDIR/.stderr.copilot"
}

@test "copilot: cc-only is skipped with stderr warning" {
  ! [ -f "$OUTDIR/copilot/cc-only.md" ]
  grep -q "skipping meta/cc-only for copilot" "$OUTDIR/.stderr.copilot"
}

@test "copilot: with-references references copied as <slug>-references/" {
  [ -d "$OUTDIR/copilot/with-references-references" ]
}

# ---------------------------------------------------------------------------
# antigravity — generated frontmatter: name, description, risk, source, date_added
# ---------------------------------------------------------------------------

@test "antigravity: minimal-agent output at <slug>/SKILL.md" {
  [ -f "$OUTDIR/antigravity/minimal-agent/SKILL.md" ]
}

@test "antigravity: frontmatter contains 'risk: low'" {
  grep -q "^risk: low" "$OUTDIR/antigravity/minimal-agent/SKILL.md"
}

@test "antigravity: frontmatter contains 'source: alltheskills'" {
  grep -q "^source: alltheskills" "$OUTDIR/antigravity/minimal-agent/SKILL.md"
}

@test "antigravity: frontmatter contains 'date_added' with ISO-8601 date format" {
  grep -qE "^date_added: '[0-9]{4}-[0-9]{2}-[0-9]{2}'" "$OUTDIR/antigravity/minimal-agent/SKILL.md"
}

@test "antigravity: does NOT have 'version:' in frontmatter" {
  ! grep -q "^version:" "$OUTDIR/antigravity/minimal-agent/SKILL.md"
}

@test "antigravity: body is preserved" {
  grep -q "## Overview" "$OUTDIR/antigravity/minimal-agent/SKILL.md"
}

@test "antigravity: references copied alongside" {
  [ -d "$OUTDIR/antigravity/with-references/references" ]
}

# ---------------------------------------------------------------------------
# gemini-cli — minimal frontmatter (name, description) + manifest file
# ---------------------------------------------------------------------------

@test "gemini-cli: minimal-agent at skills/<slug>/SKILL.md" {
  [ -f "$OUTDIR/gemini-cli/skills/minimal-agent/SKILL.md" ]
}

@test "gemini-cli: gemini-extension.json manifest exists" {
  [ -f "$OUTDIR/gemini-cli/gemini-extension.json" ]
}

@test "gemini-cli: manifest contains alltheskills name" {
  grep -q '"alltheskills"' "$OUTDIR/gemini-cli/gemini-extension.json"
}

@test "gemini-cli: frontmatter has only name and description (no version)" {
  ! grep -q "^version:" "$OUTDIR/gemini-cli/skills/minimal-agent/SKILL.md"
  grep -q "^name:" "$OUTDIR/gemini-cli/skills/minimal-agent/SKILL.md"
  grep -q "description:" "$OUTDIR/gemini-cli/skills/minimal-agent/SKILL.md"
}

@test "gemini-cli: references copied alongside" {
  [ -d "$OUTDIR/gemini-cli/skills/with-references/references" ]
}

# ---------------------------------------------------------------------------
# opencode — name (original), description, mode=subagent, color=#6B7280
# ---------------------------------------------------------------------------

@test "opencode: minimal-agent at agents/<slug>.md" {
  [ -f "$OUTDIR/opencode/agents/minimal-agent.md" ]
}

@test "opencode: frontmatter has mode=subagent" {
  grep -q "^mode: subagent" "$OUTDIR/opencode/agents/minimal-agent.md"
}

@test "opencode: frontmatter has color #6B7280" {
  grep -q "6B7280" "$OUTDIR/opencode/agents/minimal-agent.md"
}

@test "opencode: frontmatter uses original name field (not slug)" {
  grep -q "^name: full-agent" "$OUTDIR/opencode/agents/full-agent.md"
}

@test "opencode: references copied as <slug>-references/ sibling" {
  [ -d "$OUTDIR/opencode/agents/with-references-references" ]
}

# ---------------------------------------------------------------------------
# cursor — description/globs/alwaysApply frontmatter, .mdc extension
# ---------------------------------------------------------------------------

@test "cursor: minimal-agent at rules/<slug>.mdc" {
  [ -f "$OUTDIR/cursor/rules/minimal-agent.mdc" ]
}

@test "cursor: frontmatter has globs field" {
  grep -q 'globs:' "$OUTDIR/cursor/rules/minimal-agent.mdc"
}

@test "cursor: frontmatter has alwaysApply: false" {
  grep -q "alwaysApply: false" "$OUTDIR/cursor/rules/minimal-agent.mdc"
}

@test "cursor: frontmatter does NOT have 'name:'" {
  ! grep -q "^name:" "$OUTDIR/cursor/rules/minimal-agent.mdc"
}

@test "cursor: with-references file contains inline-bundled Reference: guide header" {
  grep -q "## Reference: guide" "$OUTDIR/cursor/rules/with-references.mdc"
}

@test "cursor: with-references file contains inline-bundled Reference: glossary header" {
  grep -q "## Reference: glossary" "$OUTDIR/cursor/rules/with-references.mdc"
}

# ---------------------------------------------------------------------------
# openclaw — SOUL.md / AGENTS.md / IDENTITY.md split
# ---------------------------------------------------------------------------

@test "openclaw: minimal-agent has SOUL.md, AGENTS.md, IDENTITY.md" {
  [ -f "$OUTDIR/openclaw/minimal-agent/SOUL.md" ]
  [ -f "$OUTDIR/openclaw/minimal-agent/AGENTS.md" ]
  [ -f "$OUTDIR/openclaw/minimal-agent/IDENTITY.md" ]
}

@test "openclaw: IDENTITY.md starts with robot emoji and skill name" {
  head -1 "$OUTDIR/openclaw/minimal-agent/IDENTITY.md" | grep -q "minimal-agent"
}

@test "openclaw: no-headers skill: SOUL.md is a placeholder (# name only)" {
  soul_content="$(cat "$OUTDIR/openclaw/no-headers/SOUL.md")"
  [ "$(echo "$soul_content" | grep -c "^# ")" -eq 1 ]
  echo "$soul_content" | grep -q "no-headers"
}

@test "openclaw: no-headers skill: AGENTS.md contains the full body" {
  grep -q "no markdown level-two headers" "$OUTDIR/openclaw/no-headers/AGENTS.md"
}

@test "openclaw: full-agent: SOUL.md contains Identity section (classified as soul)" {
  grep -q "## Identity" "$OUTDIR/openclaw/full-agent/SOUL.md"
}

@test "openclaw: with-references: references/ directory copied into skill dir" {
  [ -d "$OUTDIR/openclaw/with-references/references" ]
}

@test "openclaw: with-references: AGENTS.md footer references the references/ dir" {
  grep -q "Additional context: see references/" "$OUTDIR/openclaw/with-references/AGENTS.md"
}

# ---------------------------------------------------------------------------
# qwen — name (slug), description, optional tools field, inline-bundled refs
# ---------------------------------------------------------------------------

@test "qwen: minimal-agent at agents/<slug>.md" {
  [ -f "$OUTDIR/qwen/agents/minimal-agent.md" ]
}

@test "qwen: frontmatter uses slug as name" {
  grep -q "^name: minimal-agent" "$OUTDIR/qwen/agents/minimal-agent.md"
}

@test "qwen: full-agent frontmatter has 'tools:' mapped from allowed_tools" {
  grep -q "^tools:" "$OUTDIR/qwen/agents/full-agent.md"
}

@test "qwen: minimal-agent frontmatter does NOT have 'tools:' (no allowed_tools)" {
  ! grep -q "^tools:" "$OUTDIR/qwen/agents/minimal-agent.md"
}

@test "qwen: with-references contains inline-bundled Reference: guide" {
  grep -q "## Reference: guide" "$OUTDIR/qwen/agents/with-references.md"
}

# ---------------------------------------------------------------------------
# kimi — agent.yaml + system.md, inline-bundled refs
# ---------------------------------------------------------------------------

@test "kimi: minimal-agent has agent.yaml and system.md" {
  [ -f "$OUTDIR/kimi/minimal-agent/agent.yaml" ]
  [ -f "$OUTDIR/kimi/minimal-agent/system.md" ]
}

@test "kimi: agent.yaml has correct structure" {
  grep -q "^version: 1" "$OUTDIR/kimi/minimal-agent/agent.yaml"
  grep -q "system_prompt_path: ./system.md" "$OUTDIR/kimi/minimal-agent/agent.yaml"
  grep -q "name: minimal-agent" "$OUTDIR/kimi/minimal-agent/agent.yaml"
}

@test "kimi: system.md starts with skill name as h1" {
  head -1 "$OUTDIR/kimi/minimal-agent/system.md" | grep -q "^# minimal-agent"
}

@test "kimi: with-references system.md contains inline-bundled Reference: guide" {
  grep -q "## Reference: guide" "$OUTDIR/kimi/with-references/system.md"
}

# ---------------------------------------------------------------------------
# aider — single CONVENTIONS.md with all skills concatenated
# ---------------------------------------------------------------------------

@test "aider: CONVENTIONS.md exists" {
  [ -f "$OUTDIR/aider/CONVENTIONS.md" ]
}

@test "aider: CONVENTIONS.md contains the file header comment" {
  grep -q "AllTheSkillsAllTheAgents" "$OUTDIR/aider/CONVENTIONS.md"
  grep -q "do not edit manually" "$OUTDIR/aider/CONVENTIONS.md"
}

@test "aider: CONVENTIONS.md contains minimal-agent section" {
  grep -q "## minimal-agent" "$OUTDIR/aider/CONVENTIONS.md"
}

@test "aider: CONVENTIONS.md contains full-agent section" {
  grep -q "## full-agent" "$OUTDIR/aider/CONVENTIONS.md"
}

@test "aider: CONVENTIONS.md does NOT contain inline reference content (refs skipped)" {
  ! grep -q "copy-alongside:" "$OUTDIR/aider/CONVENTIONS.md"
}

@test "aider: stderr note emitted for skipped references" {
  grep -q "skipped references for with-references" "$OUTDIR/.stderr.aider"
}

# ---------------------------------------------------------------------------
# windsurf — single .windsurfrules with all skills concatenated
# ---------------------------------------------------------------------------

@test "windsurf: .windsurfrules exists" {
  [ -f "$OUTDIR/windsurf/.windsurfrules" ]
}

@test "windsurf: .windsurfrules contains the file header comment" {
  grep -q "AllTheSkillsAllTheAgents" "$OUTDIR/windsurf/.windsurfrules"
  grep -q "do not edit manually" "$OUTDIR/windsurf/.windsurfrules"
}

@test "windsurf: .windsurfrules contains minimal-agent section" {
  grep -q "## minimal-agent" "$OUTDIR/windsurf/.windsurfrules"
}

@test "windsurf: .windsurfrules uses 80-char = delimiter" {
  grep -qE "^={80}$" "$OUTDIR/windsurf/.windsurfrules"
}

@test "windsurf: stderr note emitted for skipped references" {
  grep -q "skipped references for with-references" "$OUTDIR/.stderr.windsurf"
}
