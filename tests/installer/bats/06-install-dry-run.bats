#!/usr/bin/env bats
# 06-install-dry-run.bats — Validate scripts/install.sh dry-run behavior.
#
# Tests:
# - --dry-run --tool claude-code: lists destinations under ~/.claude/skills/
# - --dry-run --all: lists destinations across all 11 tools
# - --dry-run --detected: uses detector functions
# - No integrations/ directory → preflight failure, exit 2
# - --tool aider with existing CONVENTIONS.md → refuses to overwrite, exit 1
# - Symlinked skill destination → skipped with contracted warning
#
# Uses setup_file so the fake-repo + integrations/ are built once.

setup_file() {
  export REPO_ROOT
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  local SCRIPTS_DIR="$REPO_ROOT/scripts"
  local FIXTURE_SKILLS="$REPO_ROOT/tests/installer/fixtures/skills"

  # Build a fake repo with copied scripts + fixture skills + pre-built integrations
  export FAKEREPO
  FAKEREPO="$(mktemp -d /tmp/ats-fakerepo.XXXXXX)"
  mkdir -p "$FAKEREPO/scripts/lib"
  cp "$SCRIPTS_DIR/convert.sh"         "$FAKEREPO/scripts/convert.sh"
  cp "$SCRIPTS_DIR/install.sh"         "$FAKEREPO/scripts/install.sh"
  cp "$SCRIPTS_DIR/lib/frontmatter.sh" "$FAKEREPO/scripts/lib/frontmatter.sh"
  cp "$SCRIPTS_DIR/lib/slug.sh"        "$FAKEREPO/scripts/lib/slug.sh"
  cp "$SCRIPTS_DIR/lib/term.sh"        "$FAKEREPO/scripts/lib/term.sh"
  cp "$SCRIPTS_DIR/lib/platform.sh"    "$FAKEREPO/scripts/lib/platform.sh"
  cp -r "$FIXTURE_SKILLS"              "$FAKEREPO/skills"

  # Run convert first to populate integrations/
  export INTEG_DIR
  INTEG_DIR="$(mktemp -d /tmp/ats-integ.XXXXXX)"
  bash "$FAKEREPO/scripts/convert.sh" --out "$INTEG_DIR" 2>/dev/null

  # install.sh derives REPO_ROOT from its SCRIPT_DIR; create integrations/ symlink
  ln -sf "$INTEG_DIR" "$FAKEREPO/integrations"

  export INSTALL
  INSTALL="$FAKEREPO/scripts/install.sh"
  # Export SCRIPTS_DIR so individual tests can reference the original scripts
  export SCRIPTS_DIR_ORIG
  SCRIPTS_DIR_ORIG="$SCRIPTS_DIR"
}

teardown_file() {
  rm -rf "$FAKEREPO" "$INTEG_DIR"
}

# Each test gets its own fake HOME and WORKDIR to avoid HOME contamination
setup() {
  export FAKE_HOME
  FAKE_HOME="$(mktemp -d /tmp/ats-home.XXXXXX)"
  export HOME="$FAKE_HOME"

  export WORKDIR
  WORKDIR="$(mktemp -d /tmp/ats-workdir.XXXXXX)"
}

teardown() {
  rm -rf "$FAKE_HOME" "$WORKDIR"
}

# ---------------------------------------------------------------------------
# Preflight: integrations/ must exist
# ---------------------------------------------------------------------------

@test "install: no integrations/ directory exits with code 2" {
  local NOINTEG
  NOINTEG="$(mktemp -d /tmp/ats-nointeg.XXXXXX)"
  mkdir -p "$NOINTEG/scripts/lib"
  cp "$SCRIPTS_DIR_ORIG/install.sh" "$NOINTEG/scripts/install.sh"
  cp "$SCRIPTS_DIR_ORIG/lib/term.sh" "$NOINTEG/scripts/lib/term.sh"
  cp "$SCRIPTS_DIR_ORIG/lib/platform.sh" "$NOINTEG/scripts/lib/platform.sh"

  cd "$WORKDIR" && run bash "$NOINTEG/scripts/install.sh" --tool claude-code --dry-run --no-interactive
  [ "$status" -eq 2 ]
  echo "$output" | grep -qi "convert\|integrations"
  rm -rf "$NOINTEG"
}

# ---------------------------------------------------------------------------
# --dry-run --tool claude-code: lists intended destinations
# ---------------------------------------------------------------------------

@test "install --dry-run --tool claude-code: exits 0" {
  cd "$WORKDIR" && run bash "$INSTALL" --tool claude-code --dry-run --no-interactive
  [ "$status" -eq 0 ]
}

