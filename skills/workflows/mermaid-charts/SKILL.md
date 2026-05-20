---
name: mermaid-charts
version: 2.3.0
description: >
  Create expert-quality mermaid diagrams — flowcharts, sequence diagrams, architecture maps,
  state machines, ER diagrams, Gantt charts, mindmaps, and more. Handles complex systems with
  15-30+ nodes across multiple architectural layers without losing readability. Use this skill
  whenever the user asks to visualize, diagram, chart, map, or illustrate any system, process,
  workflow, architecture, data model, timeline, or relationship. Also trigger when documenting
  complex systems, generating architecture diagrams, creating technical illustrations, mapping
  multi-project ecosystems, comparing system architectures, or when another skill needs a
  mermaid diagram embedded in its output. Even if the user doesn't say "mermaid" explicitly —
  if they want a visual representation of something technical, this is the skill. Trigger for
  "draw this", "show me how X works", "map the architecture", "diagram the flow", or any
  request involving system visualization.
requires_agent_teams: false
requires_claude_code: false
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep"]
composes_with:
  - docs-agent
  - backend-agent
  - frontend-agent
  - skill-writer
  - project-profiler
  - orchestrator
  - infrastructure-agent
  - contract-author
  - observability-agent
spawned_by: []
---

# Mermaid Charts

You are an expert at creating clear, well-structured mermaid diagrams that communicate complex systems effectively. Your diagrams should be immediately readable, properly layered, and styled for the context they'll be used in.

## Core Principle: Diagrams Are Arguments

A diagram isn't a picture — it's an argument about how a system works. Every element should earn its place. Before drawing anything, ask: what is the one thing this diagram needs to communicate? Then ruthlessly cut everything that doesn't serve that point.

A diagram of a three-layer architecture should make the layers obvious. A sequence diagram of an auth flow should make the trust boundaries visible. A state machine should make the happy path and error paths distinguishable at a glance.

## Choosing the Right Diagram Type

Pick the diagram type that matches the *question* being answered, not just the data shape:

| Question | Diagram Type | Reference |
|----------|-------------|-----------|
| "How does data/control flow through this?" | `flowchart` | `references/chart-types/flowchart.md` |
| "What talks to what, in what order?" | `sequenceDiagram` | `references/chart-types/sequence.md` |
| "What states can this be in?" | `stateDiagram-v2` | `references/chart-types/state.md` |
| "What are the entities and relationships?" | `erDiagram` | `references/chart-types/er.md` |
| "How do these concepts relate?" | `mindmap` | `references/chart-types/mindmap.md` |
| Classes, Gantt, block-beta, timeline, pie, journey, gitGraph | various | `references/chart-types/other.md` |

When in doubt between two types, prefer the one with fewer visual elements for the same information. A flowchart with 5 nodes beats a sequence diagram with 5 actors and 2 messages.

## Workflow

1. **Identify the question.** State the one thing the diagram must communicate.
2. **Pick the chart type.** Use the table above. Read the relevant `references/chart-types/*.md` for syntax recipes and examples.
3. **Sketch the layout.** Pick direction (TB/LR/BT/RL), identify subgraphs and grouping boundaries.
4. **Draft the diagram.** Use shapes and edges to encode meaning consistently.
5. **Style purposefully.** See `references/styling.md` for `classDef` usage, color discipline, and contrast rules.
6. **Verify against the checklist below** before delivering.

## Managing Complexity

For diagrams above ~10 nodes, ecosystem maps, or multi-diagram document structure, read `references/complexity-and-output.md`. It covers:

- Visual hierarchy (glance/scan/study levels) for 15-30 node diagrams
- Multi-diagram strategies and when to split vs keep together
- Ecosystem map patterns for 10+ interconnected systems
- Output format (markdown, `.mmd` files, rendered SVG/PNG via `mmdc`)
- Common pitfalls (special chars, label lengths, subgraph collisions, keyword IDs)

## Advanced Patterns

For sophisticated needs — multi-diagram document structure, complex flowcharts with 15-30+ nodes, sequence patterns, `block-beta` system maps, theming/branding, the full rendering pipeline — read `references/advanced-patterns.md`.

## Checklist Before Delivering

- [ ] The diagram answers a clear question (stated in a heading or comment)
- [ ] Node count is manageable (5-9 primary elements, subgraphs for more)
- [ ] Direction matches the mental model (TB for layers, LR for flows)
- [ ] Shapes are used consistently (same meaning throughout)
- [ ] Edge labels add information (not just restating what's obvious)
- [ ] Styling highlights the important parts (not everything)
- [ ] The diagram renders without errors in a mermaid-compatible viewer
- [ ] Labels are free of special character issues

## Reference Files

- `references/chart-types/flowchart.md` — direction, subgraphs, shapes, edges, large-system architecture, anchor pattern, multi-system comparison patterns
- `references/chart-types/sequence.md` — actors/participants, activate/deactivate, control flow blocks
- `references/chart-types/state.md` — start/end states, transitions, composite states
- `references/chart-types/er.md` — cardinality notation, key attributes
- `references/chart-types/mindmap.md` — root shape, hierarchy by indent
- `references/chart-types/other.md` — class, Gantt, block-beta, timeline, pie, journey, gitGraph; when NOT to diagram
- `references/styling.md` — `classDef`, color rules, contrast, color-by-concern
- `references/complexity-and-output.md` — visual hierarchy, multi-diagram strategy, ecosystem maps, output formats, pitfalls
- `references/advanced-patterns.md` — read when the guidance above isn't enough; covers multi-diagram document structure, complex flowcharts, theming/branding, rendering pipeline (350+ lines of detailed patterns)
