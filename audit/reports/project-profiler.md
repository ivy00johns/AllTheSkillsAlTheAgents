# Audit: project-profiler

**Path:** skills/workflows/project-profiler/SKILL.md
**Version:** 1.1.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields; semver 1.1.0; canonical hyphenated `allowed-tools`; description uses YAML `\|` literal; all 3 `composes_with` targets resolve; `spawned_by: ["orchestrator"]` resolves and orchestrator's body references project-profiler. `owns.patterns: ["CLAUDE.md", ".claude/profile.yaml"]` matches the v1.1 resolved-conflicts table in the frontmatter spec. |
| Description quality | 5 | 483 chars — closest to the 200-char target of any audited workflow this batch. Action verb "Analyze"; 8 explicit trigger phrases; specifies both output artifacts (CLAUDE.md + profile.yaml). |
| Progressive disclosure | 5 | Body 123 lines / well under 5000 words. One reference (`profile-schema.yaml`) linked from the body at line 100 with explicit purpose. No duplication — body summarizes process; YAML schema documents the artifact. |
| Instruction clarity | 5 | Strong imperative voice; numbered 7-step process (Detect Stack → Map Dirs → Detect Conventions → Auth → CI/CD → profile.yaml → CLAUDE.md); concrete grep-style indicator table (lines 46–54). Quality checklist (lines 116–123) testable. |
| Coordination | 5 | Pattern-based ownership of `CLAUDE.md` + `.claude/profile.yaml` matches the v1.1 ownership resolution table verbatim (frontmatter-spec.md:213); explicit conflict-resolution note in body (line 31); `composes_with` accurate; `spawned_by` reciprocal. |
| Completeness | 5 | The single reference (`profile-schema.yaml`) exists and is detailed (75 lines, fully typed). All process steps map to outputs. Quality checklist concrete. Off-limits clause stated (line 30: "you analyze but never modify"). |
| Anti-patterns | 5 | No emojis; no hardcoded project paths beyond examples; MUSTs minimal; no body/reference duplication; "Off-limits" explicit. |

**Average:** 5.00

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- None — this skill is exemplary.

### Nits (won't block ship)
- `compatibility` field absent; skill requires Bash + filesystem access to scan code — declaring this is good hygiene. — SKILL.md:8
- CLAUDE.md target is "≤200 lines" (line 20, 104, 119) but the repo's own CLAUDE.md is currently 64 lines — fine for the rule, but the 200-line cap could mention the rationale (agent context budget) for first-time profilers.
- The reference is a `.yaml` file rather than a `.md` file. The audit-checklist says "all referenced files exist" — it does — but a parser scanning for `references/*.md` would miss it. Not a real issue since the body links to `references/profile-schema.yaml` explicitly.
- Step 4 "Identify Auth Pattern" (line 79–87) and Step 5 "Map CI/CD" (line 89–96) feel narrower than the open-ended Steps 1–3. Some projects have neither; the schema should let those be `null` (it does — `profile-schema.yaml` allows it) but the body could say so.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Add `compatibility` field — SKILL.md:8 — declare "Claude Code; requires Bash + Read + Write for repo-root and `.claude/`." Effort: small.
2. Add a one-line rationale for the ≤200-line CLAUDE.md cap — SKILL.md:20 or 104 — e.g., "CLAUDE.md loads into every agent's context, so keep it under 200 lines (~3K tokens)." Effort: small.
3. Soften Steps 4 and 5 — SKILL.md:79–96 — note that auth/CI sections become `null` in profile.yaml if the project has none, so profilers don't synthesize missing patterns. Effort: small.

## Dead links / broken references
- None. `references/profile-schema.yaml` exists. All 3 `composes_with` targets resolve. `spawned_by: ["orchestrator"]` reciprocal verified.