@test "install --dry-run --tool claude-code: output mentions ~/.claude/skills" {
  cd "$WORKDIR" && run bash "$INSTALL" --tool claude-code --dry-run --no-interactive
  echo "$output" | grep -q "\.claude/skills"
}

@test "install --dry-run --tool claude-code: output mentions minimal-agent" {
  cd "$WORKDIR" && run bash "$INSTALL" --tool claude-code --dry-run --no-interactive
  echo "$output" | grep -q "minimal-agent"
}

@test "install --dry-run --tool claude-code: no files written to fake HOME" {
  cd "$WORKDIR" && bash "$INSTALL" --tool claude-code --dry-run --no-interactive 2>/dev/null
  [ ! -d "$FAKE_HOME/.claude" ]
}

# ---------------------------------------------------------------------------
# --dry-run --all: lists destinations across all 11 tools
# ---------------------------------------------------------------------------

@test "install --dry-run --all: exits 0" {
  cd "$WORKDIR" && run bash "$INSTALL" --all --dry-run --no-interactive
  [ "$status" -eq 0 ]
}

@test "install --dry-run --all: output references multiple tools" {
  cd "$WORKDIR" && run bash "$INSTALL" --all --dry-run --no-interactive
  echo "$output" | grep -q "\.claude/skills"
  echo "$output" | grep -q "\.windsurfrules\|CONVENTIONS.md\|\.cursor\|\.opencode"
}

@test "install --dry-run --all: no files written anywhere" {
  cd "$WORKDIR" && bash "$INSTALL" --all --dry-run --no-interactive 2>/dev/null
  [ ! -f "$WORKDIR/CONVENTIONS.md" ]
  [ ! -f "$WORKDIR/.windsurfrules" ]
  [ ! -d "$WORKDIR/.cursor" ]
}

# ---------------------------------------------------------------------------
# --dry-run --detected: honors detection
# ---------------------------------------------------------------------------

@test "install --dry-run --detected: exits 0 even when nothing detected" {
  cd "$WORKDIR" && run bash "$INSTALL" --detected --dry-run --no-interactive
  [ "$status" -eq 0 ]
}

@test "install --dry-run --detected: detects claude-code when ~/.claude exists" {
  mkdir -p "$FAKE_HOME/.claude"
  cd "$WORKDIR" && run bash "$INSTALL" --detected --dry-run --no-interactive
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Claude Code\|claude-code\|\.claude"
}

# ---------------------------------------------------------------------------
# Conflict: existing single-file targets (aider, windsurf) refuse overwrite
# ---------------------------------------------------------------------------

@test "install --tool aider: refuses to overwrite existing CONVENTIONS.md, exits 1" {
  echo "# existing conventions" > "$WORKDIR/CONVENTIONS.md"
  cd "$WORKDIR" && run bash "$INSTALL" --tool aider --no-interactive
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "exists\|remove\|rename"
  grep -q "# existing conventions" "$WORKDIR/CONVENTIONS.md"
}

@test "install --tool windsurf: refuses to overwrite existing .windsurfrules, exits 1" {
  echo "# existing rules" > "$WORKDIR/.windsurfrules"
  cd "$WORKDIR" && run bash "$INSTALL" --tool windsurf --no-interactive
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "exists\|remove\|rename"
  grep -q "# existing rules" "$WORKDIR/.windsurfrules"
}

# ---------------------------------------------------------------------------
# Symlinked skill destination: skipped with contracted warning
# ---------------------------------------------------------------------------

@test "install --tool claude-code: symlinked skill dir is skipped with warning" {
  local skill_dest="$FAKE_HOME/.claude/skills/roles/minimal-agent"
  mkdir -p "$(dirname "$skill_dest")"
  local SYMLINK_TARGET
  SYMLINK_TARGET="$(mktemp -d /tmp/ats-symtarget.XXXXXX)"
  ln -sf "$SYMLINK_TARGET" "$skill_dest"

  cd "$WORKDIR" && run bash "$INSTALL" --tool claude-code --no-interactive
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "skipped.*managed\|sync-skills\|symlink\|minimal-agent"
  rm -rf "$SYMLINK_TARGET"
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------

@test "install: unknown option exits with code 2" {
  cd "$WORKDIR" && run bash "$INSTALL" --unknown-flag-xyz
  [ "$status" -eq 2 ]
}

@test "install: --tool with unknown tool name exits with code 2" {
  cd "$WORKDIR" && run bash "$INSTALL" --tool nonexistent-tool-xyz
  [ "$status" -eq 2 ]
}
