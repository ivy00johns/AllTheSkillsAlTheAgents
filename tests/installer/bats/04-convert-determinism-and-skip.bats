#!/usr/bin/env bats
# 04-convert-determinism-and-skip.bats — Determinism and requires_claude_code skip tests.
#
# Tests:
# - Run convert twice with same input — output is byte-identical (modulo date_added)
# - requires_claude_code: true skill included in claude-code, skipped for other 10 tools
# - Golden file diffs against committed expected output
#
# Uses setup_file: convert runs happen once at file load; all tests read from those.

setup_file() {
  export REPO_ROOT
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  local SCRIPTS_DIR="$REPO_ROOT/scripts"
  local FIXTURE_SKILLS="$REPO_ROOT/tests/installer/fixtures/skills"

  # ---------------------------------------------------------------------------
  # Two identical fake repos for the determinism comparison.
  # ---------------------------------------------------------------------------
  export FAKEREPO1 FAKEREPO2
  FAKEREPO1="$(mktemp -d /tmp/ats-fakerepo1.XXXXXX)"
  FAKEREPO2="$(mktemp -d /tmp/ats-fakerepo2.XXXXXX)"

  local REPO
  for REPO in "$FAKEREPO1" "$FAKEREPO2"; do
    mkdir -p "$REPO/scripts/lib"
    cp "$SCRIPTS_DIR/convert.sh"         "$REPO/scripts/convert.sh"
    cp "$SCRIPTS_DIR/lib/frontmatter.sh" "$REPO/scripts/lib/frontmatter.sh"
    cp "$SCRIPTS_DIR/lib/slug.sh"        "$REPO/scripts/lib/slug.sh"
    cp "$SCRIPTS_DIR/lib/term.sh"        "$REPO/scripts/lib/term.sh"
    cp "$SCRIPTS_DIR/lib/platform.sh"    "$REPO/scripts/lib/platform.sh"
    cp -r "$FIXTURE_SKILLS"              "$REPO/skills"
  done

  export OUTDIR1 OUTDIR2
  OUTDIR1="$(mktemp -d /tmp/ats-out1.XXXXXX)"
  OUTDIR2="$(mktemp -d /tmp/ats-out2.XXXXXX)"

  # Run all tools for the determinism two-run comparison.
  bash "$FAKEREPO1/scripts/convert.sh" --out "$OUTDIR1" 2>/dev/null
  bash "$FAKEREPO2/scripts/convert.sh" --out "$OUTDIR2" 2>/dev/null

  # Normalize date_added in both antigravity outputs
  local f
  for f in $(find "$OUTDIR1/antigravity" -name "SKILL.md" -type f 2>/dev/null); do
    sed -i.bak "s/^date_added: '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'$/date_added: 'NORMALIZED'/" "$f"
    rm -f "${f}.bak"
  done
  for f in $(find "$OUTDIR2/antigravity" -name "SKILL.md" -type f 2>/dev/null); do
    sed -i.bak "s/^date_added: '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'$/date_added: 'NORMALIZED'/" "$f"
    rm -f "${f}.bak"
  done

  # ---------------------------------------------------------------------------
  # Separate fake repo + outdir for per-tool skip tests.
  # We run each tool individually so we can capture per-tool stderr.
  # This must be a SEPARATE outdir from OUTDIR1 so the determinism diff is clean.
  # ---------------------------------------------------------------------------
  export FAKEREPO_SKIP OUTDIR_SKIP
  FAKEREPO_SKIP="$(mktemp -d /tmp/ats-fakerepo-skip.XXXXXX)"
  mkdir -p "$FAKEREPO_SKIP/scripts/lib"
  cp "$SCRIPTS_DIR/convert.sh"         "$FAKEREPO_SKIP/scripts/convert.sh"
  cp "$SCRIPTS_DIR/lib/frontmatter.sh" "$FAKEREPO_SKIP/scripts/lib/frontmatter.sh"
  cp "$SCRIPTS_DIR/lib/slug.sh"        "$FAKEREPO_SKIP/scripts/lib/slug.sh"
  cp "$SCRIPTS_DIR/lib/term.sh"        "$FAKEREPO_SKIP/scripts/lib/term.sh"
  cp "$SCRIPTS_DIR/lib/platform.sh"    "$FAKEREPO_SKIP/scripts/lib/platform.sh"
  cp -r "$FIXTURE_SKILLS"              "$FAKEREPO_SKIP/skills"

  OUTDIR_SKIP="$(mktemp -d /tmp/ats-skip.XXXXXX)"

  local tool
  for tool in claude-code copilot antigravity gemini-cli opencode cursor openclaw qwen kimi aider windsurf; do
    bash "$FAKEREPO_SKIP/scripts/convert.sh" --tool "$tool" --out "$OUTDIR_SKIP" \
      2>"$OUTDIR_SKIP/.stderr.$tool" || true
  done

  export GOLDEN
  GOLDEN="$REPO_ROOT/tests/installer/golden"
}

teardown_file() {
  rm -rf "$FAKEREPO1" "$FAKEREPO2" "$FAKEREPO_SKIP"
  rm -rf "$OUTDIR1" "$OUTDIR2" "$OUTDIR_SKIP"
}

# ---------------------------------------------------------------------------
# Determinism: two runs produce byte-identical output (date_added normalized)
# ---------------------------------------------------------------------------

