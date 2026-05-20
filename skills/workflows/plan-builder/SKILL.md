---
name: plan-builder
version: 1.4.0
description: |
  Transform research documents, Compass artifacts, PRDs, reference materials, and conversational goals into structured project plans ready for the orchestrator to execute. Use this skill when the user has source material and wants to build something from it, when the user says "make a plan", "plan this out", "I want to build X from this research", or when a plan is needed before invoking the orchestrator. Also trigger when @-mentioned files or attached documents accompany a build request, when the user wants to turn research into a website/app/tool, or when orchestrator would be invoked but no plan exists yet. This skill produces the plan — orchestrator consumes it.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed_tools: ["Read", "Write", "Edit", "Glob", "Grep"]
composes_with: ["orchestrator", "project-profiler", "mermaid-charts", "contract-author"]
spawned_by: []
---

# Plan Builder

> **Tradeoff:** Biases toward thoroughness over speed. For simple changes that don't need a plan, skip directly to implementation.

## When this skill applies

This skill assumes a contract-first multi-agent build model:

- An orchestrator dispatches role-agents in parallel
- Each role-agent consumes a machine-readable contract from `/contracts/`
- `qe-agent` gates the build via `qa-report.json`

For single-agent or ad-hoc work, this skill is not the right tool.

<what-to-do>

Transform source material and project goals into orchestrator-ready build plans.

The orchestrator is powerful but needs a well-structured plan to work from. This skill bridges the gap between "I have research and a vision" and "orchestrator, go build it." It handles the thinking that should happen *before* agents are spawned: synthesizing source material, making architectural decisions, mapping content to components, and producing a plan the orchestrator can immediately act on.

**Announce at start:** "Using plan-builder to create a structured project plan."

## When This Skill Runs vs Others

- **Brainstorming** explores what to build when the idea is vague. It asks many questions, one at a time, to refine intent. If you arrive here with only a vague idea and no source material, invoke brainstorming first, then come back with the spec it produces.
- **Plan-builder** (this skill) synthesizes known inputs into a build plan. It works when you have source material, a clear goal, or a spec from brainstorming. It asks at most 3 clarifying questions before producing a draft — bias toward action.
- **Writing-plans** produces TDD-level implementation detail (exact file paths, test code, commit messages) for single-agent sequential execution. Plan-builder produces architecture-level plans for multi-agent parallel execution.
- **Orchestrator** consumes the plan this skill produces. It sizes teams, authors contracts, and spawns agents.

```text
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

## Path A: Artifact Ingestion

When the user provides research documents, Compass artifacts, or reference material alongside a build request, follow the four-step extraction in `references/research-extraction.md`:

1. **Synthesize source material** — content domains, natural sections, data points, implied features, volume
2. **Map content to architecture** — produce a source-to-component table; research-heavy projects need information architecture before code architecture
3. **Check existing codebase (Path A+)** — only if working in an existing project; respect existing conventions
4. **Confirm with user** — present the content map + key decisions concisely; ask at most 3 clarifying questions total

Then produce the plan (see `references/plan-format.md`).

## Path B: Goal-Driven (No Artifacts)

When the user has a clear goal but no source material:

1. Ask: **What are you building, who is it for, and are there constraints?** (tech stack, timeline, existing code, deployment target). This is one question — don't split it into three messages.
2. If the answer is still vague after one round, invoke brainstorming rather than asking more questions. Plan-builder is for synthesis, not ideation.
3. If the goal is clear enough to plan, proceed straight to plan production.

## Behavior Rules

- **Reasoning first, plan second.** Always produce Section 1 (Architecture Reasoning) before Section 2 (Build Plan). Thinking through the *why* produces better plans than jumping straight to the *what*.
- **Surface ambiguity, don't bury it.** If source material is contradictory or a decision could go either way, say so in Architecture Reasoning. Silent assumptions become integration bugs.
- **Bias toward action.** Three clarifying questions maximum. After that, draft the plan and let the user correct it. A wrong draft you can fix is more useful than a perfect question you haven't asked yet.
- **Right-size for orchestrator.** Plans should be specific enough that the orchestrator can size teams and author contracts, but not so detailed that agents have no autonomy. Component responsibilities yes, implementation pseudocode no.
- **Flag scale.** If the plan would require more than 6 parallel agents, suggest phasing: build the core in phase 1, extend in phase 2. Large teams need proactive context management (handoffs, phased spawning) to maintain quality.
- **Respect existing code.** When augmenting an existing project, follow its conventions. Don't propose a React rewrite of a Vue app just because you prefer React.

## Before Handoff: Long-Horizon Plans

For plans affecting systems beyond roughly 30 days — product launches, pricing changes, migrations, anything with time to ripple — run the second-order-effects discipline before declaring the plan finalized. See `references/second-order-effects.md`. Document the **unintended consequence** and **feedback loop** in the plan itself (a short subsection at the end of Architecture Reasoning is the right home), so the orchestrator and downstream agents inherit that context rather than rediscovering it the hard way.

## Handoff

After the plan is saved:

> "Plan saved to `docs/plans/YYYY-MM-DD-<name>-plan.md`. Ready to build?"
>
> - **Orchestrated build:** I'll invoke the orchestrator skill to spawn the agent team
> - **Solo build:** I'll invoke writing-plans to expand this into TDD implementation steps
> - **Review first:** Take a look at the plan and let me know what to change

Wait for the user's choice. Do not auto-invoke the orchestrator.

## Anti-Pattern

> **Forbidden:** Padding the plan with phases for the sake of structure. If three steps suffice, write three steps.

</what-to-do>

<supporting-info>

## Reference Documents

- **`references/plan-format.md`** — the section-by-section structure of the plan document (Architecture Reasoning + Build Plan, with templates for each section).
- **`references/research-extraction.md`** — how to pull a plan out of research docs (synthesize, map to architecture, check existing code, confirm with user).
- **`references/second-order-effects.md`** — discipline for mapping first, second, and third-order consequences plus the unintended consequence and feedback loop, for any plan affecting systems beyond ~30 days.

## Output Location

Save the plan to `docs/plans/YYYY-MM-DD-<project-name>-plan.md` unless user preferences override the location.

</supporting-info>
