# 09 — Review Readiness Dashboard

## The Problem

You do 3 reviews (CEO, Eng, Design) across multiple sessions. When you run
`/ship`, it needs to know: did all reviews pass? Which ones are pending?
Which had issues that were never resolved?

Without persistence, every `/ship` run starts from zero — re-reviewing
everything or skipping reviews entirely.

## The Dashboard

### How It Works

Every review skill writes its result to disk:
```
~/.gstack/projects/{slug}/{branch}-reviews.jsonl
```

Each line is a review record:
```jsonl
{"type": "ceo", "status": "CLEAR", "mode": "HOLD_SCOPE", "timestamp": "...", "issues": 0}
{"type": "eng", "status": "CLEAR", "timestamp": "...", "issues": 2, "resolved": 2}
{"type": "design", "status": "PENDING", "timestamp": "...", "issues": 5, "resolved": 3}
```

### Status Values
- **CLEAR** — Review passed, no blocking issues
- **PENDING** — Review completed but has unresolved issues
- **FAILED** — Review found blocking problems

### Gate Behavior in `/ship`

During pre-flight, `/ship` reads the dashboard:

```
Review Readiness Dashboard
─────────────────────────
CEO Review:    CLEAR (Hold Scope mode, 2026-03-15)
Eng Review:    CLEAR (2 issues, all resolved, 2026-03-16)
Design Review: PENDING (5 issues, 3 resolved, 2026-03-14)
─────────────────────────
```

**Gate rules:**
- Eng Review is **required** (can be disabled in config)
- CEO Review is **informational** (shown but doesn't block)
- Design Review is **informational** (shown but doesn't block)

If Eng Review is missing or FAILED, `/ship` asks:
"Eng review not found for this branch. Run `/plan-eng-review` first,
or override with 'ship without eng review'?"

### Override Persistence

If the user overrides a gate, the override is recorded:
```jsonl
{"type": "eng", "status": "OVERRIDDEN", "reason": "user override", "timestamp": "..."}
```

Future `/ship` runs on the same branch skip the gate — the user already decided.

## Branch-Level Scoping

All dashboard data is scoped to the current branch:
- `main-reviews.jsonl` — reviews for main
- `feature/auth-reviews.jsonl` — reviews for feature/auth

When you switch branches, the dashboard resets. Each branch has its own
review history. This prevents stale review data from blocking unrelated work.

## Decision Tracking

The dashboard also tracks key decisions made during reviews:

```jsonl
{"type": "decision", "review": "ceo", "decision": "Hold scope — no expansion", "timestamp": "..."}
{"type": "decision", "review": "eng", "decision": "Use SQLite not Postgres for MVP", "timestamp": "..."}
{"type": "decision", "review": "design", "decision": "Keep current color system, fix spacing only", "timestamp": "..."}
```

This creates an audit trail: why was this architecture chosen? What did the
CEO review recommend? What design tradeoffs were made?

## Cross-Skill References

The dashboard is read by multiple skills:
- `/ship` — pre-flight gate check
- `/review` — shows which reviews informed the current review
- `/qa` — inherits test plan from eng review

And written by:
- `/plan-ceo-review`
- `/plan-eng-review`
- `/plan-design-review`
- `/qa-design-review` (updates design review status)

## Storage Location

```
~/.gstack/
├── config.yaml              # Global config
└── projects/
    └── {owner}-{repo}/
        ├── {branch}-reviews.jsonl    # Review dashboard
        ├── {branch}-design.jsonl     # Design regression data
        └── ceo-plans/
            └── {slug}.md             # CEO expansion visions
```

## Why This Matters

1. **Reviews persist across sessions** — do them once, skip on re-runs
2. **Gate system prevents shipping without review** — with escape hatch
3. **Decision audit trail** — why was this approach chosen?
4. **Branch scoping** — each branch has independent review state
5. **Override tracking** — user decisions are respected and recorded
6. **Cross-skill composition** — reviews inform downstream workflows
