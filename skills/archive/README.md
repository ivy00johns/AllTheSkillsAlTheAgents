# archive/

Retired skills. Each subdirectory keeps the original `SKILL.md` plus a `WHY-ARCHIVED.md` note explaining what replaced it and when.

These skills are **not** symlinked into `~/.claude/skills/` and are **not** listed in `.claude-plugin/plugin.json`. They live here as a reference-only audit trail — useful for understanding why a current skill exists or how a workflow evolved.

## Layout

```text
archive/
├── <retired-skill-name>/
│   ├── SKILL.md           # original, untouched
│   └── WHY-ARCHIVED.md    # what replaced it, date, link to successor
```

## Adding a skill to the archive

When retiring a skill, move (don't copy) the original directory here and write a `WHY-ARCHIVED.md` alongside it. The note should answer:

1. **Replaced by** — which skill (or skills) supersedes this one
2. **Date archived** — YYYY-MM-DD
3. **Reason** — one paragraph: what changed about the workflow that made this obsolete

## Do not auto-load

The `sync-skills` script skips this directory by design. If you find yourself reaching for a retired skill, the answer is almost always to use its successor — `WHY-ARCHIVED.md` will name it.
