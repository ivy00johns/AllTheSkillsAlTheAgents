---
name: skill-audit
version: 1.1.0
description: |
  Scan all skills (or a filtered subset) for consistency, quality issues, gaps, and ownership conflicts in bulk. Use this skill when auditing the full skill ecosystem, running a broad quality scan, checking for ownership overlaps across agents, finding inconsistencies between skills, doing a "health check" on all skills, or when someone says "audit skills", "scan all skills", "skill ecosystem health", "bulk review", or "what needs fixing". Not for single-skill deep dives — use skill-deep-review for that.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["skills/"]
allowed_tools: ["Read", "Grep", "Glob", "Bash", "Agent"]
composes_with: ["skill-deep-review", "skill-improvement-plan", "skill-writer"]
spawned_by: []
---

# Skill Audit

Broad scan across all skills (or a filtered subset) to surface consistency issues, quality gaps, ownership conflicts, and ecosystem-level problems that individual reviews miss.

## When to Use

- Periodic health check on the skill ecosystem
- After bulk edits or a new batch of skills is added
- Before a release to validate ecosystem integrity
- Investigating systemic issues (e.g., "why do none of my skills trigger?")

## Inputs

- **Scope** — `all` (default), or a filter: category (`roles`, `meta`, `contracts`, `workflows`, `orchestrator`), or a list of specific skill names
- **Focus (optional)** — narrow the audit to specific checks (e.g., "just ownership", "just descriptions")

## Process

### Phase 1: Discovery

Enumerate all skills in scope:

1. Glob for `skills/**/SKILL.md`
2. Parse frontmatter from each
3. Build a skill inventory table:

```markdown
| Skill | Category | Version | Description Length | Body Lines | Refs Count |
```

### Phase 2: Bulk Checks

Run these checks across all skills in scope. Use subagents to parallelize where possible — each check category can run independently.

#### 2a. Frontmatter Consistency

For every skill:
- Required fields present (`name`, `version`, `description`)
- Version is valid semver
- Name matches directory name
- Description starts with action verb
- Description length vs 200-char target

Produce a table of violations.

#### 2b. Ownership Conflict Detection

For agent role skills only:
- Collect all `owns.directories` declarations
- Collect all `owns.patterns` declarations
- Check for overlaps (two agents claiming the same directory)
- Validate against the v1.1 resolved conflicts table in `frontmatter-spec.md`
- Flag any new conflicts

Produce a conflict map.

#### 2c. Description Quality Scoring

For every skill:
- Has action verb? (boolean)
- Has ≥3 trigger contexts? (count)
- Has keyword variants? (boolean)
- States exclusions if ambiguous? (boolean)
- Estimated "pushiness" (low/medium/high)

Produce a ranked list from weakest to strongest descriptions.

#### 2d. Progressive Disclosure Check

For every skill:
- SKILL.md body line count
- Number of reference files
- Are references linked from body?
- Any body >500 lines? (flag)
- Any reference >300 lines without TOC? (flag)

#### 2e. Cross-Skill Consistency

Check for ecosystem-level issues:
- `composes_with` references that point to non-existent skills
- `spawned_by` references that point to non-existent skills
- Circular `composes_with` chains (A→B→A)
- Skills declaring `requires_agent_teams: true` that don't degrade gracefully
- Orphan reference files (exist but aren't linked from any SKILL.md)

#### 2f. Coverage Gap Analysis

Compare the skill inventory against the ecosystem design spec:
- Are all roles defined in `skill-ecosystem-design-spec.md` implemented?
- Are all workflow skills implemented?
- Any design spec capabilities not covered by a skill?

### Phase 3: Generate Audit Report

Produce a structured markdown report:

```markdown
# Skill Ecosystem Audit Report
Audited: [timestamp]
Scope: [all / filtered description]
Skills scanned: [count]

## Executive Summary
- Total skills: X
- Passing: X (X%)
- Issues found: X (X critical, X high, X medium, X low)
- Ownership conflicts: X

## Skill Inventory
| Skill | Category | Version | Desc Length | Body Lines | Refs | Status |
|-------|----------|---------|------------|------------|------|--------|

## Ownership Map
[Visual or tabular representation of which agent owns what]

### Conflicts
[Any overlaps detected]

## Description Quality Ranking
| Rank | Skill | Score | Issues |
|------|-------|-------|--------|
[Weakest first]

## Bulk Issues

### Frontmatter Violations
| Skill | Field | Issue |
|-------|-------|-------|

### Progressive Disclosure Violations
| Skill | Body Lines | Issue |
|-------|-----------|-------|

### Cross-Skill Issues
| Issue Type | Skills Involved | Description |
|-----------|-----------------|-------------|

## Coverage Gaps
[Capabilities from design spec not covered by existing skills]

## Recommendations
[Top 5 highest-impact improvements, ordered by priority]

## Per-Skill Scores
| Skill | Frontmatter | Description | Disclosure | Consistency | Overall |
|-------|-------------|-------------|------------|-------------|---------|
[Quick scores for each skill — details available via skill-deep-review]
```

### Phase 4: Triage

After generating the report:

1. Highlight the top 3–5 most impactful issues
2. Suggest which skills would benefit from a **skill-deep-review** for further investigation
3. Note any issues that **skill-improvement-plan** could address directly

Tell the user:

> "Audit complete. [X] issues found across [Y] skills. The top priorities are [brief list]. Feed this report into `/skill-improvement-plan` to generate fix plans, or use `/skill-deep-review` on [specific skills] for deeper investigation."

## Guidelines

- Optimize for speed — this is a broad scan, not a deep dive. Score quickly, flag issues, move on.
- Use subagents to parallelize check categories when available
- Don't read reference file contents unless checking for specific issues (orphans, broken links) — frontmatter + body line count is enough for most checks
- Focus on ecosystem-level patterns that individual reviews miss: conflicts, inconsistencies, gaps
- If scope is filtered, still check cross-skill references against the full inventory

## Reference Files

- `references/audit-checklist.md` — Quick-reference checklist for all bulk checks
