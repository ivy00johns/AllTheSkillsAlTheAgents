---
name: maintain-context
version: 1.0.0
description: "Maintain a project's CONTEXT.md domain glossary and docs/adr/ decision records inline as understanding crystallizes. When the user uses an ambiguous term, propose the canonical form and update CONTEXT.md right there. When a hard-to-reverse decision is made, offer an ADR — but ONLY when all three are true: hard to reverse, surprising without context, real trade-off involved. If any condition is missing, skip. Use this skill after any architectural discussion, requirements clarification, or when shared terminology starts to drift. Trigger on: 'update the glossary', 'add to CONTEXT', 'record this as an ADR', 'what do we call this', 'is this the right term', 'we just decided something', 'document this decision'."
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: ["CONTEXT.md", "docs/adr/**"]
  shared_read: []
allowed_tools: ["Read", "Write", "Edit", "Grep", "Glob"]
composes_with: ["grill-me", "architecture-rescue"]
spawned_by: []
---

# maintain-context

Incrementally maintain two artifacts as conversations happen: `CONTEXT.md` (the project's domain glossary) and `docs/adr/` (decision records). Both compound in value only if you keep them honest, narrow, and rare.

## The three-condition ADR gate

Before writing an ADR, all three must be true. Miss any one and skip — the next ADR will not be a worse decision because this one wasn't recorded.

1. **Hard to reverse.** Rolling back costs real time or money. Schema migrations, public API shapes, vendor lock-in, contractual commitments. Reversible defaults (a flag, a CSS choice, a folder name) don't qualify.
2. **Surprising without context.** A new contributor would not derive this from the code in front of them. They'd reach for the obvious answer and be wrong. If the code self-documents the choice, no ADR.
3. **Real trade-off involved.** There were viable alternatives, and choosing this one closed some doors. If the alternative was nonsense ("we could have not used HTTPS"), there's no decision to record — only a fact.

Why this gate matters: an ADR folder full of routine choices reads like noise, and people stop opening it. Rarity is the whole point. When all three conditions hit, the ADR is worth writing because it captures information that *will* be lost otherwise.

## CONTEXT.md is a glossary

Not a spec. Not a scratchpad. Not implementation notes. Each entry is:

- A term (the canonical name this project uses)
- Its meaning in this project's vocabulary
- An `_Avoid_:` line listing forbidden synonyms — words that mean the same thing in everyday speech but collide with something else here

If the entry isn't disambiguating a term, it doesn't belong in CONTEXT.md. Put it in a README or design doc instead.

## Inline-update pattern

Capture entries the moment a term resolves. Do not batch glossary updates for end-of-session.

> **Forbidden:** Batching glossary updates for end-of-session. Capture them inline as terms are resolved. Batched updates miss context — the reason a term was forbidden gets lost between the conversation and the writeup.

When the user says "let's call them subscribers, not users" — open `CONTEXT.md` right then, write the entry, confirm the `_Avoid_:` list with the user. The five-second update is worth more than a thirty-minute end-of-session pass that has lost half the nuance.

## The `_Avoid_:` alias-list pattern

Every term lists forbidden synonyms with a one-clause reason. The reason is what makes the rule stick.

```markdown
## Subscriber
A customer record with `subscription_status = active`. Has access to paid features.
_Avoid_: user (too generic), member (legacy term from v1), client (means something else in marketing).
```

See `references/context-format.md` for full structure and three worked examples.

## Cross-reference with code

When the user states behavior — "Subscribers get a 30-day trial" — verify against the code before recording it. Use `Grep` for the relevant constant or model field. If the code disagrees, stop and ask which is wrong. Do not record a glossary entry or ADR that contradicts the codebase: one of them is going to be wrong, and the artifact that's supposed to disambiguate will become the thing that confuses people.

## Lazy file creation

Do not create `CONTEXT.md` or `docs/adr/` until there is a real entry to put in them. If they don't exist when this skill triggers, ask once: "Should I create `CONTEXT.md` / `docs/adr/` now?" Get explicit consent. Empty scaffolding signals "this project documents things" when it doesn't yet.

## ADR workflow

When all three gate conditions hit:

1. Propose the ADR out loud: "This looks ADR-worthy — hard to reverse (schema), surprising (we picked event-sourcing over CRUD), real trade-off (loses ad-hoc queryability). Want me to write it?"
2. On yes, draft per `references/adr-format.md` and save to `docs/adr/NNNN-title.md` with the next sequential number.
3. Status starts as `Accepted` if the decision is live; `Proposed` if still under debate.

For uncertain cases, see `references/three-condition-gate.md` — five scenarios walked through with the right call named.

## Compose with

- `grill-me` — surfaces decisions and terminology that should be captured here.
- `architecture-rescue` — when joining an unfamiliar codebase, this skill is where the recovered understanding lands.
