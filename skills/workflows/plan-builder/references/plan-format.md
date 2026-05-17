# Plan Format

The plan document has two sections — reasoning first, then the orchestrator-ready build spec. Save to `docs/plans/YYYY-MM-DD-<project-name>-plan.md` unless the user's preferences override the location.

## Section 1: Architecture Reasoning

Human-readable explanation of the thinking behind the plan. This section is for the user, not the orchestrator.

```markdown
# [Project Name] — Architecture Reasoning

## What This Is
[One paragraph: what gets built, who it serves, why it matters]

## Source Material Analysis
[Only if artifacts were provided. Summarize what you found:
content domains, volume, structure, interactive potential]

## Key Decisions
[Numbered list. Each entry: decision + rationale. Cover:
- Tech stack choice and why
- Content organization strategy
- What's a page vs. a component vs. a section
- What's interactive vs. static
- Data flow (if any backend/API needed)
- Deployment target]

## Content Map
[Only if artifacts were provided. The source-to-component mapping from research extraction]

## Assumptions and Risks
[What you decided without confirmation. What could go wrong.
What the user should validate.]
```

## Section 2: Build Plan

The orchestrator reads this section. It extracts: what to build, components, technologies, shared data models, dependency graph, and validation criteria (see orchestrator Phase 1). Structure the plan to make that extraction obvious.

```markdown
# [Project Name] — Build Plan

> **For orchestrated builds:** Use the orchestrator skill to execute this plan with parallel agents.
> **For solo builds:** Expand each component into TDD-style implementation steps (red → green → refactor) and work through them sequentially.

## Goal
[One paragraph describing the finished product, its core purpose,
and the acceptance criteria — how you know it's done]

## Tech Stack
[Be specific. Not "a modern framework" — name the framework, version if it matters,
and key libraries. Example:]
- **Runtime:** Node.js 20+
- **Framework:** Next.js 14 (App Router)
- **Styling:** Tailwind CSS
- **Data:** Static content from markdown, no database
- **Deployment:** Vercel

## Components
[Each component gets a name, responsibility, and rough file ownership.
The orchestrator uses this to define agent boundaries.]

### [Component Name]
- **Responsibility:** [What it does]
- **Owns:** [Directories/files]
- **Depends on:** [Other components, or "none"]
- **Key features:** [Bulleted list]

### [Component Name]
...

## Shared Data Models
[Entities referenced by multiple components. Define shape here so the
orchestrator can create shared types before spawning agents.]

## Dependency Graph
[What must exist before something else can be built.
Example: "Shared types → Backend API → Frontend pages"]

## Key Features
[Numbered list of discrete, buildable features. Each should be
assignable to one agent. Order by dependency — independent features first.]

1. [Feature] — [which component owns it]
2. [Feature] — [which component owns it]
...

## Validation Criteria
[How we know the build is done. Specific, testable conditions.]
- [ ] [Criterion]
- [ ] [Criterion]
...

## Agent Hints
[Notes for the orchestrator about parallelization opportunities,
natural agent boundaries, and coordination risks.]
- Suggested team size: [N agents, with rationale]
- Natural splits: [e.g., "frontend and backend are fully independent after shared types"]
- Coordination risks: [e.g., "search feature touches both frontend and backend — assign to one agent or define contract carefully"]
- Content that needs special handling: [e.g., "statistics table has 20+ rows — consider a data file rather than hardcoding"]
```
