# scripts/

Three command-line utilities for managing the AllTheSkillsAllTheAgents ecosystem:

- **`convert.sh`** — translates canonical SKILL.md files into 11 tool-specific formats
- **`install.sh`** — copies converted artifacts to the appropriate config directories for each tool
- **`lint-skills.sh`** — validates all SKILL.md files (frontmatter, body quality, cross-skill invariants)

All three scripts are portable (bash 3.2+ on macOS, bash 4+ on Linux) and deterministic — same input always produces identical output.

## Installation Prerequisites

- **bash** 3.2+ (macOS), 4.0+ (Linux) — tested on macOS 12+, Ubuntu 20.04+, Windows Git Bash
- **python3** with PyYAML — required by lint-skills.sh for YAML parsing (used by convert.sh and install.sh indirectly via lib/frontmatter.sh). Install with `pip3 install pyyaml`.
- **bats-core** — only if running the test suite (`tests/installer/`). Not required to run convert/install/lint.

## scripts/convert.sh

**Purpose:** Convert canonical SKILL.md files from `skills/**/` into 11 tool-specific output formats and write them to `integrations/<tool>/`.

**Usage:**
```bash
scripts/convert.sh [--tool <name>] [--out <dir>] [--parallel] [--jobs N] [--help]
```

**Options:**

| Flag | Argument | Default | Effect |
|---|---|---|---|
| `--tool` | NAME | all | Convert for a single tool only. Repeatable: `--tool cursor --tool aider`. Valid names: `claude-code`, `copilot`, `antigravity`, `gemini-cli`, `opencode`, `cursor`, `openclaw`, `qwen`, `kimi`, `aider`, `windsurf`, `all` |
| `--out` | DIR | `integrations/` | Override output base directory |
| `--parallel` | — | — | Run per-tool conversions concurrently (only with `--tool all`). Use `--jobs` to set worker count. |
| `--jobs` | N | nproc (Linux) or sysctl (macOS) | Parallel worker count. Ignored unless `--parallel` is set. |
| `--help` | — | — | Print help and exit |

**Exit Codes:**
- `0` — success
- `1` — at least one per-skill conversion error
- `2` — argument parsing error

**Output Paths:**

See `contracts/installer/per-tool-output-spec.md` for the full specification. Summary:

- `claude-code`: `integrations/claude-code/<category>/<slug>/SKILL.md` + references/
- `copilot`: `integrations/copilot/<slug>.md` + references/
- `antigravity`: `integrations/antigravity/<slug>/SKILL.md` + references/
- `gemini-cli`: `integrations/gemini-cli/skills/<slug>/SKILL.md` + manifest
- `opencode`: `integrations/opencode/agents/<slug>.md`
- `cursor`: `integrations/cursor/rules/<slug>.mdc` (inline-bundled references)
- `openclaw`: `integrations/openclaw/<slug>/{SOUL.md,AGENTS.md,IDENTITY.md}`
- `qwen`: `integrations/qwen/agents/<slug>.md`
- `kimi`: `integrations/kimi/<slug>/{agent.yaml,system.md}`
- `aider`: `integrations/aider/CONVENTIONS.md` (all skills in one file)
- `windsurf`: `integrations/windsurf/.windsurfrules` (all skills in one file)

**Behavior:**

- Deterministic: same input → identical output (except `antigravity` which includes `date_added` field)
- Idempotent: re-running produces byte-identical output
- Lossy: Claude-Code-only frontmatter fields (`owns`, `allowed_tools`, `composes_with`, `spawned_by`) are stripped with a stderr warning per skill
- Skills marked `requires_claude_code: true` are skipped for non-Claude-Code targets
- Stderr summary at end: `[convert] processed 38 skills across 11 tools (0 errors, 0 warnings)`

**Examples:**

```bash
# Convert for all tools (default)
./scripts/convert.sh

# Convert for a single tool
./scripts/convert.sh --tool cursor

# Convert multiple tools explicitly
./scripts/convert.sh --tool cursor --tool aider

# Convert in parallel (all tools, 8 workers)
./scripts/convert.sh --parallel --jobs 8

# Override output directory
./scripts/convert.sh --out /tmp/integrations --tool gemini-cli
```

## scripts/install.sh

**Purpose:** Copy converted skill artifacts from `integrations/` to the appropriate config directories for each tool. Detects installed tools, offers an interactive selector, and handles conflicts gracefully.

**Usage:**
```bash
scripts/install.sh [OPTIONS] [TOOL ...]
```

**Options:**

