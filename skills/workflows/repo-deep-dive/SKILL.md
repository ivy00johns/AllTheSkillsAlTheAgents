---
name: repo-deep-dive
version: 1.2.0
description: >-
  Perform a comprehensive technical deep dive on an open-source repository, combining
  a deep-research markdown document with hands-on codebase analysis to produce a structured
  12-14 document reference series. Use this skill whenever the user wants to deeply analyze
  a repo, do a deep dive on a project, reverse-engineer a codebase, create a technical
  reference for an open-source tool, understand how a project works inside and out, or
  compare another project's architecture against a reference project. Also trigger when the
  user mentions "deep dive", "deep research", "analyze this repo", "break down this codebase",
  "technical reference", "how does this project work", or has a deep-research markdown
  alongside a cloned repo ready for analysis.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent"]
composes_with: ["project-profiler", "plan-builder", "mermaid-charts", "wiki-research", "llm-wiki"]
spawned_by: []
---

# Repo Deep Dive

> **Tradeoff:** Biases toward exhaustive documentation. For quick familiarization, use Explore subagent or grep instead.

Turn a Claude Deep Research document and a locally cloned repository into a comprehensive, structured technical reference — the kind of document set that lets someone understand a 100k+ LoC codebase in an afternoon.

## What You Need

1. **A deep-research document** — markdown from any deep-research session about the project (Claude Deep Research, ChatGPT Deep Research, Gemini Deep Research, or a hand-written brief). This provides landscape context, community perspective, and high-level understanding that code analysis alone can't give you.

2. **A locally cloned repo** — the actual source code to trace, measure, and analyze.

3. **An output directory** — where the deep dive's document series should land. Ask the user for this if not provided. There is no built-in default — naming the location explicitly keeps deep dives from accumulating in a default folder the user forgets about.

If the deep-research document is missing, ask the user. It's critical — it grounds the analysis in why the project exists and where it sits in the landscape, not just what the code does. If the user doesn't have one, suggest they run a deep-research session first (it takes ~5 minutes and dramatically improves the output quality).

## The Process

Four phases. Read `references/phases.md` for the detailed instructions, code snippets for measurement, and per-phase guidance.

1. **Phase 1 — Orient.** Read the deep-research doc, extract claims, gather hard numbers from the repo (LoC, commits, contributors).
2. **Phase 2 — Map the Architecture.** Trace from entry points inward. Use parallel subagents to explore subsystems concurrently. Produce a mermaid architecture diagram.
3. **Phase 3 — Deep Dive Each Subsystem.** One focused document per major subsystem (6-10 typical). Read the actual code, not just docs.
4. **Phase 4 — Compare and Assess.** Comparison + convergence/frontier documents. This is the strategic payoff.

## Output Structure

All output goes in `{output_dir}/{project}_deepdive/source-material/`.

`{output_dir}` is required and supplied by the user. If they don't specify one, ask before generating any files — silently dropping a 12-document series into a default location wastes their time finding it later.

### Document Progression

Read `references/document-template.md` for the full template with per-document guidance.

The consistent structure across all deep dives:

| # | Document | Purpose |
|---|----------|---------|
| 00 | INDEX.md | Table of contents, generation metadata, reading guide |
| 01 | project-overview.md | What it is, by the numbers, landscape position |
| 02 | architecture.md | High-level system design, layers, key decisions |
| 03-09 | [subsystem docs] | Deep technical dives — one per major subsystem |
| 10+ | comparison.md | How it compares to a reference project and related tools |
| 11+ | convergence-analysis.md | What each project has that the other lacks |
| 12+ | frontier-assessment.md | What's novel, what's table stakes, what to build |

The exact number and naming of subsystem docs (03-09) varies by project. A project with a complex agent system gets `agent-system.md`. A project with a custom database gets `storage-engine.md`. Name them for what they cover, not by a fixed template.

### Document Quality Standards

- **80-300 lines per document** — long enough to be thorough, short enough to read in one sitting
- **Code paths, not code dumps** — reference specific files and functions, don't paste large blocks
- **"By the numbers" tables** — readers love hard data, give them precise counts
- **Mermaid architecture diagrams** — use the `mermaid-charts` skill for flowcharts, sequence diagrams, and system maps instead of ASCII art. Prefer `flowchart TB` with subgraphs for layer-cake architectures, `sequenceDiagram` for request flows
- **Cross-references** — link between documents when one subsystem touches another
- **Honest assessments** — note gaps, limitations, and production readiness issues candidly

## Parallelization, Scope, and Working With the Research Doc

Read `references/parallelization.md` for: the subagent strategy across phases, how to adapt scope to codebase size (6-8 / 10-12 / 12-14 docs), how to reconcile contradictions between the research doc and the code, and what makes a great deep dive vs a mediocre one.

## Anti-Pattern

> **Forbidden:** Generating a deep dive without the user-supplied output directory. Silently dropping a 12-doc series into a default location wastes the user's time.

## Reference Files

- `references/phases.md` — detailed instructions for Phases 1-4 with measurement commands and subagent dispatch patterns
- `references/document-template.md` — full per-document template (INDEX, overview, architecture, subsystem skeletons, comparison, convergence, frontier)
- `references/parallelization.md` — subagent strategy, scope adaptation, reconciling research vs code, hallmarks of a great deep dive
