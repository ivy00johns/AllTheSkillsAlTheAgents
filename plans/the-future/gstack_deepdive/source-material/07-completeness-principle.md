# 07 — The Completeness Principle ("Boil the Lake")

## The Insight

AI-assisted coding compresses implementation time 10–100x. This changes the
calculus on shortcuts vs completeness.

**Before AI:** "We could do 100% test coverage, but that's 3 weeks of work.
Let's cover the critical paths and ship." Rational.

**After AI:** "We could do 100% test coverage in 30 minutes. The shortcut
saves 15 minutes. Ship the complete version." Also rational.

The delta between 80 lines and 150 lines is meaningless with Claude Code.
The delta between 80% coverage and 100% coverage is a production incident.

## Lake vs Ocean

Not everything should be boiled. The distinction:

**Lake** = Boilable (do it):
- 100% test coverage for a module
- Full feature implementation with all edge cases
- Complete error handling
- All enum variants handled
- Every validation rule enforced

**Ocean** = Not boilable (don't attempt):
- Rewriting the entire codebase in a new language
- Multi-quarter migration projects
- Redesigning a distributed system from scratch
- Replacing a fundamental dependency

## How It's Embodied

### In AskUserQuestion
Every question Claude asks shows a completeness score (1–10):
- "This covers 7/10 cases. The complete version covers 10/10 and takes
  15 more minutes of CC time. Recommend: complete version."

### In Effort Estimates
Always show both human-team time AND CC+gstack time:
```
Human team: 2 days | CC+gstack: 15 min | Compression: ~100x
Recommendation: Complete version (lake, not ocean)
```

### In `/ship`
Flags shortcut implementations where the complete version costs <30 min CC time:
"This error handler covers 3 of 5 cases. Complete version: 15 min.
Recommendation: boil the lake."

### In `/review`
Calls out incomplete error paths:
"This switch statement handles 4 of 6 enum values. The missing values
will cause a runtime panic in production. Lake: add them now (5 min CC)."

### In Scope Decisions
When `/plan-ceo-review` presents options:
- Option A: Full implementation (30 min CC, covers all edge cases)
- Option B: MVP (15 min CC, covers happy path)
- "Option A is a lake. Option B saves 15 minutes but creates tech debt.
  Recommendation: A."

## The Anti-Pattern: Premature Shortcuts

Before AI, shortcuts were rational time management. After AI, shortcuts are
**premature optimization of human time at the cost of code quality**.

The old calculus:
```
Complete version: 3 weeks → ship MVP, iterate later
```

The new calculus:
```
Complete version: 30 minutes → just do it, there is no "later"
```

## Why This Changes Everything

1. **Tech debt is optional.** If complete implementation costs 30 min,
   choosing the shortcut is choosing debt for no reason.

2. **"Good enough" is no longer an excuse.** When "great" costs the same
   as "good enough," settling is a choice, not a constraint.

3. **Edge cases are cheap.** The time to handle them is now, when context
   is fresh, not later when you've forgotten the invariants.

4. **Test coverage is free.** Writing tests for 5 more edge cases costs
   15 minutes of CC time. Not writing them costs a production incident.

5. **Documentation is free.** Generating comprehensive docs costs 10 minutes.
   Not generating them costs onboarding time for every future contributor.

## The Caveat

This only works when you have a reliable AI coding assistant. gstack's
compression ratios are measured with Claude Code + gstack skills. Without
the quality layer (reviews, QA, design audit), raw AI coding speed creates
bugs faster, not fewer.

Completeness without quality = more bugs, faster.
Completeness with quality = production-grade code, fast.
