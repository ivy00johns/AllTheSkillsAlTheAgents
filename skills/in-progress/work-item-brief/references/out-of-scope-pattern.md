# Out-of-Scope Pattern

When a related decision keeps surfacing but doesn't belong in the brief at hand, capture it as a **concept-level out-of-scope file** — one concept per file — instead of burying it inside a ticket body.

## Why concept-level files

Concepts buried inside ticket bodies are unreachable:

- Future triage can't find them — nobody greps ticket descriptions
- They die when the ticket closes
- Two tickets touching the same concept produce two divergent paragraphs
- Reviewers re-litigate decisions that were already made

Concept-level files solve all four:

- They live in a stable directory (`out-of-scope/`) with one concept per filename
- They survive ticket closure
- The same concept has exactly one home — updates land in one place
- Future briefs link to the concept file instead of repeating the argument

## Directory layout

```text
briefs/
├── add-grace-period-to-cancellation.md
├── grace-period-email-notifications.md
└── grace-period-ui-surface.md

out-of-scope/
├── refund-window-policy.md
├── plan-tier-cancellation-overrides.md
└── subscription-state-machine.md
```

Briefs reference concepts by name: `See out-of-scope/refund-window-policy.md`.

## File shape

```markdown
# <Concept Name>

## Status
Open question | Deferred decision | Settled with caveats

## Context
<2-3 sentences naming the concept and where it surfaced. Use type names
and behavior — no paths, no line numbers.>

## Why it's out of scope right now
<Why this isn't being decided in the current brief. Cost? Ambiguity?
Cross-team dependency?>

## What we'd need to settle it
<Concrete next step. A decision-maker, a doc, a spike, a survey.>

## Briefs that have touched this
- <brief slug>
- <brief slug>
```

Keep these short — under 30 lines. If a concept needs more than that, it deserves its own brief.

## Triage by similarity

When a new brief is drafted, the triage step is:

1. Extract the type names and concept words from the new brief's `Out of scope` section.
2. Search `out-of-scope/` for matching concept files (by name, by type reference, by topic).
3. If a match exists: link to it from the new brief.
4. If no match exists but the concept feels like it'll resurface: write a new concept file.
5. If a concept file's "Briefs that have touched this" list grows past 3, the concept is a recurring blocker — promote it to a real brief and resolve it.

Similarity is not magic. It's grep. The agent or human running triage greps `out-of-scope/` for terms from the new brief. Names matter — name concept files after the *concept*, not after the *brief that spawned them*.

## Anti-pattern

A 400-line ticket body with three nested "by the way" sections, each containing a half-argument about an adjacent concern. The author thinks they've documented it. Nobody can find it three months later. Every adjacent ticket re-argues the same point because no one knows the prior argument exists.

**Pull adjacent concerns out into named concept files.** The brief stays short. The concept survives.
