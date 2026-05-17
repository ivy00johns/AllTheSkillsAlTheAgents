# AFK / HITL Rubric

Every brief declares one classification. This document tells you which.

## The deciding factor

**A brief is AFK-ready if and only if every acceptance criterion is objectively verifiable without a human judgment call.**

If even one criterion requires taste, judgment, or "does this feel right" — the brief is HITL-required. There is no middle ground. "Mostly AFK" doesn't exist; the human review either happens or it doesn't.

## AFK-ready means

- Acceptance criteria are observable from outside the code (return values, status codes, persisted state, emitted events, test outcomes)
- All design decisions are settled in the brief or in linked concept files
- No security-sensitive surface is changing without an established pattern
- Rollback is bounded — the change can be reverted without manual data repair
- No public API shape is being chosen for the first time

## HITL-required means at least one of

- A design decision is open (two reasonable shapes; the brief doesn't pick)
- A security or privacy surface is changing (auth, permissions, PII handling, secrets)
- UX judgment is needed (copy, layout, interaction feel)
- The change is irreversible without restore (destructive migration, dropped column, deleted records)
- A new public API shape is being introduced (external consumers will lock in to it)
- Acceptance criteria contain the words "appropriate", "reasonable", "good", or "clean"

## Worked scenarios

### Scenario 1: AFK-ready

> Add a `gracePeriodDays` field to `CancellationPolicy` with default `0`. `applyCancellation` returns `GraceStarted` instead of `Refunded` when the policy has a non-zero grace period. Existing tests must pass unchanged. Add tests for grace expiry and idempotent re-cancellation.

**Why AFK:** Default of `0` means legacy behavior is bit-for-bit preserved. New behavior is fully describable as state transitions on named types. Tests pin everything down. No UX, no security, no irreversible move.

### Scenario 2: AFK-ready

> Implement `isAccessAllowed(subscription, now)` to return `true` when `subscription.status` is `"active"` or `"grace"`, `false` otherwise. Function must be pure. Add a property test asserting it never throws on any valid `Subscription` shape.

**Why AFK:** Pure function. Observable behavior. Property test gives objective verification. Zero ambiguity.

### Scenario 3: HITL-required

> Add an "Are you sure?" confirmation step before subscription cancellation. The flow should feel appropriate for high-value customers and not annoying for free-tier customers.

**Why HITL:** "Feel appropriate" and "not annoying" are taste judgments. Even if the brief specifies modal vs. inline vs. email-confirm, the choice is UX judgment. The deciding factor: acceptance criteria contain `appropriate` and `annoying` — both judgment words.

### Scenario 4: HITL-required

> Drop the `legacy_refund_eligible` column from the `subscriptions` table. All consumers have been migrated.

**Why HITL:** Irreversible destructive migration. "All consumers have been migrated" is a claim a human should verify before the agent runs the DDL. The deciding factor: rollback is unbounded — once the column is dropped, restoring it requires backups and a re-migration. A human signs off; the agent doesn't.

## When in doubt

Mark it HITL-required. The cost of an unnecessary human review is one ping. The cost of an unattended agent making the wrong judgment call is hours of cleanup. The asymmetry favors HITL on every uncertain case.
