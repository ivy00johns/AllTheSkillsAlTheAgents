# Brief Format

The canonical section-by-section template for a work-item brief, with a fully-fleshed-out example.

## Template

```markdown
# <Title — one declarative line>

## Intent
<1-2 sentences naming the user problem this solves. Not the implementation
strategy. Not "refactor X." The actual user-visible outcome.>

## Behavioral acceptance criteria
- <Observable behavior #1 after this lands>
- <Observable behavior #2>
- <Negative criterion: what should NOT happen / regress>
- <Edge case behavior that is easy to forget>

## Key interfaces
- `<TypeName>` (existing | new) — <what changes, by name>
- `<functionSignature(args): ReturnType>` — <new | modified | removed>
- `<EventName>` — <emitted when, payload shape by name>

## Out of scope
- <Adjacent concern that is NOT included>
- <Adjacent concern that is NOT included>
- See `out-of-scope/<concept>.md` for related decisions captured separately.

## Classification
**AFK-ready** | **HITL-required**

Reason: <one sentence — what makes it unattended-safe, or what decision
needs a human.>
```

## Forbidden

Do not include in any section:

- File paths
- Line numbers
- "The file we just edited" / "the function above"
- Code blocks copied from the current tree
- Relative dates ("yesterday's commit")

If a section feels like it needs a path, the section is wrong — name the type or function instead.

## Example: Subscription cancellation with grace period

```markdown
# Add grace period to subscription cancellation

## Intent
Customers who cancel mid-billing-cycle currently lose access immediately
and feel cheated. Give them a configurable grace period so paid time
remains usable, reducing churn-driven support tickets.

## Behavioral acceptance criteria
- Cancelling an active subscription with a non-zero grace period keeps
  the subscription in a "grace" state until grace expiry.
- During grace, the customer retains all paid features.
- At grace expiry, the subscription transitions to "cancelled" and
  access is revoked on the next access check.
- A grace period of zero days behaves identically to today's immediate
  cancellation — no behavior change for legacy plans.
- Cancelling an already-cancelled subscription is a no-op (idempotent).
- Refund eligibility is unaffected by grace state — refunds still apply
  to the original payment.

## Key interfaces
- `CancellationPolicy` (existing type) — gains `gracePeriodDays: number`
  with default `0` for backward compatibility.
- `applyCancellation(subscriptionId, policy): CancellationOutcome` — new
  function; the single entry point for cancellation flows.
- `CancellationOutcome` — new sum type: `Refunded | GraceStarted | Denied`.
- `SubscriptionStatus` (existing enum) — gains `"grace"` variant.
- `isAccessAllowed(subscription, now): boolean` — existing predicate;
  must treat `"grace"` as allowed.

## Out of scope
- UI surface for displaying grace state to the customer (separate brief).
- Email notification at grace start and grace expiry (separate brief).
- Configurable grace per plan tier — this brief uses a single global default.
- See `out-of-scope/refund-window-policy.md` — interaction between grace
  and refund window has surfaced repeatedly; captured separately.

## Classification
**AFK-ready**

Reason: All acceptance criteria are observable via the public function
surface and existing test patterns. No UX judgment required. Default
`gracePeriodDays: 0` preserves legacy behavior, so rollout risk is bounded.
```

## Anti-pattern (what NOT to do)

```markdown
## Acceptance criteria
- Edit `src/billing/cancel.ts` line 47 to add the grace period field
- Update the function we discussed yesterday
- Make sure tests in `tests/cancel.test.ts` pass

## Implementation notes
- The current code at `src/billing/policy.ts:103` already does most of this
- Just add a field, it's easy
```

Every reference here breaks within a sprint. The file gets renamed. Line 47 becomes line 89. "The function we discussed" is forgotten. The brief becomes a stale ticket nobody can action. **Use type names. Always.**