@test "determinism: all tools produce identical output on two runs" {
  diff -rq --exclude=".stderr*" "$OUTDIR1" "$OUTDIR2"
}

@test "determinism: aider CONVENTIONS.md is byte-identical across two runs" {
  diff "$OUTDIR1/aider/CONVENTIONS.md" "$OUTDIR2/aider/CONVENTIONS.md"
}

@test "determinism: windsurf .windsurfrules is byte-identical across two runs" {
  diff "$OUTDIR1/windsurf/.windsurfrules" "$OUTDIR2/windsurf/.windsurfrules"
}

@test "determinism: claude-code output is byte-identical across two runs" {
  diff -rq "$OUTDIR1/claude-code" "$OUTDIR2/claude-code"
}

# ---------------------------------------------------------------------------
# requires_claude_code: true — included in claude-code, skipped everywhere else
# ---------------------------------------------------------------------------

@test "cc-only: included in claude-code output" {
  [ -f "$OUTDIR_SKIP/claude-code/meta/cc-only/SKILL.md" ]
}

@test "cc-only: skipped for copilot with stderr warning" {
  ! [ -f "$OUTDIR_SKIP/copilot/cc-only.md" ]
  grep -q "skipping meta/cc-only for copilot" "$OUTDIR_SKIP/.stderr.copilot"
}

@test "cc-only: skipped for antigravity with stderr warning" {
  ! [ -d "$OUTDIR_SKIP/antigravity/cc-only" ]
  grep -q "skipping meta/cc-only for antigravity" "$OUTDIR_SKIP/.stderr.antigravity"
}

@test "cc-only: skipped for gemini-cli with stderr warning" {
  ! [ -f "$OUTDIR_SKIP/gemini-cli/skills/cc-only/SKILL.md" ]
  grep -q "skipping meta/cc-only for gemini-cli" "$OUTDIR_SKIP/.stderr.gemini-cli"
}

@test "cc-only: skipped for opencode with stderr warning" {
  ! [ -f "$OUTDIR_SKIP/opencode/agents/cc-only.md" ]
  grep -q "skipping meta/cc-only for opencode" "$OUTDIR_SKIP/.stderr.opencode"
}

@test "cc-only: skipped for cursor with stderr warning" {
  ! [ -f "$OUTDIR_SKIP/cursor/rules/cc-only.mdc" ]
  grep -q "skipping meta/cc-only for cursor" "$OUTDIR_SKIP/.stderr.cursor"
}

@test "cc-only: skipped for openclaw with stderr warning" {
  ! [ -d "$OUTDIR_SKIP/openclaw/cc-only" ]
  grep -q "skipping meta/cc-only for openclaw" "$OUTDIR_SKIP/.stderr.openclaw"
}

@test "cc-only: skipped for qwen with stderr warning" {
  ! [ -f "$OUTDIR_SKIP/qwen/agents/cc-only.md" ]
  grep -q "skipping meta/cc-only for qwen" "$OUTDIR_SKIP/.stderr.qwen"
}

@test "cc-only: skipped for kimi with stderr warning" {
  ! [ -d "$OUTDIR_SKIP/kimi/cc-only" ]
  grep -q "skipping meta/cc-only for kimi" "$OUTDIR_SKIP/.stderr.kimi"
}

@test "cc-only: NOT in aider CONVENTIONS.md (skipped)" {
  ! grep -q "^## cc-only" "$OUTDIR_SKIP/aider/CONVENTIONS.md"
  grep -q "skipping meta/cc-only for aider" "$OUTDIR_SKIP/.stderr.aider"
}

@test "cc-only: NOT in windsurf .windsurfrules (skipped)" {
  ! grep -q "^## cc-only" "$OUTDIR_SKIP/windsurf/.windsurfrules"
  grep -q "skipping meta/cc-only for windsurf" "$OUTDIR_SKIP/.stderr.windsurf"
}

# ---------------------------------------------------------------------------
# Golden file diff — stable output matches committed golden files
# ---------------------------------------------------------------------------

@test "golden: claude-code/roles/minimal-agent/SKILL.md matches golden" {
  diff "$GOLDEN/claude-code/roles/minimal-agent/SKILL.md" \
       "$OUTDIR_SKIP/claude-code/roles/minimal-agent/SKILL.md"
}

@test "golden: antigravity/minimal-agent/SKILL.md matches golden (date normalized)" {
  local actual_norm golden_norm
  actual_norm="$(sed 's/date_added: .*/date_added: PLACEHOLDER/' "$OUTDIR_SKIP/antigravity/minimal-agent/SKILL.md")"
  golden_norm="$(sed 's/date_added: .*/date_added: PLACEHOLDER/' "$GOLDEN/antigravity/minimal-agent/SKILL.md")"
  [ "$actual_norm" = "$golden_norm" ]
}

@test "golden: aider/CONVENTIONS.md matches golden" {
  diff "$GOLDEN/aider/CONVENTIONS.md" "$OUTDIR_SKIP/aider/CONVENTIONS.md"
}

@test "golden: windsurf/.windsurfrules matches golden" {
  diff "$GOLDEN/windsurf/.windsurfrules" "$OUTDIR_SKIP/windsurf/.windsurfrules"
}
