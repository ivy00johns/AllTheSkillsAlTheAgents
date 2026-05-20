# Audit Checklist

Quick-reference checklist for every per-skill and ecosystem-level check `skill-review` runs. Each item maps back to a phase in the SKILL.md process.

## Per-Skill Checks

Run these for every skill in scope. In Mode A (bulk) they roll up to PASS / WARN / FAIL. In Mode B (deep dive) each one feeds the rubric score in `deep-review-rubric.md`.

### Frontmatter

- [ ] `name` field present, kebab-case, ≤64 chars
- [ ] `name` starting with `claude-` or `anthropic-` (reserved by Anthropic) — **WARN**, not FAIL. Acceptable when the skill targets the corresponding Anthropic product and the exception is documented in the skill body (e.g., `claude-design-brief` for Claude Design). Confirm the documented exception exists before clearing the warning.
- [ ] `name` matches the directory name
- [ ] `version` field present (top-level), valid semver
- [ ] `description` field present
- [ ] No `<` or `>` anywhere in the frontmatter block — **FAIL** (security rule)
- [ ] Description starts with an action verb
- [ ] Description length ≤200 characters (target) and ≤1024 (hard ceiling — **FAIL** if exceeded)
- [ ] Description follows the `[What] + [When] + [Capabilities]` anatomy
- [ ] Agent role skills have an `owns` block with `directories`, `patterns`, `shared_read`
- [ ] `allowed-tools` (hyphen, canonical) is appropriate for the skill's function. `allowed_tools` (underscore) still accepted as deprecated alias — flag as WARN
- [ ] `compatibility` field is present for skills with host/tool requirements (recommended, not required)
- [ ] `metadata` is a nested object if present (author, category, tags, mcp-server)
- [ ] `composes_with` references existing skills
- [ ] `spawned_by` references existing skills
- [ ] `argument-hint` present if the skill takes an argument

### Body Structure

- [ ] Body ≤5,000 words (Anthropic guideline) — WARN past this
- [ ] Body ≤500 lines (this repo's rule of thumb: anything past ~200 should probably move to references) — WARN past this
- [ ] Heavy skills (`orchestrator`, `ui-ux-pro-max`, `repo-deep-dive`) may exceed both — note as accepted divergence rather than flag
- [ ] Has a role/purpose statement
- [ ] Has a process or steps section
- [ ] Uses imperative voice ("Read the file" not "The file should be read")
- [ ] References are linked from the body with "when to read" guidance

### References

- [ ] All referenced files exist
- [ ] References linked from the body with explicit "when to read" guidance
- [ ] No reference files >300 lines without a table of contents
- [ ] No orphan reference files (exist but never linked from any SKILL.md)

## Ecosystem-Level Checks

Run these once across the full inventory in Mode A.

### Ownership

- [ ] No two agent roles share `owns.directories` entries
- [ ] No `owns.directories` conflicts with the v1.1 resolved conflicts table
- [ ] Directory ownership takes precedence over pattern ownership
- [ ] performance-agent carve-out of `tests/performance/` from qe-agent is respected

### Cross-References

- [ ] All `composes_with` targets exist
- [ ] All `spawned_by` targets exist
- [ ] No circular `composes_with` chains (A→B→A)
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

## Anti-Pattern Checklist

Flag any of these in Mode B; aggregate counts in Mode A.

- [ ] Hardcoded project details (paths, names, URLs specific to one project)
- [ ] Excessive MUST / NEVER / ALWAYS without explaining why
- [ ] Duplicate content between SKILL.md body and references
- [ ] Overly rigid templates that leave no room for adaptation
- [ ] Instructions that fight against the LLM's natural behavior without justification
- [ ] Style-over-substance rules (mandating comment formats, variable naming) without practical impact
- [ ] "Kitchen sink" — trying to do too many things in one skill
- [ ] Assuming tools or environment features that aren't declared in `allowed-tools`, `compatibility`, or `requires_*`

## Bulk Scoring Quick Reference

For per-skill scores in the Mode A report, use simplified triage:

| Score | Meaning |
|-------|---------|
| PASS | No issues found |
| WARN | Minor issues, functional |
| FAIL | Issues that affect functionality or ecosystem integrity |

Mode A doesn't deep-score dimensions — that's Mode B's job. It flags pass / warn / fail for triage.
