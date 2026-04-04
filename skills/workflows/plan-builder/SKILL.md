---
name: plan-builder
version: 1.1.0
description: |
  Transform research documents, Compass artifacts, PRDs, reference materials, and conversational goals into structured project plans ready for the orchestrator to execute. Use this skill when the user has source material and wants to build something from it, when the user says "make a plan", "plan this out", "I want to build X from this research", or when a plan is needed before invoking the orchestrator. Also trigger when @-mentioned files or attached documents accompany a build request, when the user wants to turn research into a website/app/tool, or when orchestrator would be invoked but no plan exists yet. This skill produces the plan — orchestrator consumes it.
requires_claude_code: true
composes_with: ["orchestrator", "project-profiler", "mermaid-charts", "contract-author"]
spawned_by: []
---

# Plan Builder

Transform source material and project goals into orchestrator-ready build plans.

The orchestrator is powerful but needs a well-structured plan to work from. This skill bridges the gap between "I have research and a vision" and "orchestrator, go build it." It handles the thinking that should happen *before* agents are spawned: synthesizing source material, making architectural decisions, mapping content to components, and producing a plan the orchestrator can immediately act on.

**Announce at start:** "Using plan-builder to create a structured project plan."

## When This Skill Runs vs Others

- **Brainstorming** explores what to build when the idea is vague. It asks many questions, one at a time, to refine intent. If you arrive here with only a vague idea and no source material, invoke brainstorming first, then come back with the spec it produces.
- **Plan-builder** (this skill) synthesizes known inputs into a build plan. It works when you have source material, a clear goal, or a spec from brainstorming. It asks at most 3 clarifying questions before producing a draft — bias toward action.
- **Writing-plans** produces TDD-level implementation detail (exact file paths, test code, commit messages) for single-agent sequential execution. Plan-builder produces architecture-level plans for multi-agent parallel execution.
- **Orchestrator** consumes the plan this skill produces. It sizes teams, authors contracts, and spawns agents.

```
brainstorming (vague idea) → plan-builder (structured plan) → orchestrator (agent army)
                              ↑ you are here
```

## Entry Detection

Assess what the user has brought:

| Signal | Entry Path |
|--------|-----------|
| @-mentioned files, attached docs, research artifacts, Compass exports | **Path A** — Artifact Ingestion |
| Spec from brainstorming, PRD, requirements doc | **Path A** — treat as artifact |
| Clear goal but no artifacts ("build me a dashboard for X") | **Path B** — Goal-Driven |
| Vague idea, no artifacts ("I want to do something with AI") | **Redirect** → invoke brainstorming |
| Existing codebase + new source material | **Path A+** — Augmentation variant |

## Path A: Artifact Ingestionu

When the user provides research documents, Compass artifacts, or reference material alongside a build request.

### Step 1: Synthesize Source Material

Read all provided artifacts. As you read, extract:

- **Content domains** — what topics does this material cover? (e.g., "voter registration law, demographic impact, legislative status, state-by-state analysis")
- **Natural sections** — how is the material organized? What are its structural boundaries?
- **Data points** — are there statistics, tables, comparisons, timelines, or other structured data?
- **Implied features** — what would a user of the finished product want to do with this information? (search it? compare states? check their own status?)
- **Content volume** — is this a single page of content or an entire site's worth?

### Step 2: Map Content to Architecture

This is the step most planning approaches miss. Research-heavy projects need *information architecture* before code architecture.

Think about how a human would navigate and consume this content:

- Which sections become distinct pages or views?
- What needs its own navigation entry vs. being a section within a page?
- Are there natural groupings (by topic, by audience, by geography)?
- Is there interactive potential? (calculators, filters, lookups, comparisons)
- What's the primary user journey through this content?

Produce a content map:

```
Source Section → Application Component → User Purpose
"Demographics data" → Interactive checker tool → "Am I affected?"
"State-by-state analysis" → Filterable state grid → "What's happening in my state?"
"Legislative timeline" → Timeline component → "Where does this stand?"
```

### Step 3: Check Existing Codebase (Path A+ variant)

If working within an existing project (not a blank repo):

1. Read the project structure, package.json/requirements.txt, existing routes/pages
2. Identify where new content integrates — new pages? new section of existing page? new API endpoints?
3. Note existing conventions (framework, styling approach, data patterns) that the plan must follow
4. Flag any conflicts between existing architecture and what the new content requires

### Step 4: Confirm with User

Before writing the plan, present your content-to-architecture mapping and key decisions. Keep this concise — a short list, not an essay:

- "Here's how I'd organize the content: [content map]"
- "Tech stack recommendation: [X] because [reason]"
- "This would be [N] pages/components — does that feel right?"

Ask at most **3 clarifying questions** total across the entire process. If you need more, you're probably overthinking it — make a decision, note it as an assumption, and let the user correct you in the draft.

### Step 5: Produce Plan

Write the plan document (see Output Format below).

## Path B: Goal-Driven (No Artifacts)

When the user has a clear goal but no source material.

1. Ask: **What are you building, who is it for, and are there constraints?** (tech stack, timeline, existing code, deployment target). This is one question — don't split it into three messages.
2. If the answer is still vague after one round, invoke brainstorming rather than asking more questions. Plan-builder is for synthesis, not ideation.
3. If the goal is clear enough to plan, proceed to Step 5 (Produce Plan).

## Output Format

Save the plan to `docs/plans/YYYY-MM-DD-<project-name>-plan.md` (user preferences for location override this default). The plan has two sections — reasoning first, then the orchestrator-ready build spec.

### Section 1: Architecture Reasoning

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
[Only if artifacts were provided. The source-to-component mapping from Step 2]

## Assumptions and Risks
[What you decided without confirmation. What could go wrong.
What the user should validate.]
```

### Section 2: Build Plan

The orchestrator reads this section. It extracts: what to build, components, technologies, shared data models, dependency graph, and validation criteria (see orchestrator Phase 1). Structure your plan to make that extraction obvious.

```markdown
# [Project Name] — Build Plan

> **For orchestrated builds:** Use the orchestrator skill to execute this plan with parallel agents.
> **For solo builds:** Use superpowers:writing-plans to expand into TDD implementation detail.

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

## Behavior Rules

- **Reasoning first, plan second.** Always produce Section 1 before Section 2. Thinking through the *why* produces better plans than jumping straight to the *what*.
- **Surface ambiguity, don't bury it.** If source material is contradictory or a decision could go either way, say so in Architecture Reasoning. Silent assumptions become integration bugs.
- **Bias toward action.** Three clarifying questions maximum. After that, draft the plan and let the user correct it. A wrong draft you can fix is more useful than a perfect question you haven't asked yet.
- **Right-size for orchestrator.** Plans should be specific enough that the orchestrator can size teams and author contracts, but not so detailed that agents have no autonomy. Component responsibilities yes, implementation pseudocode no.
- **Flag scale.** If the plan would require more than 6 parallel agents, suggest phasing: build the core in phase 1, extend in phase 2. Large teams need proactive context management (handoffs, phased spawning) to maintain quality.
- **Respect existing code.** When augmenting an existing project, follow its conventions. Don't propose a React rewrite of a Vue app just because you prefer React.

## Handoff

After the plan is saved:

> "Plan saved to `docs/plans/YYYY-MM-DD-<name>-plan.md`. Ready to build?"
>
> - **Orchestrated build:** I'll invoke the orchestrator skill to spawn the agent team
> - **Solo build:** I'll invoke writing-plans to expand this into TDD implementation steps
> - **Review first:** Take a look at the plan and let me know what to change

Wait for the user's choice. Do not auto-invoke the orchestrator.
