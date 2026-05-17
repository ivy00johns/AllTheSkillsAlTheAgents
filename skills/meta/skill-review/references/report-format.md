# Output Format Specification

This file is a schema reference for `skill-review` output. It is read by the skill at runtime and by `skill-update` to parse the JSON sidecar. It is not an actual review.

## Output File Names

| Mode | Markdown artifact | JSON sidecar artifact |
|------|-------------------|-----------------------|
| A (`--scope=all`) | `skill-review-report.md` at the repo root (or a user-specified path) | `skill-review-report.json` next to it |
| B (`--scope=<name>`) | `{skill-path}/skill-review-report.md` | `{skill-path}/skill-review-report.json` |

## Mode A Markdown Template

The Mode A run fills in the template below. Keep the section order stable so downstream tooling can locate sections.

```markdown
# Ecosystem Review Output
Reviewed: [ISO-8601 timestamp]
Scope: all  (or: filtered description)
Skills scanned: [count]

## Executive Summary
- Total skills: X
- Passing: X (X%)
- Issues found: X (X critical, X high, X medium, X low)
- Ownership conflicts: X

## Skill Inventory
| Skill | Category | Version | Desc Length | Body Lines | Refs | Status |
|-------|----------|---------|-------------|------------|------|--------|

## Ownership Map
[Tabular representation of which agent owns what]

### Conflicts
[Any overlaps detected — empty if none]

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
|-------|------------|-------|

### Cross-Skill Issues
| Issue Type | Skills Involved | Description |
|------------|-----------------|-------------|

## Coverage Gaps
[Capabilities referenced in `docs/architecture.md`, `CLAUDE.md`, or orchestrator phase-guide that no existing skill covers]

## Recommendations
[Top 5 highest-impact improvements, ordered by priority. For each, name the skill(s) involved and the suggested action.]

## Per-Skill Scores
| Skill | Frontmatter | Description | Disclosure | Consistency | Overall |
|-------|-------------|-------------|------------|-------------|---------|
[PASS / WARN / FAIL per column. Details available via `--scope=<name>` follow-up.]
```

## Mode B Markdown Template

```markdown
# Single-Skill Review Output: [skill-name]
Reviewed: [ISO-8601 timestamp]
Skill path: [path]
Why-now: [optional — the user-supplied context]

## Summary
| Dimension | Score (1-5) | Issues |
|-----------|-------------|--------|
| Frontmatter compliance | X | Y |
| Description quality | X | Y |
| Progressive disclosure | X | Y |
| Instruction clarity | X | Y |
| Coordination | X | Y |
| Completeness | X | Y |
| Anti-patterns | X | Y |

**Overall score:** X.X / 5.0
**Verdict:** SHIP | NEEDS WORK | MAJOR REWORK

## Trigger Testing
- Should-trigger hit rate: X/Y (Z%)
- False-positive rate: X/Y (Z%)
- Problem triggers: [list any that failed]
- Skipped: [reason, if skill-creator was unavailable]

## Issues

### [SEVERITY]-[N]: [Title]
- **Dimension:** [which]
- **Location:** [file:line or frontmatter field]
- **Description:** [what is wrong]
- **Suggestion:** [how to fix]

## Strengths
[What the skill does well — specific examples]

## Recommendations
[Prioritized list of improvements, ordered by impact]
```

## JSON Sidecar Schema

`skill-update` consumes the JSON sidecar. Both modes emit the same top-level shape; the `mode` field disambiguates and only the relevant sub-block is populated.

```json
{
  "schema_version": "1.0.0",
  "tool": "skill-review",
  "mode": "all",
  "reviewed_at": "ISO-8601",
  "scope": "all",
  "summary": {
    "skills_scanned": 0,
    "issues_total": 0,
    "issues_by_severity": {"critical": 0, "high": 0, "medium": 0, "low": 0},
    "ownership_conflicts": 0
  },
  "bulk": {
    "inventory": [
      {
        "name": "skill-name",
        "category": "meta",
        "version": "1.0.0",
        "description_length": 0,
        "body_lines": 0,
        "refs_count": 0,
        "status": "PASS"
      }
    ],
    "ownership_conflicts": [
      {"resource": "src/api/", "agents": ["backend-agent", "qe-agent"]}
    ],
    "cross_skill_issues": [
      {"type": "broken_composes_with", "from": "skill-a", "to": "skill-b"}
    ],
    "coverage_gaps": [
      {"capability": "string", "source": "docs/architecture.md"}
    ]
  },
  "single": {
    "skill_name": "skill-name",
    "skill_path": "skills/meta/skill-name",
    "dimensions": {
      "frontmatter_compliance": {"score": 5, "issues": []},
      "description_quality": {"score": 5, "issues": []},
      "progressive_disclosure": {"score": 5, "issues": []},
      "instruction_clarity": {"score": 5, "issues": []},
      "coordination": {"score": 5, "issues": []},
      "completeness": {"score": 5, "issues": []},
      "anti_patterns": {"score": 5, "issues": []}
    },
    "overall_score": 5.0,
    "verdict": "SHIP",
    "trigger_testing": {
      "skipped": false,
      "should_trigger_hits": 0,
      "should_trigger_total": 0,
      "false_positives": 0,
      "false_positive_total": 0,
      "problem_triggers": []
    },
    "strengths": []
  },
  "issues": [
    {
      "id": "HIGH-1",
      "severity": "high",
      "skill": "skill-name",
      "dimension": "description_quality",
      "location": "frontmatter.description",
      "description": "string",
      "suggestion": "string"
    }
  ],
  "recommendations": [
    {"priority": 1, "skill": "skill-name", "action": "string"}
  ]
}
```

Allowed enum values:

- `mode`: `all` | `single`
- `status`: `PASS` | `WARN` | `FAIL`
- `severity`: `critical` | `high` | `medium` | `low`
- `verdict`: `SHIP` | `NEEDS WORK` | `MAJOR REWORK`

## Severity Levels

| Severity | Use for |
|----------|---------|
| critical | Skill cannot function (missing frontmatter, broken YAML, no description) |
| high | Skill works but likely under-triggers, has ownership conflicts, or violates ecosystem rules |
| medium | Functional but missing references, weak descriptions, or minor anti-patterns |
| low | Style nits and polish |

## Handoff to skill-update

`skill-update` reads `skill-review-report.json` and converts each entry in `issues` into a proposed edit. The `id`, `skill`, `dimension`, `location`, and `suggestion` fields are the contract — keep their names stable across versions.
