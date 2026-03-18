# Future Stack Synthesis — Index

This document set synthesizes the three deep dives already captured in
`plans/gstack/source-material/`, `plans/gastown/source-material/`, and
`plans/beads/source-material/`.

The goal is not to restate those files. The goal is to answer the next-order
questions:

- What each system actually is
- Which layer each system owns
- Where they connect cleanly
- Where they do not connect yet
- Which gaps still block a fully orchestrated future stack
- What to build on top, around, or between them

## Core thesis

The three repos are not competitors:

- `gstack` is the quality and perception layer
- `gastown` is the fleet control layer
- `beads` is the durable work graph and memory layer

None of them, alone, is the future platform.
The future platform is the thin orchestration, policy, contract, and evidence
layer that makes the three behave like one system.

## Documents

| # | File | Purpose |
|---|------|---------|
| 01 | [01-system-atlas.md](01-system-atlas.md) | What each repo is, what it is not, and how to think about the stack |
| 02 | [02-four-phase-model.md](02-four-phase-model.md) | The four phases of a complete agentic software factory and how coverage maps today |
| 03 | [03-integration-topology.md](03-integration-topology.md) | Where the repos connect natively, where adapters are required, and where boundaries are hard |
| 04 | [04-gap-catalog.md](04-gap-catalog.md) | The missing capabilities no single repo currently provides |
| 05 | [05-reference-architecture.md](05-reference-architecture.md) | The proposed future-state platform architecture |
| 06 | [06-build-vs-wrap-decisions.md](06-build-vs-wrap-decisions.md) | What to keep upstream, what to wrap, what to extract, and what not to rebuild |
| 07 | [07-program-roadmap.md](07-program-roadmap.md) | A phased program for building the future stack without getting trapped in a monolith |
| 08 | [08-open-questions.md](08-open-questions.md) | The unresolved product, architecture, and operating model questions |
| 09 | [09-repo-reading-map.md](09-repo-reading-map.md) | The exact files to study first in each repo by build goal |

## Recommended reading order

1. Read `01-system-atlas.md`
2. Read `02-four-phase-model.md`
3. Read `03-integration-topology.md`
4. Read `04-gap-catalog.md`
5. Read `05-reference-architecture.md`
6. Use `06-build-vs-wrap-decisions.md` and `07-program-roadmap.md` to decide what to build next

## Source foundations

This synthesis depends on the existing deep dives:

- `plans/gstack/source-material/12-convergence-opportunity.md`
- `plans/gstack/source-material/13-phase-plan.md`
- `plans/gastown/source-material/02-architecture.md`
- `plans/gastown/source-material/11-skills-gastown-relationship.md`
- `plans/beads/source-material/11-production-gaps.md`
- `plans/beads/source-material/12-build-plan.md`
- `plans/claude_research/four-frameworks-one-architects-field-guide.md`

## Practical reading rule

When you feel lost, use this shortcut:

- If the question is "How do agents think better?" read `gstack`
- If the question is "How do agents run at scale?" read `gastown`
- If the question is "How does work survive sessions?" read `beads`
- If the question is "How do we make these feel like one product?" read this folder
