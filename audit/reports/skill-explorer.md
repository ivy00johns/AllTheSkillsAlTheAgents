# Audit: skill-explorer

**Path:** skills/meta/skill-explorer/SKILL.md
**Version:** 1.0.0
**Category:** meta
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 3 | All required fields present; valid semver (1.0.0); no angle brackets; allowed-tools hyphenated; owns block correctly empty for a read-only routing skill. BUT: description is 1023 chars — exactly 1 char under the 1024 hard ceiling, dangerously close. composes_with includes two archived skills (skill-audit, skill-deep-review) which is a broken cross-skill reference. |
| Description quality | 3 | Action verb ("Help"), extensive trigger enumeration with 15+ concrete user phrases ("I forgot the name", "what was that skill called", "what skills do I have", "what does X do", "which skill for Y"). Very "pushy". BUT: 1023 chars (sits at the ceiling) and the multiline | scalar makes it harder to scan. |
| Progressive disclosure | 5 | Body 162 lines / ~1405 words — within all guidelines. Single reference (routing-table.md at 148 lines) linked at L161 with explicit "when to read" context ("used when the four rules of thumb above don't cover the case"). Below 300-line TOC threshold. The body has an `evals/` directory with evals.json — bonus infrastructure for trigger testing. |
| Instruction clarity | 5 | Four modes (Recall/Catalog/Explain/Route) defined in a clear table at L35-40. Each mode has an explicit output format example. Imperative voice ("name the role skill directly", "say so explicitly"). Routing rules of thumb section gives concrete decision rules. "Core principle: name, don't invoke" is well-articulated with an explicit exception clause. |
| Coordination | 2 | composes_with at L24 lists `skill-audit` and `skill-deep-review` — both archived (now `skill-review` with two modes). This is a broken cross-skill reference per the AGENT_BRIEF flag list ("Cross-skill links pointing at nonexistent skills (FAIL)"). spawned_by empty (correct). Also references stale skill names in body at L131, L144. |
| Completeness | 4 | routing-table.md exists. Output format examples comprehensive. BUT: L30 hardcodes "38 repo skills" which is stale (per CLAUDE.md the count is now ~46-47); the body itself flags that "Names blur together" which is somewhat ironic given the stale count. Evals infrastructure present in `evals/evals.json`. |
| Anti-patterns | 4 | Excellent anti-patterns table at L149-157 with rationale ("Auto-invoking hides the decision", "Listing 5 candidates when one fits"). "When NOT to invoke" section actively prevents over-triggering. Imperative voice. BUT: routing rule at L131 directs users to dead skills (skill-audit, skill-deep-review), so the skill would actively misroute users today. |

**Average:** 3.71

## Findings

### Critical (must fix to ship)
- composes_with references two archived skills — SKILL.md:24 — `composes_with: ["skill-audit", "skill-deep-review", "skill-writer"]` — both archived (see `skills/archive/skill-audit/` and `skills/archive/skill-deep-review/`). Proposed fix: replace with `composes_with: ["skill-review", "skill-writer", "skill-update"]`.
- Routing rule at L131 sends users to dead skills — SKILL.md:131 — change `"Audit / review my skills"** → \`skill-audit\` (broad), \`skill-deep-review\` (one skill deep)` to `"Audit / review my skills"** → \`skill-review\` (\`--scope=all\` for broad, \`--scope=<name>\` for deep)`.
- "When NOT to invoke this skill" rule at L144 references dead skill — SKILL.md:144 — change "that's `skill-audit`. Same deal." to "that's `skill-review`. Same deal."

### Important (should fix)
- Description is 1023 chars — SKILL.md:5-15 — exactly 1 char under the 1024 hard ceiling. Any future addition will push it over. Proposed fix: tighten the multi-clause sentence at L11-15 to drop ~200 chars while keeping the strongest 4-5 trigger contexts.
- Hardcoded skill count "38 repo skills" — SKILL.md:30 — stale (CLAUDE.md says ~46). Proposed fix: change to "a large toolkit (40+ repo skills plus plugin skills)" or omit the number entirely.

### Nits (won't block ship)
- Description uses multiline `|` block scalar with hard wraps that don't add value (Claude reads it as flowing text). SKILL.md:5-15 — consider folding to a single paragraph for better readability.
- Mermaid suggestion at L121 ("render a small mermaid diagram or text tree") doesn't reference `mermaid-charts` skill — the explorer is a meta-skill that should know about composition; pointing at `mermaid-charts` would dogfood the routing pattern.
- L62 says "Plugin skills come from `~/.claude/plugins/`" — accurate path but plugin location is environment-dependent; consider noting "or wherever Claude Code is configured to load them."
- "Anti-patterns" table at L149-157 uses non-standard double-line table formatting (extra space) — works in most renderers but inconsistent with other tables in the same file (L35-40 uses standard pipes).

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Replace archived-skill references with current skill-review** — SKILL.md:24, 131, 144 — composes_with becomes `["skill-review", "skill-writer", "skill-update"]`; L131 routing rule points at `skill-review --scope=all` (broad) / `skill-review --scope=<name>` (deep); L144 "When NOT to invoke" references `skill-review`. Effort: small.
2. **Trim description below 800 chars to leave headroom** — SKILL.md:5-15 — currently 1023 chars (1 under ceiling). Keep the 4-5 strongest trigger contexts ("I forgot the name", "what skills do I have", "what does X do", "which skill for Y") and drop the longer enumerations. Effort: medium.
3. **Update stale skill count "38 repo skills"** — SKILL.md:30 — change to "a large toolkit (40+ repo skills plus plugin skills)" or drop the count entirely. Effort: trivial.

## Dead links / broken references
- `skill-audit` in composes_with (SKILL.md:24) — **broken** (archived).
- `skill-deep-review` in composes_with (SKILL.md:24) — **broken** (archived).
- `skill-audit` in body routing rule (SKILL.md:131) — **broken** (archived).
- `skill-deep-review` in body routing rule (SKILL.md:131) — **broken** (archived).
- `skill-audit` in "When NOT to invoke" (SKILL.md:144) — **broken** (archived).
- `references/routing-table.md` — resolves (148 lines).
- All composes_with entries except the two archived ones are correct.
