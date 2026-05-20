# Audit: nano-banana

**Path:** skills/workflows/nano-banana/SKILL.md
**Version:** 1.2.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | Required fields all present; semver 1.2.0; canonical hyphenated `allowed-tools`; no `<`/`>` in field values; `composes_with` targets (`frontend-agent`, `docs-agent`) both exist. |
| Description quality | 4 | 615 chars — under 1024 ceiling but ~3× the 200-char target. Action verb "Generate"; multiple trigger phrases (8+); catch-all clause ("even if they just say 'let's do images'"). Could trim trigger-verb redundancy. |
| Progressive disclosure | 4 | Body 135 lines / well under 5000 words. Two references both linked with explicit "when to read" guidance (lines 134–135). Body is slightly long because it embeds prompt examples and full CLI parameter table — those could move to a reference. |
| Instruction clarity | 5 | Strong imperative voice; numbered 4-step workflow (Step 1–Step 4); concrete CLI invocation with `find -L` to locate the bundled script across symlink layouts (lines 67–69). |
| Coordination | 5 | Empty `owns.directories/patterns` (stateless image generator); `composes_with` lists frontend-agent + docs-agent which both exist; no ownership conflicts. |
| Completeness | 5 | Both reference files exist; the bundled `scripts/generate_image.py` exists and is the operative tool; CLI parameters documented; error handling covered (line 99–107). |
| Anti-patterns | 5 | No emojis; one hardcoded URL (https://aistudio.google.com/apikey) which is correct since that's the actual signup page; one `> **Note:**` block (line 35) but it's documenting future-tier behavior with rationale. |

**Average:** 4.71

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Body line 47 says "reads from the Skill Madness root `.env` file automatically" — this is a hardcoded assumption about the **host project** that contradicts repo CLAUDE.md guidance ("Skills should describe work in terms of capabilities … so the same skill body works across hosts"). If a user installs this skill into another project, "Skill Madness root" is meaningless. — SKILL.md:47 — proposed fix: rephrase to "reads from the current project's repo-root `.env` file" or document the lookup chain (CWD `.env`, then `~/.env`, then explicit `GEMINI_API_KEY` env).

### Nits (won't block ship)
- Aspect-ratio list at lines 38–43 splits four "preferred" ratios into bullets then dumps the rest into a one-line comma list — inconsistent presentation. Either bullet all or table-ify the lot. — SKILL.md:38–43
- "Bundled script uses `gemini-2.5-flash-image`" but the CLI section (line 78) shows `--model standard` — slight mismatch between narrative and example. Worth clarifying that `standard` is the internal alias for `gemini-2.5-flash-image`.
- `compatibility` field absent; skill requires Bash + a network-reachable Gemini API + Python 3 — worth declaring for cross-platform parsers.
- Reference file `imagen-4-prompting.md` is about **Imagen 4** but the skill is about **Nano Banana** (gemini-2.5-flash-image). The prompting techniques may transfer, but the naming is confusing. SKILL.md line 134 acknowledges the gap ("the model behind Nano Banana") — verify the relationship is accurate or rename the reference.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Remove the hardcoded "Skill Madness root" reference — SKILL.md:47 — replace with "reads from the current project's `.env` file" so the skill works when installed into any consumer project. Effort: small.
2. Add `compatibility` field — SKILL.md:13 — declare "Claude Code; requires Bash, Python 3, and a `GEMINI_API_KEY` environment variable." Effort: small.
3. Trim description from 615 → ~300 chars — SKILL.md:4–10 — remove the comma-separated alternate trigger phrases (already covered by the catch-all clause); keep one strong action verb + 3 anchor phrases + the Nano Banana keyword. Effort: small.

## Dead links / broken references
- None. Both `references/*.md` files exist. `scripts/generate_image.py` exists. `composes_with` targets resolve.
- External URL `https://aistudio.google.com/apikey` is a real Google AI Studio page — appropriate context.
