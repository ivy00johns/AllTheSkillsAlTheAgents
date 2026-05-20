# Audit: maintain-context

**Path:** skills/workflows/maintain-context/SKILL.md
**Version:** 1.1.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields present; semver `1.1.0`; canonical hyphenated `allowed-tools`; no `<`/`>` in frontmatter; `composes_with` targets `grill-me` + `architecture-rescue` both exist. |
| Description quality | 4 | 729 chars (well under 1024); action verb "Maintain"; lists 7 explicit trigger phrases; embeds the three-condition gate logic. Slightly long — could lose 200 chars without losing trigger coverage. |
| Progressive disclosure | 5 | Body 89 lines / 962 words. Three references (adr-format, context-format, three-condition-gate), each linked from the body with explicit "when to read" pointers (lines 59, 84). |
| Instruction clarity | 5 | Imperative voice throughout; three-condition gate explained with rationale ("Why this gate matters" line 29); inline-update pattern, lazy file creation, and `domain-docs.md` precondition all stated in order. |
| Coordination | 5 | `owns.directories: []`, `owns.patterns: ["CONTEXT.md", "docs/adr/**"]` — no overlap with other agents; `composes_with` lists real skills; integrates `/setup-project-skills` (lines 65–70). |
| Completeness | 5 | All three referenced files exist on disk; each is linked from the body; worked examples in references include a fully-fleshed ADR (adr-format.md lines 37–62) and three CONTEXT.md entry types. |
| Anti-patterns | 5 | No emojis, no hardcoded project paths (uses generic placeholders), MUSTs are justified ("Why this gate matters"); only one "Forbidden:" callout (line 45), and it's explained. |

**Average:** 4.86

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description is 729 chars — above the 200-char target. Trimmable by collapsing the "ONLY when all three are true" recital (already covered in the body and references). — SKILL.md:4 — proposed fix: cut the inline three-condition recital from the description; keep one summary clause plus the trigger phrases.

### Nits (won't block ship)
- `docs/agents/domain-docs.md` is referenced as a hard precondition (line 67) but no skill in the repo currently writes it; the description mentions `/setup-project-skills` as the producer, which is a workflow skill present. Worth a sentence confirming setup-project-skills is the writer. — SKILL.md:67–70
- "See `references/three-condition-gate.md`" at line 84 — fine, but the same reference is also implicitly invoked by the gate summary in the body (lines 21–29). Mild duplication of the gate's three conditions between SKILL.md (lines 25–27) and references/three-condition-gate.md (lines 5–7). Acceptable as a "scannable summary + deep dive" pattern.
- `composes_with` could add `setup-project-skills` since the body explicitly depends on its output (`docs/agents/domain-docs.md`).

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Trim description from 729 → ~300 chars — SKILL.md:4 — drop the "ONLY when all three are true…" recital and the "If any condition is missing, skip" clause (both restated in the body); keep action verb + 7 trigger phrases. Effort: small.
2. Add `setup-project-skills` to `composes_with` — SKILL.md:13 — body treats it as a hard upstream producer (line 67) but frontmatter doesn't reflect that compose relationship. Effort: small.
3. Add a one-line cross-reference at line 70 confirming `setup-project-skills` writes `docs/agents/domain-docs.md` — currently the body says "written by `/setup-project-skills`" parenthetically (line 66); promote that to an explicit pointer with the skill path. Effort: small.

## Dead links / broken references
- None. All three `references/*.md` files exist and are linked. `composes_with` targets (`grill-me`, `architecture-rescue`) both exist under `skills/workflows/`.
- `docs/agents/domain-docs.md` is a runtime artifact (project-local), not a repo file — correct to reference as a precondition.