| Flag | Argument | Default | Effect |
|---|---|---|---|
| `--tool` | NAME | — | Install for a single tool. Repeatable: `--tool cursor --tool aider`. Valid names: same as convert.sh. |
| `--all` | — | — | Install for all 11 tools (force, no detection). |
| `--detected` | — | — | Install only for tools detected on this machine (skip interactive TUI). Default when stdin is not a TTY. |
| `--interactive` | — | auto | Force the interactive TUI selector. Default when stdin is a TTY. |
| `--no-interactive` | — | — | Skip the TUI selector; use `--detected` or explicit `--tool`. |
| `--parallel` | — | — | Run installations concurrently across tools. Use `--jobs` to set worker count. |
| `--jobs` | N | nproc (Linux) or sysctl (macOS) | Parallel worker count. Ignored unless `--parallel` is set. |
| `--dry-run` | — | — | Print what would be copied without writing. Useful for previewing. |
| `--help` | — | — | Print help and exit |

**Exit Codes:**
- `0` — all requested installations succeeded
- `1` — at least one installation failed
- `2` — argument parsing error or preflight failure (e.g., missing `integrations/`)

**Tool Detection:**

`install.sh` detects installed tools by checking for commands and config directories:

| Tool | Detection Signal |
|---|---|
| Claude Code | `~/.claude/` exists |
| GitHub Copilot | `command -v code` OR `~/.github/` exists |
| Antigravity | `~/.gemini/antigravity/skills/` exists |
| Gemini CLI | `command -v gemini` OR `~/.gemini/` exists |
| OpenCode | `command -v opencode` OR `$PWD/.opencode/` exists |
| Cursor | `command -v cursor` OR `~/.cursor/` exists |
| OpenClaw | `command -v openclaw` OR `~/.openclaw/` exists |
| Qwen Code | `command -v qwen` |
| Kimi Code | `command -v kimi` OR `~/.config/kimi/` exists |
| Aider | `command -v aider` |
| Windsurf | `command -v windsurf` OR `~/.codeium/windsurf/` exists |

**Interactive UI:**

When stdin is a TTY and no explicit tool is specified, the installer shows an ASCII menu:

```
+----------------------------------------------------+
|  AllTheSkillsAllTheAgents -- Skill Installer       |
+----------------------------------------------------+

System scan:  [*] = detected on this machine

[x]  1)  [*]  Claude Code      (~/.claude/skills/)
[ ]  2)  [*]  Copilot          (~/.github + ~/.copilot)
[x]  3)  [ ]  Antigravity      (~/.gemini/antigravity)
[ ]  4)  [*]  Gemini CLI       (gemini extension)
[ ]  5)  [ ]  OpenCode         (.opencode/agents)
[x]  6)  [*]  OpenClaw         (~/.openclaw/alltheskills)
[ ]  7)  [ ]  Cursor           (.cursor/rules)
[x]  8)  [*]  Aider            (CONVENTIONS.md)
[ ]  9)  [ ]  Windsurf         (.windsurfrules)
[x] 10)  [ ]  Qwen Code        (.qwen/agents)
[ ] 11)  [ ]  Kimi Code        (~/.config/kimi)

------------------------------------------------
[1-11] toggle   [a] all   [n] none   [d] detected
[Enter] install   [q] quit
```

Navigation:
- Type `1-11` to toggle a tool's checkbox
- Type `a` to select all, `n` to deselect all, `d` to select only detected
- Press Enter to proceed with checked tools
- Type `q` to quit without installing

**Conflict Handling:**

