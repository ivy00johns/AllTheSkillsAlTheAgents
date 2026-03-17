# AGENTS.md

Shared instructions for all AI coding agents (Claude Code, Gemini CLI, Codex, etc.) working in this repo.

## Skill Creator Workspaces

When using `/skill-creator` (or any skill evaluation workflow) to audit, test, or iterate on skills, **always** place workspace directories in `.workspaces/` at the repo root — not as siblings to the skill directory. This overrides skill-creator's default behavior of creating `<skill-name>-workspace/` next to the skill.

```
# Use this:
.workspaces/<skill-name>/iteration-1/...

# NOT this:
skills/workflows/<skill-name>-workspace/...
# or:
<skill-name>-workspace/...
```

Both `.workspaces/` and `*-workspace/` are gitignored, but consolidating into `.workspaces/` keeps the repo clean and avoids stray directories.
