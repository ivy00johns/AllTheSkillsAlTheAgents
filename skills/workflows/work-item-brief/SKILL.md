---
name: work-item-brief
version: 1.0.0
description: |
  Produce a durable, agent-ready work-item brief that captures intent precisely enough for an autonomous agent to grab and finish unattended. FORBIDDEN: file paths, line numbers, references to "the file we just edited" — these go stale fast. REQUIRED: behavioral acceptance criteria, named interfaces (types and signatures), explicit out-of-scope list. Pairs with the work-item / Beads model. Use after a grilling session or plan-builder session, before dispatching to an agent. Trigger on: "make a work-item brief", "write the agent brief", "agent-ready ticket", "make this dispatchable", "package this for an agent", "brief this".
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: ["briefs/**/*.md"]
  shared_read: []
allowed-tools: ["Read", "Write", "Grep", "Glob"]
composes_with: ["grill-me", "plan-builder", "contract-author"]
spawned_by: []
---

# Work-Item Brief

Produce a durable, agent-ready brief that an autonomous agent can grab and finish without a human in the loop. The brief is the *context* artifact. The work-item (Beads ID, status, owner, deadline) is the *contract* — it lives elsewhere and updates on a different cadence.

**Announce at start:** "Using work-item-brief to package this for an agent."

## The Forbidden List

Durable briefs MUST NOT contain:

- File paths (`src/billing/cancel.ts`) — files get renamed, moved, deleted
- Line numbers (`line 142`) — code shifts on every commit
- Ephemeral references ("the file we just edited", "the function above", "as discussed")
- Snapshots of code blocks copied from the current tree
- Dates relative to "now" ("yesterday's change", "the recent refactor")

These all go stale fast and turn the brief into a lie. Use **concept-level references** instead: type names, interface names, function signatures, behavior. The agent finds the files by grepping for the names. See `references/brief-format.md` for the canonical template.

## Required Sections

Every brief has exactly these sections, in this order:

1. **Title** — one line, declarative, no ticket prefix
2. **Intent** — 1-2 sentences naming the user problem this solves
3. **Behavioral acceptance criteria** — bulleted; what the system DOES after this lands, observable from outside
4. **Key interfaces** — types and signatures touched, by name only
5. **Out of scope** — explicit list of things this brief does NOT include
6. **AFK/HITL classification** — one of two, declared at the bottom

Missing sections are a defect. An agent reading a brief without out-of-scope will expand scope.

## Key Interfaces Pattern

Name the types and signatures. Do not name files. Example:

```text
Key interfaces:
- `CancellationPolicy` (existing type) — gains a `gracePeriodDays: number` field
- `applyCancellation(subscriptionId, policy): CancellationOutcome` — new function
- `CancellationOutcome` — new sum type: `Refunded | GraceStarted | Denied`
```

The agent runs `grep -r CancellationPolicy` to find the file. The brief stays valid through every rename, restructure, and refactor. **Do not write paths — write names.**

## AFK/HITL Classification

Every brief declares one:

- **AFK-ready** — the agent can finish unattended. Acceptance criteria are objectively verifiable (tests pass, output shape matches, behavior is observable). No design ambiguity.
- **HITL-required** — a human must review at least one decision. Triggered by: design ambiguity, security risk, UX judgment, irreversible data migration, public API shape choices.

If you can't decide, it's HITL-required. The full rubric with worked examples lives in `references/afk-hitl-rubric.md`.

## Out-of-Scope as Concept Files

When a related decision keeps surfacing but doesn't belong in this brief, write a separate concept-level file (e.g., `out-of-scope/refund-window-policy.md`). One concept per file. Future triage uses similarity to surface these when a new ticket touches the same concept. Do not bury concepts inside ticket bodies — they get lost. Pattern in `references/out-of-scope-pattern.md`.

## Process

1. Read the grilling output, plan, or conversation that produced this brief.
2. Draft the six required sections.
3. Strip every path, line number, and ephemeral reference. Replace with type/function names.
4. Classify AFK or HITL. If unsure, HITL.
5. Save to `briefs/<short-slug>.md`.
6. If out-of-scope items have weight, spawn concept files alongside.

## Composition

- After `grill-me` (the user has interrogated the idea) → write the brief.
- After `plan-builder` (a multi-component plan exists) → write one brief per discrete work item.
- Before `contract-author` (interfaces still fuzzy) → the brief seeds the contract; contract-author makes it machine-readable.

## Closing Reminder

**Forbidden, again: no file paths, no line numbers, no "the file we just touched."** The brief outlives the current tree. If the agent needs to find code, it grep's for the type name. This rule is load-bearing — every brief that violates it becomes a stale ticket within a sprint.
