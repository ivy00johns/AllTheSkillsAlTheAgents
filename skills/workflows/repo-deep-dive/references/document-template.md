# Document Template Reference

Per-document guidance for the deep dive output series. Each section below describes
what belongs in that document, with structural templates drawn from the 5 existing
deep dives (gastown, beads, overstory, gstack, mission_control).

## 00-INDEX.md

The navigation hub. Contains no analysis — only structure and metadata.

### Template

```markdown
# {Project Name} Deep Dive — Index

{One paragraph: what this deep dive covers, what inputs were used, and the
strategic question it answers.}

## Documents

| # | File | Topic |
|---|------|-------|
| 01 | [project-overview.md](01-project-overview.md) | {One-line topic} |
| 02 | [architecture.md](02-architecture.md) | {One-line topic} |
| ... | ... | ... |

## How to Read This Series

{Paragraph 1: Start with 01 for the big picture, then 02 for architecture.}

{Paragraph 2: Which documents to read in sequence vs. reference on-demand.}

{Paragraph 3: Which documents are forward-looking and benefit from reading
the technical docs first.}

## Source Repository

- Repository: {URL}
- Version analyzed: {version or commit SHA}
- Primary language: {language} ({framework/runtime details})
- License: {license}

## Generated

{YYYY-MM-DD} — from codebase analysis of {project} ({version}, {N}k LoC,
{N} commits, {other distinguishing stats}) and AllTheSkillsAllTheAgents
({N} skills, {N} files).
```

## 01-project-overview.md

The "what and why" document. Someone reading only this document should understand
the project's purpose, scale, and position in the landscape.

### Required Sections

**What {Project} Is** — 1-2 paragraphs explaining the project's purpose and
key insight. What problem does it solve? What's the core idea?

**By The Numbers** — A table with hard data:

| Metric | Value |
|--------|-------|
| Source files | {count} |
| Lines of code | {count} |
| Git commits | {count} |
| CLI commands | {count, if applicable} |
| {Domain-specific metric} | {value} |
| Runtime | {language/runtime} |
| License | {license} |

**Key Dependencies** — Table of major dependencies and their purpose.

**How {Project} Differs from {Related Project}** — If there's a natural comparison
point (often another project in the analysis scope), a comparison table here.

**Origin and Trajectory** — Brief history: key inflection points, current version,
maturity assessment.

## 02-architecture.md

The structural blueprint. After reading this, someone should be able to navigate
the codebase and understand how data flows through the system.

### Required Sections

**High-Level Architecture** — An ASCII diagram showing major components and how
they connect. Box-drawing characters work well:

```
┌─────────────┐     ┌─────────────┐
│   CLI       │────▸│   Engine    │
└─────────────┘     └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Storage   │
                    └─────────────┘
```

**Directory Layout** — Map of the source tree, annotated with what lives where.

**Key Design Decisions** — The 5-10 architectural choices that explain why the
codebase is shaped the way it is. Number them — later documents reference back.

**Execution Model** — How the system runs: startup, request flow, shutdown.

## 03-09: Subsystem Documents

Each subsystem gets its own document. The exact topics depend on the project,
but common subsystems include:

- Data model / schema
- Storage engine / persistence
- Agent/worker system
- CLI / command reference
- Plugin / extension system
- Messaging / coordination
- Merge / conflict resolution
- Integration layer (APIs, MCP, plugins)
- Observability / monitoring

### Per-Subsystem Structure

```markdown
# {NN} — {Subsystem Name}

## What It Does

{2-3 paragraphs: purpose, responsibilities, boundaries.}

## How It Works

{The meat of the document. Cover:}
- Key data structures and their relationships
- Core algorithms or processing pipelines
- State management and lifecycle
- Error handling patterns

## Key Files

| File | Purpose |
|------|---------|
| `src/engine/core.ts` | Main processing loop |
| `src/engine/types.ts` | Core type definitions |

## Design Decisions

{Why is it built this way? What alternatives were considered?}

## Gotchas

{Non-obvious behavior, edge cases, known limitations.}
```

## 10+: Comparison Document

### Structure

**Side-by-side table** comparing dimensions across projects:

| Dimension | Project A | Project B | Notes |
|-----------|-----------|-----------|-------|
| Language | Go | TypeScript | ... |
| Scale | 377k LoC | 96k LoC | ... |

**What {Project} Has That AllTheSkills Lacks** — Specific capabilities,
with enough detail to understand whether they're worth adopting.

**What AllTheSkills Has That {Project} Lacks** — Same treatment, reversed.

**Shared DNA** — Where the projects converge philosophically or architecturally.

## 11+: Convergence Analysis

Goes beyond comparison to identify integration opportunities:

- What can be ported directly?
- What requires adaptation?
- What ideas are worth stealing even if the implementation doesn't transfer?
- What would the combined system look like?

## 12+: Frontier Assessment

The strategic capstone document. Three sections:

**What Is Genuinely Novel** — Capabilities that no other system in the analysis
scope has. Each gets a "this is frontier because..." explanation.

**What Is Table Stakes** — Capabilities that any serious project in this space
needs. Having them is necessary but not differentiating.

**What the Combined System Could Become** — The vision for integration. Include
a layered architecture showing how the projects compose, and a phased build
sequence showing how to get there.
