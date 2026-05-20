# Audit: orchestrator

**Path:** skills/orchestrator/SKILL.md
**Version:** 1.8.0
**Category:** orchestrator
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 2 | Description is 1444 chars — exceeds the 1024-char Anthropic hard ceiling (brief calls this a hard FAIL). Otherwise: name kebab-case, version valid semver, no angle brackets, allowed-tools hyphenated, owns block present, composes_with populated, spawned_by present (empty list, correct for top-level skill). |
| Description quality | 3 | Comprehensive trigger coverage with strong action verbs ("Lead", "INVOKES", "DISPATCHES"), explicit exclusions, keyword variants ("agent team", "parallel build", "MISSION.md") — but the >1024-char length is a structural fail. Reads more like an essay than a tight trigger paragraph. |
| Progressive disclosure | 4 | Body is 233 lines / ~3330 words — within the 5000-word soft ceiling for a heavy skill. References well-organized; each is linked from the body with explicit "when to read" guidance. phase-guide.md (185 lines) is below the 300-line TOC threshold. References sum to 823 lines — load-bearing length is justified. |
| Instruction clarity | 4 | Numbered Quick Start steps 0-14, clear imperative voice ("Read the plan", "Spawn QE agent"), good rationale (e.g. "50% effort on design", explains WHY in Anti-Patterns table). Step 9a appears as a sub-step interleaved with 10–13 — slightly awkward numbering. Some steps (3, 13) are dense paragraphs that mix multiple actions. |
| Coordination | 5 | Ownership cleanly declared (only `.gitignore` pattern + shared_read for `contracts/`, `.claude/handoffs/`). Composes_with is exhaustive and accurate. File-ownership reference exists. spawned_by correctly empty (top-level coordinator). |
| Completeness | 5 | All 9 referenced files exist (`agent-spawning.md`, `circuit-breaker.md`, `file-ownership.md`, `handoff-protocol.md`, `mission-interpretation.md`, `phase-guide.md`, `team-sizing.md`, `wave-gate.md`, `workspace-bootstrap.md`). qa-report-schema reference at L153 points at `roles/qe-agent/references/qa-report-schema.json` (canonical path). DoD checklist thorough. |
| Anti-patterns | 4 | Excellent dedicated Anti-Patterns table with prevention rationale. Minor: "Anti-Pattern" section at L194-196 is a near-duplicate header below the larger table (could merge). Definition of Done has a duplicated "9." (line 211 "9a." then line 213 jumps to 10) — numbering nit. No hardcoded project paths. |

**Average:** 3.86

## Findings

### Critical (must fix to ship)
- Description exceeds the 1024-char Anthropic hard ceiling (1444 chars) — SKILL.md:5 — proposed fix: split the description into a tight ≤200-char trigger paragraph (action verb + 3 trigger contexts + key keywords) and move the long enumeration of composed skills and "does NOT preempt" exclusions into a `## Composition` body section. Suggested rewrite: "Coordinate multi-agent Claude Code builds end-to-end: read the plan/mission, design contracts, dispatch role-agents in parallel, gate on QA, and ship. Use when the user mentions agent teams, parallel builds, swarm builds, multi-agent, MISSION.md, or wants to split work across Claude sessions. Composes with brainstorming, plan-builder, contract-author, role agents, ux-review, render-sanity, deployment-checklist."

### Important (should fix)
- Definition of Done has a numbering bug: two items labeled "9" (line 211 "9a." then line 213 reads "10. Contract changelog clean", which would make the original 9 vs 9a a single logical step but appears mis-numbered) — SKILL.md:209-215 — proposed fix: renumber 9a → 10 and shift 10-13 down, or convert 9 + 9a into a single step with sub-bullets.
- Duplicate "Anti-Pattern" header below the large Anti-Patterns table — SKILL.md:194-196 — proposed fix: fold this AFK/HITL forbiddance into a new row at the bottom of the table at L191 (one row: "Spawning without AFK/HITL classification | Every agent dispatch must declare it can finish unattended.").

### Nits (won't block ship)
- Quick Start section uses 0-indexed step (step 0) which can confuse — SKILL.md:65 — consider renaming "Step 0" to "Step 1: Check the wiki" and shifting.
- Frontmatter field order: `allowed-tools` (L13) appears after `owns` (L9-12) — the AGENT_BRIEF lists `allowed-tools` before `owns` in the house ordering. Move L13 to between L8 (`min_plan`) and L9 (`owns`).
- `composes_with` includes `claude-mem:*` entries with `:` plugin-prefix form — works as informational, but mixes plugin-namespaced and bare names. Consider adding a comment noting these are plugin-namespaced.
- `composes_with` includes external skills (frontend-design, ui-ux-pro-max, ux-review, feature-dev, claude-api, brainstorming, writing-plans, loop, schedule) that aren't in this repo's `skills/` tree — they live in plugins/superpowers. Currently fine but worth a body note that some composed skills are external.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Compress the description below the 1024-char ceiling** — SKILL.md:5 — rewrite as ≤200 char tight trigger paragraph; move the "INVOKES x for y / DISPATCHES x" enumeration and the "does NOT preempt" exclusion list into a new `## Composition` body section near `## When this skill applies`. Effort: small.
2. **Fix Definition of Done numbering** — SKILL.md:209-215 — promote "9a." to its own number (10) and renumber subsequent items 10→11, 11→12, 12→13, 13→14, or fold 9 + 9a together with sub-bullets. Effort: small.
3. **Merge the orphan "Anti-Pattern" header into the main Anti-Patterns table** — SKILL.md:194-196 — delete L194-196 and add a new row at L191: `| Spawning without explicit AFK/HITL classification | Every agent dispatch must declare it can finish unattended. |`. Effort: small.

## Dead links / broken references
- None. All 9 `references/*.md` files resolve. The qa-report-schema path (`roles/qe-agent/references/qa-report-schema.json`) at SKILL.md:153 resolves to a real file. Composed-with skills that aren't local (`frontend-design`, `ui-ux-pro-max`, `ux-review`, `feature-dev`, `claude-api`, `brainstorming`, `writing-plans`, `loop`, `schedule`, `claude-mem:*`) are provided by external plugins/superpowers in the available-skills list — not broken refs.
