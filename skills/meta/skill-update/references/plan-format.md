# Edit Plan Format

The plan is a one-bullet-per-edit list. Each bullet is small enough to walk past in a single confirmation but specific enough to apply verbatim.

## Header

```markdown
# Skill Update Plan
Generated: <timestamp>
Source: <report path(s) or "inline findings">
Target skill(s): <names>
Total edits: <count>

## Priority Matrix

| Priority | Impact | Effort | Edits |
|----------|--------|--------|-------|
| P0 (do first) | 3 | 1 | X |
| P1 (do next)  | 3 | 2–3, or 2 | 1 | X |
| P2 (do later) | 2 | any | X |
| P3 (backlog)  | 1 | any | X |
```

## Bullet Schema

Every edit bullet carries these fields:

```markdown
### P<n>: <one-line title>
- **Skill:** <name>
- **File:** <absolute or repo-relative path>
- **Severity:** P0 | P1 | P2 | P3
- **Category:** Frontmatter | Description | Content | Instruction | Ownership | New content | Deletion
- **What:** <specific change — the exact text or shape of the edit>
- **Why:** <which review finding this addresses>
- **Recommended answer:** <accept | modify (with suggested text) | skip>
- **How:** <terse mechanical description: "Edit frontmatter `version` 1.0.0 → 1.1.0" or "Add references/foo.md with the validation checklist">
```

## Worked Examples

### Frontmatter fix

```markdown
### P0: Bump version after description rewrite
- **Skill:** backend-agent
- **File:** skills/roles/backend-agent/SKILL.md
- **Severity:** P0
- **Category:** Frontmatter
- **What:** Set `version: 1.2.0`
- **Why:** Description was rewritten — MINOR bump per semver convention
- **Recommended answer:** accept
- **How:** Edit frontmatter `version: 1.1.0` → `version: 1.2.0`
```

### Description rewrite (verbatim text)

```markdown
### P0: Rewrite vague description
- **Skill:** docs-agent
- **File:** skills/roles/docs-agent/SKILL.md
- **Severity:** P0
- **Category:** Description
- **What:** Replace description field with:
  > "Write and maintain README, CHANGELOG, and CONTRIBUTING for orchestrated builds. Use this skill when generating project documentation, updating README sections, drafting release notes, or when someone says 'write the docs', 'update the README', 'changelog this release'."
- **Why:** Deep-review flagged trigger phrases as too narrow — missing "release notes", "changelog"
- **Recommended answer:** accept
- **How:** Replace entire `description:` block
```

### Content move to references

```markdown
### P1: Extract validation table to references
- **Skill:** qe-agent
- **File:** skills/roles/qe-agent/SKILL.md
- **Severity:** P1
- **Category:** Content
- **What:** Move the 30-row validation table from body to `references/validation-table.md`, leave a one-line pointer in the body
- **Why:** Body exceeds 500 lines; table is rarely needed inline
- **Recommended answer:** accept
- **How:** Create reference file with the table, replace table in body with `See references/validation-table.md for the full validation table.`
```

### Ownership fix (with dependency note)

```markdown
### P0: Resolve ownership overlap on `tests/`
- **Skill:** performance-agent
- **File:** skills/roles/performance-agent/SKILL.md
- **Severity:** P0
- **Category:** Ownership
- **What:** Carve out `tests/performance/` from qe-agent; performance-agent claims it
- **Why:** Audit flagged overlap with qe-agent's `tests/`
- **Recommended answer:** accept
- **How:** Add `tests/performance/` to performance-agent `owns.directories`; in same pass, ensure qe-agent's docs note the carve-out
- **Depends on:** qe-agent edit landing in the same batch
```

### Skip with reason

```markdown
### P3: Add example block to skill-writer body
- **Skill:** skill-writer
- **File:** skills/meta/skill-writer/SKILL.md
- **Severity:** P3
- **Category:** Content
- **What:** Add an "Example" subsection under "Creating a New Skill"
- **Why:** Audit suggested examples for newcomers
- **Recommended answer:** skip
- **Reasoning:** Body is already near 130 lines and reference files cover examples; revisit if onboarding feedback says otherwise
```

## Execution Notes Section

End the plan with:

```markdown
## Execution Notes
- <ordering dependencies between edits>
- <skills that should be re-reviewed after the batch>
- <edits that touch other skills indirectly>

## Post-Implementation
- [ ] Re-run skill-review on any skill with P0 edits
- [ ] Run skill-audit if ownership changed
- [ ] Sync repo to global locations
```
