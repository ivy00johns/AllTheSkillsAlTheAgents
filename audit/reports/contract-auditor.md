# Audit: contract-auditor

**Path:** skills/contracts/contract-auditor/SKILL.md
**Version:** 1.1.0
**Category:** contracts
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields present; valid semver; no angle brackets; allowed-tools hyphenated. Includes non-standard field `disable-model-invocation: true` at L4 — this isn't in the frontmatter-spec.md but it intentionally signals "not user-invocable" (the description also says so). Description 201 chars — just over the 200-char target, within the 1024 ceiling. owns.directories and owns.patterns are empty (correct for a read-only auditor); shared_read uses wildcard `["*"]`. |
| Description quality | 4 | Action verb ("Audits"), declares dispatch model ("Orchestrator-dispatched only"), states intent ("find mismatches before integration testing"), states pipeline position ("Composed by orchestrator during multi-agent builds"). Lacks keyword variants users might say (e.g. "audit the contract", "compare implementation to contract") — but that's appropriate since the skill is intentionally not user-invocable. |
| Progressive disclosure | 5 | Body 179 lines / ~1111 words — well within guidelines. Single reference (`pact-setup.md`, 142 lines) linked explicitly at L170 with "when to read" guidance ("For projects that use consumer-driven contract testing"). |
| Instruction clarity | 5 | Numbered Process steps 1-8 with imperative voice ("Read contracts/openapi.yaml", "Find route definitions", "Check"). Each step has Check: bullets enumerating what to verify. WHY explained throughout (e.g., "Manual construction is the #1 cause of field-naming drift", "this is unique value the auditor provides that the qe-agent cannot"). Severity Guidelines section is explicit (CRITICAL/HIGH/MEDIUM/LOW). |
| Coordination | 5 | Read-only role correctly declared. Coordination Rules section explicitly distinguishes auditor vs qe-agent (static vs runtime) and auditor vs contract-author (verify vs generate). composes_with lists the right partners (contract-author, qe-agent, backend-agent, frontend-agent), all of which exist locally. spawned_by ["orchestrator"] accurate. |
| Completeness | 5 | The one reference (pact-setup.md) exists and is linked from the body. Audit report template is included inline at L138-159 with concrete schema. Severity guidelines bounded. Input requirements (contracts/, agent_ownership, tech_stack, service_map) enumerated upfront. |
| Anti-patterns | 5 | Coordination Rules explicitly state "Read-only — you never modify code", "Contract is truth", "Flag ambiguities — if the contract is ambiguous, flag it to the lead — don't assume the implementation is wrong when the contract is unclear" — this is the rare skill that explicitly tells the LLM when NOT to act. No hardcoded paths (uses `${BACKEND_SRC}` placeholders). Grep commands have realistic per-language `--include` flags rather than over-rigid invocations. |

**Average:** 4.71

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Frontmatter uses non-standard field `disable-model-invocation: true` (SKILL.md:4) not listed in `references/frontmatter-spec.md` — proposed fix: either document this field as a house-style extension in the frontmatter spec (alongside `requires_agent_teams`, `requires_claude_code`, etc.) OR remove the field and rely solely on the description's "Not user-invocable" signal. Currently the field is informal and parsers will ignore it — but its presence on one skill and not others is inconsistent.

### Nits (won't block ship)
- `owns.shared_read: ["*"]` is a wildcard — SKILL.md:12 — consider listing the actual directories the auditor needs to read (e.g., `["contracts/", "src/", "backend/", "frontend/"]`) so future ownership conflicts can be spotted.
- Description is exactly 201 chars, just over the 200-char target. SKILL.md:5 — trim "Composed by orchestrator during multi-agent builds." (redundant with "Orchestrator-dispatched only.") to drop ~52 chars and land near 150.
- `description` is a quoted single-line string while most other skills use multi-line `|` block scalar form. SKILL.md:5 — minor consistency nit; both are valid YAML.
- Field-order drift: `disable-model-invocation` (L4) appears between `version` and `description`, breaking the standard order (name → version → description → optional fields). Move to between `min_plan` and `owns` if kept.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Document or remove the `disable-model-invocation` field** — SKILL.md:4 — add it to `skills/meta/skill-writer/references/frontmatter-spec.md` as a house-style extension OR remove the line and rely on the description-only signal. Consistency matters: this field appears nowhere else in the ecosystem. Effort: small.
2. **Replace `owns.shared_read: ["*"]` with explicit list** — SKILL.md:12 — change to `["contracts/", "src/", "backend/", "frontend/", "docs/"]`. Effort: small.
3. **Trim description to under 200 chars** — SKILL.md:5 — remove "Composed by orchestrator during multi-agent builds." (redundant). Effort: small.

## Dead links / broken references
- None. `references/pact-setup.md` exists (142 lines). All composes_with targets (contract-author, qe-agent, backend-agent, frontend-agent) exist locally. spawned_by ["orchestrator"] resolves.
