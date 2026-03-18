# 03 — The Skill System

## The Problem

SKILL.md documentation drifts from code. When a browse command changes or a
snapshot flag is added, the skill docs don't auto-update. Agents hit errors.
Manual synchronization doesn't scale across 13 skills.

## Solution: Template-First Generation

```
SKILL.md.tmpl (human prose + {{PLACEHOLDERS}})
    ↓
gen-skill-docs.ts (reads source code metadata)
    ↓
SKILL.md (committed, auto-generated sections)
```

### The Pipeline

1. **Author** edits `.tmpl` file (natural language + Bash blocks + placeholders)
2. **Generator** (`scripts/gen-skill-docs.ts`) reads source code metadata arrays
3. **Output** is a complete SKILL.md with auto-generated sections
4. **Both files committed** — `.tmpl` is source of truth, `.md` is artifact
5. **CI validates** freshness: `gen:skill-docs --dry-run` + `git diff --exit-code`

### Why committed, not generated at runtime?

- Claude reads SKILL.md at skill load time — must pre-exist
- CI can validate freshness
- Git blame shows when commands were added
- No build step required for consumers

## Placeholders (Single Source of Truth)

| Placeholder | Source | Generated Content |
|-------------|--------|-------------------|
| `{{COMMAND_REFERENCE}}` | `browse/src/commands.ts` | Categorized command table with descriptions |
| `{{SNAPSHOT_FLAGS}}` | `browse/src/snapshot.ts` (SNAPSHOT_FLAGS array) | Flag reference with examples |
| `{{PREAMBLE}}` | gen-skill-docs.ts | Startup: update check, session tracking, contributor mode, AskUserQuestion format |
| `{{BROWSE_SETUP}}` | gen-skill-docs.ts | Binary discovery + setup instructions |
| `{{BASE_BRANCH_DETECT}}` | gen-skill-docs.ts | Dynamic base branch detection (main/master/develop) |
| `{{QA_METHODOLOGY}}` | gen-skill-docs.ts | Shared 6-phase QA approach (used by /qa and /qa-only) |
| `{{DESIGN_METHODOLOGY}}` | gen-skill-docs.ts | 80-item design audit (used by /plan-design-review and /qa-design-review) |
| `{{REVIEW_DASHBOARD}}` | gen-skill-docs.ts | Review Readiness Dashboard reader |
| `{{TEST_BOOTSTRAP}}` | gen-skill-docs.ts | Framework detection + CI/CD setup |
| `{{DESIGN_REVIEW_LITE}}` | gen-skill-docs.ts | 7-item code-level design review for /review |

## DRY Across Skills

The placeholder system solves duplication across skills:

- `{{QA_METHODOLOGY}}` → fills into both `/qa` and `/qa-only`
- `{{DESIGN_METHODOLOGY}}` → fills into both `/plan-design-review` and `/qa-design-review`
- `{{PREAMBLE}}` → fills into all 13 skills
- `{{BROWSE_SETUP}}` → fills into all skills that use the browser

One change to methodology = all skills updated on next `bun run gen:skill-docs`.

## Template Authoring Rules

SKILL.md.tmpl files are **prompt templates read by Claude**, not bash scripts.
Each bash code block runs in a separate shell — variables don't persist between blocks.

1. **Use natural language for logic and state.** Don't use shell variables to pass
   state between code blocks. Tell Claude what to remember in prose.
2. **Don't hardcode branch names.** Detect main/master/develop dynamically.
   Use `{{BASE_BRANCH_DETECT}}` for PR-targeting skills.
3. **Keep bash blocks self-contained.** Each block works independently.
4. **Express conditionals as English.** "1. If X, do Y. 2. Otherwise, do Z."

## Validation (3-Tier)

### Tier 1: Static (Free, <5s)
Parse every `$B` command in SKILL.md, validate against the command registry
and snapshot flags. Runs on every `bun test`. Catches typos, removed commands,
invalid flag combinations.

### Tier 2: E2E (~$3.85/run)
Spawn a real Claude session via `claude -p`, run the skill, scan output for
browse errors, tool failures, and unexpected behavior. Gated by `EVALS=1`.

### Tier 3: LLM-as-Judge (~$0.15/run)
Sonnet evaluates Haiku's responses on planted-bug fixtures for clarity,
completeness, and actionability. Uses structured rubrics with pass/fail.

## Health Dashboard

`bun run skill:check` shows a dashboard of all skills:
- Template freshness (stale = `.tmpl` newer than `.md`)
- Command validity (all `$B` commands exist in registry)
- Placeholder coverage (no raw `{{...}}` in output)
- Line count and complexity metrics

## Watch Mode

`bun run dev:skill` watches `.tmpl` files and auto-regenerates + validates
on every change. Enables rapid skill iteration with immediate feedback.

## Why This Matters

Most AI skill systems are static Markdown files that drift from reality.
gstack's template system is the only one where:
1. Command references are guaranteed accurate (sourced from code)
2. Methodology is DRY across skills (one edit, all updated)
3. Validation catches broken skills before they reach users
4. The generator itself is a pure function (testable, importable)
