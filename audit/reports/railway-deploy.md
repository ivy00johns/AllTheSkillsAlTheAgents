# Audit: railway-deploy

**Path:** skills/workflows/railway-deploy/SKILL.md
**Version:** 1.2.0
**Category:** workflows
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields; semver 1.2.0; canonical hyphenated `allowed-tools`; description uses YAML `>` block scalar (structural marker, not a forbidden value char); `composes_with` targets (infrastructure-agent, deployment-checklist) both resolve; `owns.patterns: ["railway.toml"]` non-conflicting. |
| Description quality | 4 | 586 chars — under 1024 ceiling, ~3× target. Action verb "Deploy"; 6 explicit trigger phrases ("deploy", "Railway", "push to production", "ship it", "put this online", "deploy to staging"); covers both CLI and API paths. Trimmable. |
| Progressive disclosure | 4 | Body 92 lines / well under 5000 words. Three references all linked (lines 90–92). However, references 1 and 3 are heavily depended on — the body says "see X" five times for `dockerfile-recipes.md` alone (lines 72, 74, 76, 78, 80, 82). Reasonable delegation but the body itself contains very few actionable specifics. |
| Instruction clarity | 4 | Imperative voice; numbered 6-step setup process; two clearly-named deployment approaches (CLI vs GraphQL). Minor ambiguity: Step 6 "Optional: Procfile fallback" is bullet-listed at the same level as required steps — could trip an LLM into treating it as required. |
| Coordination | 5 | Pattern ownership of `railway.toml` is appropriate and non-conflicting; `composes_with` accurate (infrastructure-agent owns Dockerfile, this skill writes railway.toml + composes with infra for the Dockerfile). |
| Completeness | 5 | All three referenced files exist and are substantively sized (49–159 lines each). External URLs (https://railway.app/account/tokens) are real. |
| Anti-patterns | 2 | **Hardcoded project assumption** at line 33: "Railway credentials … go in the Skill Madness root `.env` file" — this is the same portability anti-pattern flagged in `nano-banana`. A user installing this skill into any other project hits a dead reference. The skill is otherwise clean. |

**Average:** 4.14

## Findings

### Critical (must fix to ship)
- Hardcoded reference to "Skill Madness root `.env` file" at SKILL.md:33. Skill should not assume the consumer project is Skill Madness. — SKILL.md:33 — proposed fix: rephrase to "the current project's repo-root `.env` file (see `.env.example`)" or document the lookup order (repo `.env`, then `$HOME/.env`, then shell env).

### Important (should fix)
- Description is 586 chars; trimmable to ~300. Trigger phrases "deploy", "Railway", "push to production", "ship it", "put this online" all overlap. — SKILL.md:5–10 — proposed fix: keep "Deploy projects to Railway" + 3 distinctive triggers (Railway-specific terms) + the "go-to skill" closing.
- Step 6 "Optional: Procfile fallback" is listed under "Setting Up a New Project" (line 82) as if it's a step. Mark it as optional outside the numbered list to avoid LLMs treating it as mandatory. — SKILL.md:82

### Nits (won't block ship)
- `compatibility` field absent; skill requires Bash + `railway` CLI + Docker — declaring this would help portability. — SKILL.md:13
- The body says "see `references/dockerfile-recipes.md`" five times in steps 2–6 (lines 72, 74, 76, 78, 80, 82). Once at the top of the section with "Steps 2–6 all draw from `references/dockerfile-recipes.md` for templates" would scan better.
- "v4.x+" version requirement for Railway CLI at line 38 — no rationale; if it matters, a one-line note (e.g., "v4 added the GraphQL API endpoints we depend on") would help.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Replace "Skill Madness root `.env`" with project-agnostic language — SKILL.md:33 — change to "the current project's repo-root `.env` file" so the skill works when installed into any consumer project. Effort: small.
2. Trim description from 586 → ~300 chars — SKILL.md:5–10 — collapse overlapping trigger phrases; keep "deploy", "Railway", "ship it" + Railway-specific operations. Effort: small.
3. Move "Optional: Procfile fallback" out of the numbered setup steps — SKILL.md:82 — make it a separate paragraph after step 5 or move to references. Effort: small.

## Dead links / broken references
- None in-repo. All three reference files exist. Both `composes_with` targets resolve. External URLs (railway.app) are real.
- The hardcoded `Skill Madness root .env` reference (line 33) is not a broken link — but it is a portability bug for cross-repo installs.
