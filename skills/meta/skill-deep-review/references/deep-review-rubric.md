# Deep Review Rubric

Scoring criteria for each review dimension. Each dimension is scored 1–5.

## Scoring Scale

| Score | Meaning |
|-------|---------|
| 5 | Excellent — no issues, exemplary |
| 4 | Good — minor issues, fully functional |
| 3 | Adequate — works but has clear gaps |
| 2 | Needs work — functional issues or significant gaps |
| 1 | Major rework — fundamentally broken or missing |

## Dimension: Frontmatter Compliance

| Score | Criteria |
|-------|----------|
| 5 | All required fields present, all types correct, version valid semver, optional fields used appropriately |
| 4 | All required fields present and correct, minor optional field issues |
| 3 | Required fields present but some formatting issues (e.g., description too long, version not semver) |
| 2 | Missing a required field or significant type errors |
| 1 | Frontmatter absent, malformed YAML, or multiple required fields missing |

**Check:**
- `name`: kebab-case, ≤64 chars, unique across ecosystem
- `version`: valid semver (X.Y.Z)
- `description`: present, multiline YAML string
- Agent roles: `owns.directories`, `owns.patterns`, `owns.shared_read` present
- `allowed_tools`: appropriate for the skill's function
- `composes_with`: lists real skill names
- `spawned_by`: accurate if declared

## Dimension: Description Quality

| Score | Criteria |
|-------|----------|
| 5 | Action verb, 3+ trigger contexts, keyword variants, appropriate length, would reliably trigger |
| 4 | Good trigger coverage, minor gaps in keyword variants |
| 3 | Triggers for obvious cases but misses edge-case phrasings |
| 2 | Too vague ("helps with X") or too narrow (only triggers for exact phrases) |
| 1 | Missing, single-word, or would never trigger |

**Check against description-patterns.md:**
- Starts with action verb?
- Under 200 characters (target)?
- Contains ≥3 specific trigger contexts?
- Includes keyword variants users might say?
- States exclusions if commonly confused with another skill?
- "Pushy" enough to combat under-triggering?

## Dimension: Progressive Disclosure

| Score | Criteria |
|-------|----------|
| 5 | Body <300 lines, references well-organized, clear pointers, table of contents for large refs |
| 4 | Body <500 lines, references used, pointers present |
| 3 | Body approaching 500 lines, some content could move to references |
| 2 | Body >500 lines, or references exist but aren't linked |
| 1 | Everything in one massive file, or references broken/missing |

**Check:**
- SKILL.md body line count
- Are detailed checklists, templates, and tables in `references/`?
- Does the body link to references with "when to read" guidance?
- Are reference files >300 lines given a table of contents?
- Is there duplicate content between body and references?

## Dimension: Instruction Clarity

| Score | Criteria |
|-------|----------|
| 5 | Clear imperative steps, logical flow, explains reasoning, would guide any LLM correctly |
| 4 | Clear steps, mostly logical, minor ambiguities |
| 3 | Understandable but requires interpretation, some steps vague |
| 2 | Confusing flow, contradictory instructions, or steps that assume unstated context |
| 1 | Incoherent, missing process, or instructions that would mislead |

**Check:**
- Imperative voice ("Read the file" not "The file should be read")?
- Steps numbered and ordered logically?
- Explains WHY, not just WHAT?
- Avoids excessive MUST/NEVER without rationale?
- Would an LLM following these steps produce the right output?

## Dimension: Coordination

| Score | Criteria |
|-------|----------|
| 5 | Ownership clearly declared, no overlaps, composes_with accurate, handoff points defined |
| 4 | Ownership clear, minor coordination gaps |
| 3 | Ownership declared but some ambiguity, composes_with partially accurate |
| 2 | Ownership overlaps with existing skills, or coordination rules missing for agent role |
| 1 | No ownership declaration for agent role, or conflicts with multiple existing skills |

**Check (for agent roles):**
- `owns.directories` don't overlap with other agents
- Directory ownership follows precedence rules (v1.1 resolved conflicts)
- `composes_with` lists correct collaborators
- Off-limits sections clearly stated
- Handoff protocol defined if needed

**Check (for non-agent skills):**
- `composes_with` accurately reflects actual composition
- Inputs/outputs documented for pipeline integration

## Dimension: Completeness

| Score | Criteria |
|-------|----------|
| 5 | All referenced files exist, validation checklists complete, examples thorough |
| 4 | All references resolve, minor gaps in examples |
| 3 | Most references resolve, some dead links or missing examples |
| 2 | Multiple dead links or missing referenced files |
| 1 | Referenced files don't exist, no examples, critical sections missing |

**Check:**
- Every file path mentioned in SKILL.md exists
- Every reference file is linked from the body
- Validation checklists (for agent roles) have specific commands
- At least one example provided for key operations
- Templates referenced are actually present

## Dimension: Anti-Patterns

| Score | Criteria |
|-------|----------|
| 5 | No anti-patterns detected |
| 4 | One minor anti-pattern |
| 3 | 2–3 anti-patterns, none critical |
| 2 | Multiple anti-patterns including some that affect functionality |
| 1 | Pervasive anti-patterns that undermine the skill |

**Anti-pattern checklist:**
- [ ] Hardcoded project details (paths, names, URLs specific to one project)
- [ ] Excessive MUST/NEVER/ALWAYS without explaining why
- [ ] Duplicate content between SKILL.md body and references
- [ ] Overly rigid templates that leave no room for adaptation
- [ ] Instructions that fight against the LLM's natural behavior without justification
- [ ] Style-over-substance rules (mandating comment formats, variable naming) without practical impact
- [ ] "Kitchen sink" — trying to do too many things in one skill
- [ ] Assuming tools or environment features that aren't declared in `allowed_tools` or `requires_*`

## Verdict Thresholds

| Verdict | Criteria |
|---------|----------|
| **SHIP** | Average ≥4.0, no dimension below 3, trigger hit rate ≥80% |
| **NEEDS WORK** | Average ≥3.0 or 1–2 dimensions below 3, trigger hit rate ≥50% |
| **MAJOR REWORK** | Average <3.0 or 3+ dimensions below 3, or trigger hit rate <50% |
