---
name: sync-skills
version: 2.0.0
description: |
  Sync skills between this repo and global locations for Claude Code and Cursor using symlinks (default) or copies. Use when the user wants to link, sync, publish, push, or copy skills to Claude Code or Cursor, make repo skills available globally, check sync status, see what's linked vs copied, unlink skills, or mentions "sync skills", "link skills", "publish skills", "skill status", or wants to use repo skills from another project.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: ["skills/workflows/sync-skills/"]
  patterns: []
  shared_read: ["skills/"]
allowed_tools: ["Read", "Bash"]
composes_with: ["skill-updater", "skill-audit"]
spawned_by: []
---

# Sync Skills Between Repo and Global Locations

Link or copy skills between this repo and the global skill directories that Claude Code and Cursor read from. Symlinks are the default — edits in the repo are instantly available everywhere without copying.

## Skill Locations

| Location | Path | Used by |
| -------- | ---- | ------- |
| Repo (source of truth) | `skills/` | This workspace |
| Claude Code (global) | `~/.claude/skills/` | All Claude Code projects |
| Cursor (global) | `~/.cursor/skills-cursor/` | All Cursor workspaces |

The repo organizes skills into category directories (`contracts/`, `meta/`, `roles/`, `workflows/`, `orchestrator/`). For Claude Code, symlinks are **flattened** — each individual skill is linked directly under `~/.claude/skills/` (no category subdirs) because Claude Code only discovers skills at `~/.claude/skills/<skill-name>/SKILL.md`. For Cursor, symlinks are created at the category level.

## Quick Reference

```bash
SCRIPT="skills/workflows/sync-skills/scripts/sync-skills.sh"

# Link all repo skill categories to both Claude Code and Cursor
$SCRIPT --link --to-all

# Check what's linked, copied, or missing
$SCRIPT --status

# Link just one category to Claude Code
$SCRIPT --link --to-claude meta

# Copy instead of link (for machines without repo access)
$SCRIPT --copy --to-all

# Remove symlinks (restore independence)
$SCRIPT --unlink --to-all

# Pull a skill from Cursor into the repo
$SCRIPT --from-cursor shell

# Preview what would happen
$SCRIPT --dry-run --link --to-all
```

## Modes

### Link Mode (default for `--to-*`)

Creates symlinks from global locations pointing to repo directories. This is the development workflow — edit skills in the repo and they're instantly live in Claude Code and Cursor.

- **Claude Code**: Skills are **flattened** — each individual skill gets its own symlink directly under `~/.claude/skills/` (e.g., `~/.claude/skills/skill-audit` → `repo/skills/meta/skill-audit`). This is required because Claude Code only discovers skills at `~/.claude/skills/<skill-name>/SKILL.md`.
- **Cursor**: Symlinks are created at the **category level** (e.g., `~/.cursor/skills-cursor/meta` → `repo/skills/meta`)
- Non-repo skills in global locations (e.g., `~/.claude/skills/builtWithAgent/`) are untouched
- If a copy already exists where a symlink would go, the script warns and asks before replacing

### Copy Mode (`--copy`)

Copies skill directories instead of symlinking. Use this when:
- Deploying skills to a machine that doesn't have the repo cloned
- You need a frozen snapshot that won't change with repo edits
- The target location is on a different filesystem that doesn't support symlinks

### Pull Mode (`--from-cursor`, `--from-claude`)

Copies skills FROM global locations INTO the repo. Always copies (not symlinks) since the repo is the destination. Useful for importing skills created outside this repo.

## Script Flags

| Flag | Purpose |
| ---- | ------- |
| `--link` | Create symlinks (default for `--to-*` operations) |
| `--copy` | Copy files instead of symlinking |
| `--unlink` | Remove symlinks to repo (restores global locations to independent state) |
| `--to-cursor` | Target `~/.cursor/skills-cursor/` |
| `--to-claude` | Target `~/.claude/skills/` |
| `--to-all` | Target both Claude Code and Cursor |
| `--from-cursor` | Pull from Cursor into repo |
| `--from-claude` | Pull from Claude Code into repo |
| `--from-all` | Pull from both |
| `--status` | Show what's linked, copied, or missing across all locations |
| `--dry-run` | Preview what would happen without making changes |
| `-h, --help` | Show help |

Append category or skill names after flags to target specific ones:

```bash
$SCRIPT --link --to-claude meta roles    # Link only meta/ and roles/
$SCRIPT --from-cursor shell              # Pull only the shell skill
```

## How It Works

**Linking:** For Claude Code, discovers every individual skill within category directories and creates a flattened symlink for each (e.g., `~/.claude/skills/skill-audit` → `repo/skills/meta/skill-audit`). For Cursor, creates category-level symlinks. If the target already exists as a real directory, warns before replacing.

**Status detection:** Checks each expected location and reports whether it's a symlink (and where it points), a copy, or missing. Also detects broken symlinks.

**Non-repo skills are safe:** The script only manages categories that exist in this repo. Skills like `~/.claude/skills/builtWithAgent/` or Cursor's native skills are never touched.

## After Linking

Once linked, skills are available automatically:
- **Claude Code**: Skills in `~/.claude/skills/` are picked up by new sessions
- **Cursor**: Skills in `~/.cursor/skills-cursor/` appear in all workspaces

Edit any skill in the repo and the change is live immediately — no sync step needed.

To verify: `$SCRIPT --status`
