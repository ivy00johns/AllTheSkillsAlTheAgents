# Audit: plan-builder

**Path:** skills/workflows/plan-builder/SKILL.md
**Version:** 1.3.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields present; semver 1.3.0; canonical hyphenated `allowed-tools`; description uses YAML `\|` literal block (no `<`/`>` issue); all 4 `composes_with` targets resolve. |
| Description quality | 4 | 673 chars — under 1024 ceiling, ~3× the 200-char target. Action verb "Transform"; multiple trigger phrases including "make a plan", "plan this out", "@-mentioned files"; clear distinction from orchestrator. Trimmable. |
| Progressive disclosure | 5 | Body 121 lines / well under 5000 words. Two references both linked with explicit purpose (lines 114–115). No duplicated content with references — body summarizes, refs detail. |
| Instruction clarity | 5 | Strong imperative voice; entry-detection table (lines 56–62) makes path selection deterministic; Path A and Path B clearly separated; behavior rules section explains WHY. |
| Coordination | 5 | Empty `owns.directories/patterns` correct for stateless skill; `composes_with` lists 4 plausible collaborators all resolve; explicit "Handoff" section (lines 92–102) defines next-skill transitions. |
| Completeness | 5 | Both reference files exist (plan-format.md, research-extraction.md). Output location defined (line 119: `docs/plans/YYYY-MM-DD-<project-name>-plan.md`). Section templates concrete. |
| Anti-patterns | 5 | No emojis; explicit "Anti-Pattern" section (lines 104–106) self-polices padding-for-structure; "Forbidden:" callout justified. Uses `<what-to-do>` / `<supporting-info>` XML-style section tags in body — non-standard but body-only, not frontmatter, so no security issue. |

**Average:** 4.86

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description is 673 chars; trimmable to ~300 by removing the redundant trigger phrase enumeration ("make a plan", "plan this out", "I want to build X from this research") which is largely covered by the catch-all sentence. — SKILL.md:5 — proposed fix: keep action verb + 3 explicit trigger phrases + the orchestrator-handoff clause; drop the rest.

### Nits (won't block ship)
- Body uses `<what-to-do>` and `<supporting-info>` XML-style section markers (lines 32 / 108 / 110 / 121). These are not in any other audited workflow skill and aren't documented in the frontmatter spec or any reference. They render harmlessly in markdown but read as quirky/idiosyncratic. — SKILL.md:32,108,110,121
- Mermaid-style ASCII flow diagram at lines 47–50 could be a real mermaid flowchart since `mermaid-charts` is in `composes_with`. Minor.
- `compatibility` field absent; skill writes files to `docs/plans/` so requires Bash + write access — declaring this is good hygiene.
- The skill references "brainstorming" (lines 42, 80) and "writing-plans" (lines 44, 99) as sibling skills — those are superpowers-namespace skills, not in this repo's `skills/`. The pointer makes sense for users on Claude.ai with superpowers loaded, but for repo-local consumers the reference is dangling. Worth a footnote.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Trim description from 673 → ~300 chars — SKILL.md:5 — drop the inline trigger-phrase enumeration ("make a plan", "plan this out", "I want to build X from this research") and keep the catch-all sentence + the closing "produces the plan — orchestrator consumes it." Effort: small.
2. Remove or normalize the `<what-to-do>` / `<supporting-info>` section tags — SKILL.md:32,108,110,121 — replace with standard `## What to do` / `## Supporting info` H2 headings to match the rest of the ecosystem. Effort: small.
3. Add `compatibility` field — SKILL.md:8 — declare "Claude Code or Claude.ai; requires Write access for `docs/plans/`." Effort: small.

## Dead links / broken references
- None within this repo. Both reference files exist. All 4 `composes_with` targets resolve.
- `brainstorming` and `writing-plans` cross-references (body lines 42, 44, 80, 99) point to superpowers-namespace skills not in this repo — acceptable since they're a known plugin, but readers without superpowers won't find them.
