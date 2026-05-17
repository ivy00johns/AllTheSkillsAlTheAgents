# in-progress/

Drafts of skills under active development. **Not published.**

These skills are **not** symlinked into `~/.claude/skills/` by `sync-skills` and are **not** listed in `.claude-plugin/plugin.json`. They live here as a staging area so half-baked skills don't trigger in real sessions while the author is still iterating.

## Workflow

1. Draft a new skill at `in-progress/<skill-name>/`
2. Iterate using `skill-creator`'s eval loop — workspaces go to `.workspaces/<skill-name>/iteration-N/` per `AGENTS.md`
3. When the skill is accepted, **move** (don't copy) it to its final category — `workflows/`, `meta/`, `git/`, etc.
4. Re-run `/sync-skills` to symlink it into the global locations
5. Update `.claude-plugin/plugin.json` to include the new path

## Do not auto-load

The `sync-skills` script skips this directory by design. If you want to test a draft, point your client at the explicit path rather than relying on global discovery.
