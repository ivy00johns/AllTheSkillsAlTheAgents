# Audit Checklist

Quick-reference checklist for bulk audit checks. Each item maps to a section in the audit process.

## Per-Skill Checks

Run these for every skill in scope:

### Frontmatter
- [ ] `name` field present, kebab-case, ≤64 chars
- [ ] `name` matches directory name
- [ ] `version` field present, valid semver
- [ ] `description` field present
- [ ] Description starts with action verb
- [ ] Description length ≤200 characters (target, not hard limit)
- [ ] Agent roles have `owns` block with `directories`, `patterns`, `shared_read`
- [ ] `allowed_tools` appropriate for skill function
- [ ] `composes_with` references existing skills
- [ ] `spawned_by` references existing skills

### Body Structure
- [ ] Body ≤500 lines
- [ ] Has role/purpose statement
- [ ] Has process/steps section
- [ ] Uses imperative voice
- [ ] References link to existing files

### References
- [ ] All referenced files exist
- [ ] References linked from body with "when to read" guidance
- [ ] No reference files >300 lines without table of contents
- [ ] No orphan reference files (exist but never linked)

## Ecosystem-Level Checks

Run these once across the full inventory:

### Ownership
- [ ] No two agent roles share `owns.directories` entries
- [ ] No `owns.directories` conflicts with v1.1 resolved conflicts table
- [ ] Directory ownership takes precedence over pattern ownership
- [ ] Performance-agent carve-out of `tests/performance/` from qe-agent respected

### Cross-References
- [ ] All `composes_with` targets exist
- [ ] All `spawned_by` targets exist
- [ ] No circular `composes_with` chains
- [ ] `spawned_by` is reciprocal where expected (A spawns B → B.spawned_by includes A)

### Coverage
- [ ] All roles described in `docs/architecture.md` and `CLAUDE.md` have skill implementations
- [ ] All workflows the orchestrator phase-guide depends on have skill implementations
- [ ] Contract types (OpenAPI, AsyncAPI, Pydantic, TypeScript, JSON Schema) all have templates

### Consistency
- [ ] Version numbering convention consistent (all start at 1.0.0 or follow semver from there)
- [ ] Author field consistent across skills
- [ ] License field consistent across skills
- [ ] `requires_agent_teams` declared where agent team features are used
- [ ] `requires_claude_code` declared where CLI features are used

## Scoring Quick Reference

For per-skill scores in the audit report, use simplified scoring:

| Score | Meaning |
|-------|---------|
| PASS | No issues found |
| WARN | Minor issues, functional |
| FAIL | Issues that affect functionality or ecosystem integrity |

The audit doesn't deep-score dimensions (that's skill-deep-review's job). It flags pass/warn/fail for triage.
