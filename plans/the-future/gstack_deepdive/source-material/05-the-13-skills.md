# 05 — The 13 Skills

## Skill Map

```
PLANNING                          IMPLEMENTATION
┌─────────────────────┐           ┌──────────────────┐
│ /plan-ceo-review    │           │ /review          │
│ /plan-eng-review    │     →     │ /ship            │
│ /plan-design-review │           └──────────────────┘
└─────────────────────┘
                                  QA
         ┌────────────────────────┐
         │ /qa          (fix)     │
         │ /qa-only     (report)  │
         │ /qa-design-review (fix)│
         └────────────────────────┘

SUPPORT
┌────────────────────────────────────┐
│ /retro  /document-release          │
│ /setup-browser-cookies             │
│ /gstack-upgrade                    │
└────────────────────────────────────┘
```

## Planning Phase

### `/plan-ceo-review` — Founder/CEO Mode
**Role:** Strategic product review from a founder's perspective.
**Patterns:** 14 cognitive patterns (Bezos, Grove, Munger, Horowitz, etc.)
**4 Modes:** Scope Expansion → Selective Expansion → Hold Scope → Scope Reduction
**Output:** Strategic recommendations, expansion visions, scope decisions
**Persistence:** Visions saved to `~/.gstack/projects/{slug}/ceo-plans/`
**Exceptional visions** promoted to `docs/designs/` in the repo

### `/plan-eng-review` — Engineering Manager Mode
**Role:** Architecture, risk, and implementation review.
**Patterns:** 15 cognitive patterns (McKinley, Brooks, Beck, Majors, etc.)
**Output:**
- ASCII architecture diagrams (forces deeper thinking than Mermaid)
- Data flow diagrams
- State machines
- Edge case analysis
- Test matrices
**Format:** Interactive walkthrough — 4 sections × 1 issue per AskUserQuestion
**Gate:** Required for `/ship` (can be overridden)

### `/plan-design-review` — Senior Designer Mode
**Role:** Visual and UX design audit. Report-only, never touches code.
**Patterns:** 12 cognitive patterns (Rams, Norman, Zhuo, Gebbia, Ive, etc.)
**Output:** 80-item design audit across 10 categories
**AI Slop Detection:** 10 specific patterns (purple gradients, 3-column grids,
centered everything, uniform border-radius, generic hero copy)
**Design System Inference:** Extracts fonts, colors, heading scale, spacing from live site
**DESIGN.md Export:** Offers to save inferred design system as `DESIGN.md`

## Implementation Phase

### `/review` — Staff Engineer Finding Production Bugs
**Role:** Code review focused on production safety.
**Two-Pass Review:**
1. **CRITICAL:** SQL injection, race conditions, LLM trust boundary violations,
   enum completeness (traces new values through ALL switch statements)
2. **INFORMATIONAL:** Side effects, dead code, test gaps, stale comments

**Fix-First Heuristic:**
- Mechanical fixes auto-applied (dead code, N+1 queries, stale comments, missing indices)
- Design decisions surfaced for user judgment
- Reduces decision fatigue — AI doesn't ask "should I fix this obvious thing?"

**Enum Completeness:** Reads code OUTSIDE the diff — traces new enum values through
every switch/case statement that handles them. This is the kind of bug that only
appears in production, weeks after the PR.

**Lite Design Review:** Detects 7 anti-patterns in changed frontend code:
blacklisted fonts, `outline: none`, `!important` abuse, body text <16px, etc.

**Greptile Integration:** Fetches Greptile bot comments, classifies them
(VALID, ALREADY FIXED, FALSE POSITIVE, SUPPRESSED), escalates repeated issues.

