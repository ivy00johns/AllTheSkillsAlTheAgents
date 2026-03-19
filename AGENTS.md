# AGENTS.md

Shared instructions for all AI coding agents (Claude Code, Gemini CLI, Codex, etc.) working in this repo.

## Skill Creator Workspaces

When using `/skill-creator` (or any skill evaluation workflow) to audit, test, or iterate on skills, **always** place workspace directories in `.workspaces/` at the repo root — not as siblings to the skill directory. This overrides skill-creator's default behavior of creating `<skill-name>-workspace/` next to the skill.

```text
# Use this:
.workspaces/<skill-name>/iteration-1/...

# NOT this:
skills/workflows/<skill-name>-workspace/...

# or:
<skill-name>-workspace/...
```

Both `.workspaces/` and `*-workspace/` are gitignored, but consolidating into `.workspaces/` keeps the repo clean and avoids stray directories.

### Markdownlint

This repo has a `.markdownlint.json` config at the root. When creating or editing any Markdown
file — especially SKILL.md files via skill-creator — **always fix markdownlint violations before
finishing**. Run a lint pass on every Markdown file you touch and resolve all warnings. The repo
disables MD013 (line length) and MD060 globally; all other rules are enforced.

## Environment Variables for Skills

All API keys and credentials for skills live in a **single root `.env` file** at the repo root — never in per-skill `.env` files. This keeps secrets centralized and avoids confusion as the skill count grows.

- **`.env`** — The live credentials file (gitignored, never committed)
- **`.env.example`** — Template documenting every variable across all skills (committed, no real values)

When a skill needs a new env var:

1. Add the variable (with empty value and a comment) to `.env.example`
2. Have the skill's scripts read from the repo root `.env`
3. Document which skill uses it in the `.env.example` section header

Scripts should walk up from their location to find the repo root `.env`. Pattern:

```python
import pathlib, os
_repo_root = pathlib.Path(__file__).resolve().parent
while _repo_root != _repo_root.parent:
    if (_repo_root / ".env.example").exists():
        break
    _repo_root = _repo_root.parent
# Then load _repo_root / ".env"
```
