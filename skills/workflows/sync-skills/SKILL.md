---
name: sync-skills
description: Sync agent skills between the TAIS mono-repo and global locations for Cursor and Claude Code. Use when the user wants to copy, publish, push, or sync skills to other tools, make mono-repo skills available globally, pull skills from Claude Code or Cursor into the repo, check what skills exist across locations, or mentions using skills from this repo in another workspace or project.
---

# Sync Skills Between Mono-Repo and Global Locations

This skill copies agent skills between the TAIS mono-repo (`.agents/skills/`) and the global skill directories that Cursor and Claude Code read from. This lets you use skills authored in this repo from any workspace -- even repos that have nothing to do with the mono-repo.

## Skill Locations

| Location | Path | Used by |
| -------- | ---- | ------- |
| Mono-repo | `.agents/skills/` | This workspace only |
| Cursor (global) | `~/.cursor/skills-cursor/` | All Cursor workspaces |
| Claude Code (global) | `~/.claude/skills/tais/` | All Claude Code projects |

Mono-repo skills land under a `tais/` category in Claude Code to stay organized alongside other skills you have there (contracts, roles, orchestrator, etc.).

## Quick Reference

```bash
SCRIPT=".agents/skills/sync-skills/scripts/sync-skills.sh"

# See what skills exist everywhere
$SCRIPT --list

# Push all mono-repo skills to both Cursor and Claude Code
$SCRIPT --to-all

# Push just one skill to Cursor
$SCRIPT --to-cursor cross-service-changes

# Pull a Claude Code skill into the mono-repo
$SCRIPT --from-claude orchestrator

# Preview what would happen without changing anything
$SCRIPT --dry-run --to-all
```

## When to Use This

**Push skills out** (`--to-cursor`, `--to-claude`, `--to-all`) after:

- Creating or updating a skill in `.agents/skills/`
- Wanting to use a mono-repo skill from a different project

**Pull skills in** (`--from-cursor`, `--from-claude`, `--from-all`) when:

- You've created or modified a skill in Claude Code / Cursor and want it in the mono-repo
- You want to version-control a global skill by bringing it into Git

**Check status** (`--list`) to see what's available where and spot skills that might be out of sync.

## Script Flags

| Flag | Purpose |
| ---- | ------- |
| `--to-cursor` | Copy mono-repo skills to `~/.cursor/skills-cursor/` |
| `--to-claude` | Copy mono-repo skills to `~/.claude/skills/tais/` |
| `--from-cursor` | Copy Cursor skills into `.agents/skills/` |
| `--from-claude` | Copy Claude Code `tais/` skills into `.agents/skills/` |
| `--to-all` | Shorthand: `--to-cursor --to-claude` |
| `--from-all` | Shorthand: `--from-cursor --from-claude` |
| `--dry-run` | Show what would be copied, don't actually copy |
| `--list` | Show skills in all three locations |
| `--all` | Sync every skill (this is the default when no names are given) |

Append skill names after the flags to sync only specific ones:

```bash
$SCRIPT --to-all cross-service-changes sync-skills
```

## How It Works

The script uses `rsync` (with `--delete` to keep directories clean) when available, falling back to `cp -R`. Each skill directory is copied whole -- `SKILL.md` plus any bundled resources (`scripts/`, `references/`, `assets/`).

The `sync-skills` skill itself is excluded from `--to-*` operations to avoid copying the sync machinery to places where it doesn't make sense.

## After Syncing

Once skills are in the global locations, they'll be available automatically:

- **Cursor**: Skills in `~/.cursor/skills-cursor/` appear in all workspaces. No restart needed.
- **Claude Code**: Skills in `~/.claude/skills/` are picked up by new sessions.

If a skill isn't triggering, check that its `description` field in the YAML frontmatter covers the phrases and contexts where you'd expect it to activate.
