# Audit Agent Brief

You are auditing skills in this repo against Anthropic's Agent Skills standard
plus this repo's house style. The repo has 47 active skills under `skills/`
(excluding `skills/archive/`).

## Rubric & Spec Sources (read these first)

- `skills/meta/skill-review/references/deep-review-rubric.md` — 1-5 scoring on 7 dimensions
- `skills/meta/skill-review/references/audit-checklist.md` — anti-pattern list + per-skill checks
- `skills/meta/skill-writer/references/frontmatter-spec.md` — the authoritative frontmatter spec
- `skills/meta/skill-update/references/validation-checklist.md` — house style checks
- `CLAUDE.md` and `AGENTS.md` — repo-level conventions

## Per-Skill Output

For each assigned skill, write two files to `audit/reports/`:

### `audit/reports/{skill-name}.md`

```markdown
# Audit: {skill-name}

**Path:** skills/{category}/{skill-name}/SKILL.md
**Version:** {from frontmatter}
**Category:** {orchestrator|contracts|git|meta|roles|workflows}
**Verdict:** SHIP | NEEDS WORK | MAJOR REWORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 1-5 | specific evidence |
| Description quality | 1-5 | specific evidence |
| Progressive disclosure | 1-5 | specific evidence |
| Instruction clarity | 1-5 | specific evidence |
| Coordination | 1-5 | specific evidence |
| Completeness | 1-5 | specific evidence |
| Anti-patterns | 1-5 | specific evidence |

**Average:** X.X

## Findings

### Critical (must fix to ship)
- {finding} — {file:line} — proposed fix: {concrete diff}

### Important (should fix)
- {finding}

### Nits (won't block ship)
- {finding}

## Top 3 Concrete Fixes (rank order, with diff direction)

1. {one-liner} — file:line — what changes
2. ...
3. ...

## Dead links / broken references
- list any references/*.md, [[wiki-links]], or cross-skill references that don't resolve
```

### `audit/reports/{skill-name}.json`

```json
{
  "skill": "{skill-name}",
  "path": "skills/{category}/{skill-name}/SKILL.md",
  "version": "X.Y.Z",
  "category": "...",
  "verdict": "SHIP | NEEDS WORK | MAJOR REWORK",
  "scores": {
    "frontmatter_compliance": {"score": 5, "notes": "..."},
    "description_quality": {"score": 5, "notes": "..."},
    "progressive_disclosure": {"score": 5, "notes": "..."},
    "instruction_clarity": {"score": 5, "notes": "..."},
    "coordination": {"score": 5, "notes": "..."},
    "completeness": {"score": 5, "notes": "..."},
    "anti_patterns": {"score": 5, "notes": "..."}
  },
  "average": 5.0,
  "findings": {
    "critical": [{"item": "...", "location": "file:line", "fix": "..."}],
    "important": [...],
    "nits": [...]
  },
  "top_fixes": [
    {"rank": 1, "fix": "...", "file": "...", "effort": "small|medium|large"}
  ],
  "broken_refs": ["..."]
}
```

## What to flag aggressively

- `<` or `>` anywhere in frontmatter field values (security rule — hard FAIL)
- Description >1024 chars (hard FAIL)
- Description <80 chars or no action verb (NEEDS WORK)
- Body >5000 words OR >500 lines without justification (NEEDS WORK)
- References in SKILL.md body that don't exist on disk (FAIL)
- Cross-skill links (`composes_with`, `spawned_by`) pointing at nonexistent skills (FAIL)
- Reserved prefix `claude-*` / `anthropic-*` WITHOUT documented exception (WARN)
- Missing `version` or invalid semver (FAIL)
- Field order drifts from house style: `name, version, description, compatibility, license, allowed-tools, metadata, requires_agent_teams, requires_claude_code, min_plan, owns, composes_with, spawned_by` (nit)
- `allowed_tools` (underscore) instead of `allowed-tools` (hyphen) — should be migrated
- Body uses passive voice instead of imperative
- Body has trailing whitespace, emojis (house style forbids them), or unfenced code blocks

## What NOT to do

- Do NOT modify any SKILL.md or reference file. Audit only.
- Do NOT spawn further subagents — you ARE the subagent.
- Do NOT skip a skill because it "looks fine" — score every dimension.
- Do NOT invent scores — back each with specific evidence (file:line or quote).
