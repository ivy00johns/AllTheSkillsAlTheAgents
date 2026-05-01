# scripts/

Bash scripts that convert canonical `SKILL.md` files into 11 tool-specific formats and install them.

## Quickstart

```bash
# 1. Convert all skills to all formats
./scripts/convert.sh

# 2. Install for all detected tools
./scripts/install.sh

# 3. Lint all skills (CI gate)
./scripts/lint-skills.sh
```

## Scripts

| Script | Purpose |
|---|---|
| `convert.sh` | Read `skills/**/SKILL.md`, write `integrations/<tool>/` |
| `install.sh` | Copy `integrations/<tool>/` to each tool's config dir |
| `lint-skills.sh` | Validate frontmatter + body against the lint contract |

## convert.sh

```
Usage: scripts/convert.sh [--tool <name>] [--out <dir>] [--parallel] [--jobs N] [--help]

Tools: claude-code copilot antigravity gemini-cli opencode cursor openclaw qwen kimi aider windsurf all
```

Run `convert.sh` before `install.sh` whenever you add or edit skills.

## install.sh

```
Usage: scripts/install.sh [OPTIONS] [TOOL ...]

Options:
  --tool NAME          Install for a single tool (repeatable)
  --all                Install for all 11 tools
  --detected           Install only for detected tools
  --interactive        Force the TUI selector
  --no-interactive     Skip the TUI
  --parallel           Run installations concurrently
  --dry-run            Print what would be copied; do not write
```

When run in a TTY with no flags, an interactive tool selector is displayed.

## lint-skills.sh

```
Usage: scripts/lint-skills.sh [OPTIONS] [PATH ...]

Options:
  --quiet          Suppress warnings
  --verbose        Show INFO output
  --format FORMAT  text (default) or junit (for CI)
```

Errors block CI. Warnings are advisory.

## lib/

Helper modules sourced by all three scripts:

| File | Provides |
|---|---|
| `lib/term.sh` | Color vars, `ats_ok/warn/err`, box drawing, `progress_bar`, `strip_ansi` |
| `lib/platform.sh` | `nproc_count`, `ats_mktemp_dir/file`, `ats_cp_r` |
| `lib/slug.sh` | `slugify`, `repeat_char` |
| `lib/frontmatter.sh` | `get_field`, `get_field_raw`, `get_array`, `get_owns_dirs`, `get_body`, `fm_check` |

## Requirements

- bash 3.2+ (macOS default)
- python3 + PyYAML (`pip3 install pyyaml`)
- Standard POSIX tools: `awk`, `find`, `sort`, `cp`, `mktemp`