### `/ship` — Release Engineer (Fully Automated)
**Role:** Complete release workflow from branch to PR.
**Steps (sequential, no confirmation needed):**
1. Pre-flight: branch check, review readiness dashboard, uncommitted changes
2. Merge base branch before tests
3. Test framework bootstrap (detects no tests → installs framework → writes 3–5 real tests)
4. Run tests (parallel)
5. Eval suites (mandatory on prompt file changes)
6. Lite design review (if frontend files touched)
7. Test coverage audit (builds code path map, ASCII coverage diagram with ★★★/★★/★ quality)
8. Auto-detect version bump (MICRO vs PATCH, asks on MINOR/MAJOR)
9. Auto-generate CHANGELOG from diff
10. TODOS.md management (auto-detects completed items, marks with version)
11. Atomic commits (bisectable, one logical change per commit)
12. Git push + PR creation
13. PR body (tests, coverage, design review results)

**Philosophy:** User said `/ship`. DO IT. No confirmation dialogs.

## QA Phase

### `/qa` — QA Lead with Find-Fix-Verify Cycle
**Role:** Find bugs in the running app, fix them in source code, verify the fix.
**6-Phase Methodology:**
1. Initialize (detect stack, find browse binary)
2. Authenticate (if needed, via cookie import)
3. Orient (read codebase, understand routes/pages)
4. Explore (systematic testing with evidence)
5. Document (categorize findings)
6. Wrap up (health score, summary)

**Three Tiers:** Quick (critical/high), Standard (+ medium), Exhaustive (+ cosmetic)
**Diff-Aware:** On feature branches, auto-detects changed routes/pages
**Find-Fix-Verify:** Bug found → fix in source → commit → screenshot evidence → verify
**Health Score:** 0–100, weighted across 7 categories

### `/qa-only` — QA Reporter (Report-Only)
Same 6-phase methodology as `/qa` but never touches code. Pure reporting.

### `/qa-design-review` — Designer Who Codes
Same 80-item design audit as `/plan-design-review`, but then FIXES issues:
- CSS-safe fixes applied
- Atomic commits with before/after screenshots
- Stricter self-regulation heuristic for styling changes

## Support Phase

### `/retro` — Weekly Engineering Retrospective
**Per-Person Breakdowns:** Identifies "you" (via `git config user.name`) vs teammates
**Metrics:**
- Commit counts, LOC added/deleted, test ratio
- Hotspot analysis (most-changed files)
- Shipping streaks and velocity trends
- Test health (ratio tracking, regression tests generated)
- TODOS.md backlog analysis
**Comparison:** Current window vs prior same-length window

### `/document-release` — Technical Writer
**Role:** Auto-update all project docs after a release.
- Reads diff, cross-references README, ARCHITECTURE, CONTRIBUTING, CHANGELOG, TODOS.md
- Obvious updates applied automatically
- Risky changes surfaced as questions

### `/setup-browser-cookies` — Session Manager
**Role:** Import real browser cookies for authenticated QA.
- Decrypts cookies from Chrome/Arc/Brave/Edge via macOS Keychain
- Interactive picker UI or command-line direct import

### `/gstack-upgrade` — Self-Updater
- 12-hour cache TTL on "up to date" (60 min production), 720 min on "upgrade available"
- Exponential snooze backoff: 24h → 48h → 1 week
- Detects stale vendored copies in projects + syncs them
- Auto-upgrade mode: `auto_upgrade: true` in config

## Skill Interactions

```
/plan-ceo-review ──┐
/plan-eng-review ──┤── Review Readiness Dashboard ──→ /ship (pre-flight gate)
/plan-design-review┘

/plan-eng-review ──→ test plan artifact ──→ /qa (primary input)
/plan-design-review ──→ inferred design system ──→ /qa-design-review (calibration)

/review ──→ checklist.md ←── /ship (shared review standards)
/ship ──→ CHANGELOG.md ←── /document-release (cross-reference)
```

Every review persists to `~/.gstack/projects/{slug}/{branch}-reviews.jsonl`.
This forms a durable knowledge graph of what's been reviewed, by whom, with what result.