| Situation | Behavior |
|---|---|
| Destination exists but contents differ | Overwrite. Print `[install] updated <path>`. |
| Destination exists with identical contents | Skip silently (or `[install] unchanged <path>` at `--verbose`). |
| Destination is a symlink | Replace symlink with regular file. Print `[install] replaced symlink at <path>`. |
| Aider or Windsurf target exists | Refuse to overwrite (these are user-editable project files). Error: `<path> exists; remove or rename before install`. Exit 1. |
| Claude Code skill is currently symlinked from `/sync-skills` | Skip with `[install] skipped <slug> (managed by /sync-skills)` and continue (do not override user's symlink setup). |

**Examples:**

```bash
# Interactive mode (default if TTY)
./scripts/install.sh

# Install for detected tools only (no interactive menu)
./scripts/install.sh --detected

# Install for specific tools
./scripts/install.sh --tool cursor --tool aider

# Install for all tools
./scripts/install.sh --all

# Install in parallel across multiple tools
./scripts/install.sh --all --parallel --jobs 4

# Preview what would be installed
./scripts/install.sh --all --dry-run

# Install from a script (non-interactive)
./scripts/install.sh --all --no-interactive
```

## scripts/lint-skills.sh

**Purpose:** Validate all `skills/**/SKILL.md` files against the canonical frontmatter schema, body quality guidelines, and cross-skill invariants. This is the CI gate — errors block PR merges.

**Usage:**
```bash
scripts/lint-skills.sh [OPTIONS] [PATH ...]
```

**Options:**

| Flag | Argument | Default | Effect |
|---|---|---|---|
| `--quiet` | — | — | Suppress WARN output. Only show ERRORs and the final summary. |
| `--verbose` | — | — | Show INFO output in addition to ERRORs and WARNs. |
| `--fix-trivial` | — | — | Auto-fix trivial issues (e.g., trailing whitespace, YAML indentation) with interactive prompt before each fix. |
| `--format` | FORMAT | text | Output format: `text` (human-readable) or `junit` (XML for CI). |
| `--help` | — | — | Print help and exit |

**Arguments:**

- `PATH` — optional. Directory (recurse into all SKILL.md files) or individual SKILL.md file. Defaults to `skills/` if not given.

**Exit Codes:**
- `0` — no errors (warnings allowed)
- `1` — at least one error
- `2` — argument parsing failure

**Severity Levels:**

| Severity | Blocks CI? | When to Fix |
|---|---|---|
| ERROR | Yes | Required fields missing, malformed YAML, naming conflicts, ownership overlaps |
| WARN | No | Description too long, body word count low, missing recommended fields, broken cross-references |
| INFO | No | Suggestions; only shown with `--verbose` |

**Rule Categories:**

- **Required Frontmatter:** `name` (kebab-case, matches directory), `version` (semver), `description` (non-empty)
- **Recommended Frontmatter (agent roles only):** `owns.directories`, `allowed_tools`
- **Body Quality:** present (≥1 line), ≥50 words (WARN if stub), ≤500 lines (WARN if too long)
- **Description Quality:** starts with action verb, mentions trigger context. Heuristic-based (no hard rule for trigger detection).
- **Cross-Skill Validation:** unique names, no overlapping `owns.directories`, valid `composes_with`/`spawned_by` references
- **YAML Wellformedness:** parseable by Python 3's PyYAML (or hand-rolled fallback if `python3` unavailable)

See `contracts/installer/lint-rules.md` for the authoritative reference and severity model.

**Output Format (text):**

```
Linting 38 skills...

ERROR  skills/roles/backend-agent/SKILL.md:2  name 'backend' does not match directory 'backend-agent'
WARN   skills/workflows/ui-brief/SKILL.md     description is 215 chars (target ≤200)
WARN   skills/meta/skill-audit/SKILL.md       composes_with references unknown skill 'skill-deepreview'

Results: 1 error, 2 warnings across 38 skills.
FAILED: fix the errors above before merging.
```

**Output Format (junit):**

JUnit XML suitable for GitHub Actions test result rendering. Use `--format junit > results.xml` in CI.

**Examples:**

```bash
# Lint all skills with default options
./scripts/lint-skills.sh

# Lint a specific skill file
./scripts/lint-skills.sh skills/roles/backend-agent/SKILL.md

# Lint a category directory
./scripts/lint-skills.sh skills/workflows/

# Lint with verbose output
./scripts/lint-skills.sh --verbose

# Auto-fix trivial issues (interactive prompts)
./scripts/lint-skills.sh --fix-trivial

# Generate JUnit XML for CI
./scripts/lint-skills.sh --format junit > lint-results.xml

# Suppress warnings (show only errors)
./scripts/lint-skills.sh --quiet
```

**Self-Test:**

All 38 current skills pass lint with 0 errors as of this commit. Run locally to verify:

```bash
./scripts/lint-skills.sh skills/
```

## scripts/lib/

Shared shell libraries sourced by convert.sh, install.sh, and lint-skills.sh. All are portable (bash 3.2+ compatible):

| Module | Provides |
|---|---|
| `lib/frontmatter.sh` | SKILL.md frontmatter parsing (YAML extraction via Python 3 or hand-rolled fallback). Functions: `get_field`, `get_field_raw`, `get_array`, `get_owns_dirs`, `get_body`, `fm_raw`, `fm_check`, `fm_has_field`. |
| `lib/slug.sh` | String utilities: `slugify` (converts "My Skill" → "my-skill" for deterministic filenames). |
| `lib/term.sh` | Terminal/color helpers: ANSI color codes (respects `NO_COLOR` and `TERM=dumb`), box-drawing for the install.sh TUI. |
| `lib/platform.sh` | Cross-platform shims: `nproc_count` (portable CPU core detection), portable `mktemp`, portable `cp -r`. |

## Testing

The installer is covered by a 172-test bats suite. See `tests/installer/README.md` for setup, running, and test fixture details.

Quick start:

```bash
# Install bats-core (if not already present)
brew install bats-core  # macOS
# or: sudo apt install bats  # Ubuntu

# Run the full suite
bash tests/installer/run-tests.sh

# Run a single test file
bats tests/installer/bats/02-convert-per-tool.bats

# Filter by prefix (e.g., all lint tests)
bash tests/installer/run-tests.sh 05
```

## CI Integration

`.github/workflows/lint-skills.yml` runs on every push and PR targeting `main`:

- Runs `scripts/lint-skills.sh --format junit > lint-results.xml` on Ubuntu (blocking) and macOS (smoke-check, non-blocking)
- Uploads JUnit results as a GitHub Actions artifact for easy inspection
- Fails the job if lint exits non-zero on Ubuntu
- Produces TAP-formatted output for structured test result display

The workflow is the authoritative gate — all PRs must pass lint before merging to `main`.
