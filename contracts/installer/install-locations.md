# Contract: Install Locations

**Build:** Multi-Tool Installer (Slice A)
**Version:** 1.0.0
**Owner:** orchestrator (authored Phase 4)
**Consumed by:** scripts-agent (install.sh), qe-agent (install dry-run tests)

## Purpose

Defines where `scripts/install.sh` copies the artifacts produced in `integrations/` for each of the 11 tools. Also defines tool detection, scope, conflict behavior, and the interactive UI contract.

## Install Matrix

| Tool | Source | Destination | Scope | Detector |
|---|---|---|---|---|
| claude-code | `integrations/claude-code/` | `~/.claude/skills/<category>/<slug>/` | user | `[[ -d "$HOME/.claude" ]]` |
| copilot | `integrations/copilot/` | `~/.github/agents/` AND `~/.copilot/agents/` | user | `command -v code` OR `[[ -d "$HOME/.github" ]]` |
| antigravity | `integrations/antigravity/` | `~/.gemini/antigravity/skills/` | user | `[[ -d "$HOME/.gemini/antigravity/skills" ]]` |
| gemini-cli | `integrations/gemini-cli/` | `~/.gemini/extensions/alltheskills/` | user | `command -v gemini` OR `[[ -d "$HOME/.gemini" ]]` |
| opencode | `integrations/opencode/agents/` | `$PWD/.opencode/agents/` | project | `command -v opencode` OR `[[ -d "$PWD/.opencode" ]]` |
| cursor | `integrations/cursor/rules/` | `$PWD/.cursor/rules/` | project | `command -v cursor` OR `[[ -d "$HOME/.cursor" ]]` |
| openclaw | `integrations/openclaw/` | `~/.openclaw/alltheskills/` | user | `command -v openclaw` OR `[[ -d "$HOME/.openclaw" ]]` |
| qwen | `integrations/qwen/agents/` | `$PWD/.qwen/agents/` | project | `command -v qwen` |
| kimi | `integrations/kimi/` | `~/.config/kimi/agents/` | user | `command -v kimi` OR `[[ -d "$HOME/.config/kimi" ]]` |
| aider | `integrations/aider/CONVENTIONS.md` | `$PWD/CONVENTIONS.md` | project | `command -v aider` |
| windsurf | `integrations/windsurf/.windsurfrules` | `$PWD/.windsurfrules` | project | `command -v windsurf` OR `[[ -d "$HOME/.codeium/windsurf" ]]` |

## Preflight

`install.sh` MUST verify before any work:

1. `integrations/` directory exists. If not, error with `Run scripts/convert.sh first.` and exit 1.
2. For each requested tool, the corresponding `integrations/<tool>/` subdirectory exists.

## CLI Contract

```
Usage: scripts/install.sh [OPTIONS] [TOOL ...]

Options:
  --tool NAME          Install for a single tool (repeatable)
  --all                Install for all 11 tools
  --detected           Install only for detected tools (default in non-interactive)
  --interactive        Force the TUI (default if stdin is a TTY)
  --no-interactive     Skip the TUI (default if stdin is not a TTY)
  --parallel           Run installations concurrently
  --jobs N             Worker count for --parallel (default: nproc / sysctl)
  --dry-run            Print what would be copied; do not write
  --help               Print this and exit

If no TOOL is given and stdin is a TTY, launches interactive selector.
If no TOOL is given and stdin is NOT a TTY, behaves as --detected.
```

## Interactive UI

When the TUI is shown:

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

UI requirements:
- Inner box width: 52 chars
- Pure ASCII (no Unicode box characters — Windows Git Bash / non-UTF terminals)
- Color codes stripped before length measurement (`strip_ansi` helper)
- Respect `NO_COLOR` env var; respect `TERM=dumb`
- Initial selection: detected tools pre-checked
- Invalid input: redraw with no error noise

## Conflict Handling

| Situation | Behavior |
|---|---|
| Destination directory exists, files differ | Overwrite by default. Print `[install] updated <path>` per file. |
| Destination directory exists, files identical | Skip silently (or `[install] unchanged <path>` at `--verbose`). |
| Destination is a symlink | Replace the symlink with the regular file (don't follow it). Warn once: `[install] replaced symlink at <path>`. |
| Aider/Windsurf single-file target already exists | Refuse to overwrite. Error: `<path> exists; remove or rename before install`. Exit 1. (These are user-edited project files.) |
| `claude-code` → `~/.claude/skills/<category>/<slug>/` is currently a symlink (from `/sync-skills`) | Skip with `[install] skipped <slug> (managed by /sync-skills)` and continue. |

## Worker Mode (parallel)

When invoked with `--parallel`, install.sh spawns workers via `xargs -P <jobs>`. Each worker:

- Sets `ATS_INSTALL_WORKER=1` to suppress the TUI and progress bar
- Buffers all output to a per-tool tempfile
- On worker exit, the parent concatenates the tempfile to stdout (no interleaving)

## Exit Codes

- `0` — every requested install succeeded
- `1` — at least one install failed (per-tool errors printed inline)
- `2` — argument parsing error or preflight failure

## Cross-Platform

Scripts MUST work on:

- macOS (bash 3.2+) — use `sysctl -n hw.ncpu` for `nproc` fallback
- Linux (bash 4.0+) — use `nproc`
- Windows Git Bash / WSL — paths translate via `$HOME`

Avoid: `declare -A`, `${arr[@]:0:5}` slicing, `printf %q`, bash 4-only features.
