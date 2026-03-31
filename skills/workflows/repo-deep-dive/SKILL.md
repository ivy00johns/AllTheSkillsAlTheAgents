---
name: repo-deep-dive
version: 1.0.0
description: >-
  Perform a comprehensive technical deep dive on an open-source repository, combining
  a Claude Deep Research document with hands-on codebase analysis to produce a structured
  12-14 document reference series. Use this skill whenever the user wants to deeply analyze
  a repo, do a deep dive on a project, reverse-engineer a codebase, create a technical
  reference for an open-source tool, understand how a project works inside and out, or
  compare another project's architecture with this ecosystem. Also trigger when the user
  mentions "deep dive", "deep research", "analyze this repo", "break down this codebase",
  "technical reference", "how does this project work", or has a Deep Research markdown
  alongside a cloned repo ready for analysis.
requires_claude_code: true
composes_with:
  - project-profiler
  - plan-builder
  - mermaid-charts
---

# Repo Deep Dive

Turn a Claude Deep Research document and a locally cloned repository into a comprehensive,
structured technical reference — the kind of document set that lets someone understand a
100k+ LoC codebase in an afternoon.

## What You Need

1. **A Deep Research document** — markdown from a Claude Deep Research session about the project.
   This provides landscape context, community perspective, and high-level understanding that
   code analysis alone can't give you.

2. **A locally cloned repo** — the actual source code to trace, measure, and analyze.

If either is missing, ask the user. The Deep Research doc is critical — it grounds the
analysis in why the project exists and where it sits in the landscape, not just what the
code does. If the user doesn't have one, suggest they run a Deep Research session first
(it takes ~5 minutes and dramatically improves the output quality).

## The Process

### Phase 1: Orient

Read the Deep Research document first. Extract:
- What the project is and why it exists
- Key architectural claims to verify against the code
- Community perception vs. what the code actually does
- The project's position in its ecosystem/landscape

Then gather hard numbers from the repo:

```bash
# Lines of code by language
find <repo> -type f \( -name "*.ts" -o -name "*.go" -o -name "*.py" -o -name "*.rs" \) | xargs wc -l 2>/dev/null | tail -1
# Or use tokei/cloc/scc if available

# Git stats
git -C <repo> log --oneline | wc -l          # commits
git -C <repo> shortlog -sn | head -5          # top contributors
git -C <repo> log --format=%ai | tail -1       # first commit
ls <repo>/src/**/*.{ts,go,py,rs} 2>/dev/null | wc -l  # source files
```

These numbers go into the "By the Numbers" table in `01-project-overview.md`. Be precise —
the stats anchor the entire deep dive and readers trust them.

### Phase 2: Map the Architecture

Start from the entry points and trace inward:
- CLI entry point (main.go, index.ts, __main__.py, etc.)
- How commands route to subsystems
- The data model (schemas, types, database tables)
- How components communicate (IPC, messages, shared state, events)

Use parallel subagents when possible — dispatch 3-4 agents to explore different subsystems
simultaneously. Each agent traces one major area:

```
Agent 1: Data model + storage layer
Agent 2: Core business logic / engine
Agent 3: CLI + external interfaces
Agent 4: Agent/worker/plugin system (if applicable)
```

The goal is a mental model of the architecture that you can explain in ~200 lines of markdown,
with a mermaid diagram (using the `mermaid-charts` skill) showing how the major pieces connect.

### Phase 3: Deep Dive Each Subsystem

For each major subsystem (typically 6-10), produce a focused document covering:
- **What it does** — purpose and responsibilities
- **How it works** — key data structures, algorithms, patterns
- **Key files** — where to look in the code (with paths)
- **Design decisions** — why it's built this way, not another way
- **Gotchas** — non-obvious behavior, edge cases, known issues

Read the actual code. Don't summarize from comments or READMEs alone — trace execution paths,
read the tests, look at error handling. The value of a deep dive is discovering what the
docs don't tell you.

### Phase 4: Compare and Assess

The final 2-3 documents provide the strategic view:

**Comparison document** — How does this project compare to AllTheSkillsAllTheAgents and
any other projects in the analysis scope? Use a table format:

| Dimension | This Project | AllTheSkills | Notes |
|-----------|-------------|--------------|-------|
| Scale     | Xk LoC      | ~5k          | ...   |

Focus on what each project has that the other lacks — this is where the insight lives.

**Convergence/frontier document** — What is genuinely novel here? What is table stakes?
What would a combined system look like? This is the document that makes the deep dive
worth doing — it surfaces the ideas worth stealing and the integration opportunities
worth pursuing.

## Output Structure

All output goes in `{output_dir}/{project}_deepdive/source-material/`.

The user may specify `{output_dir}` — if not, default to `~/AI/DeepResearch/`.
This is the central monorepo for all deep dive research and analysis documents.

### Document Progression

Read `references/document-template.md` for the full template with per-document guidance.

The consistent structure across all deep dives:

| # | Document | Purpose |
|---|----------|---------|
| 00 | INDEX.md | Table of contents, generation metadata, reading guide |
| 01 | project-overview.md | What it is, by the numbers, landscape position |
| 02 | architecture.md | High-level system design, layers, key decisions |
| 03-09 | [subsystem docs] | Deep technical dives — one per major subsystem |
| 10+ | comparison.md | How it compares to AllTheSkills and related projects |
| 11+ | convergence-analysis.md | What each project has that the other lacks |
| 12+ | frontier-assessment.md | What's novel, what's table stakes, what to build |

The exact number and naming of subsystem docs (03-09) varies by project. A project with
a complex agent system gets `agent-system.md`. A project with a custom database gets
`storage-engine.md`. Name them for what they cover, not by a fixed template.

### Document Quality Standards

- **80-300 lines per document** — long enough to be thorough, short enough to read in one sitting
- **Code paths, not code dumps** — reference specific files and functions, don't paste large blocks
- **"By the numbers" tables** — readers love hard data, give them precise counts
- **Mermaid architecture diagrams** — use the `mermaid-charts` skill for flowcharts, sequence diagrams, and system maps instead of ASCII art. Prefer `flowchart TB` with subgraphs for layer-cake architectures, `sequenceDiagram` for request flows
- **Cross-references** — link between documents when one subsystem touches another
- **Honest assessments** — note gaps, limitations, and production readiness issues candidly

### INDEX.md Format

The INDEX is the entry point. It must include:

```markdown
# {Project} Deep Dive — Index

{One paragraph describing what this deep dive covers and why.}

## Documents

| # | File | Topic |
|---|------|-------|
| 01 | [project-overview.md](01-project-overview.md) | What {project} is, by the numbers |
| 02 | [architecture.md](02-architecture.md) | {Specific architecture description} |
...

## How to Read This Series

{2-3 paragraphs guiding the reader through the documents in order, explaining
what to read first, what to keep open as reference, and what to save for last.}

## Generated

{Date} — from codebase analysis of {project} ({version}, {LoC} LoC, {commits} commits,
{other key stats}) and AllTheSkillsAllTheAgents ({N} skills, {M} files).
```

## Parallelization Strategy

Deep dives are expensive but parallelizable. Use subagents aggressively:

**Phase 2 (architecture mapping):** Dispatch 3-4 agents to explore different code areas
simultaneously. Each reports back a summary of what they found.

**Phase 3 (subsystem deep dives):** Once you have the architecture map, dispatch one agent
per subsystem document. Each agent writes its document independently. This is the biggest
time saver — 8 documents written in parallel instead of sequentially.

**Phase 4 (comparison/assessment):** These require the earlier documents as context, so
they run after Phase 3 completes. But the comparison and frontier docs can be written in
parallel with each other.

When running without subagents, work through the documents sequentially. The architecture
doc (02) should be written first since all subsystem docs reference it.

## Adapting the Scope

Not every project needs 14 documents. Adjust the scope based on the codebase:

| Codebase Size | Documents | Approach |
|---------------|-----------|----------|
| < 10k LoC | 6-8 | Combine subsystems, shorter docs |
| 10k-100k LoC | 10-12 | Standard deep dive |
| 100k+ LoC | 12-14 | Full treatment, split large subsystems |

The comparison and frontier documents are always included — they're the strategic payoff
that makes the deep dive worth more than just reading the source.

## Working with the Deep Research Document

The Deep Research doc is your starting hypothesis. The codebase is the ground truth.

Common patterns:
- **Research says X, code confirms X** — great, cite both and note the consistency
- **Research says X, code shows Y** — this is gold. Document the discrepancy. Often the
  research reflects the project's aspirations while the code shows current reality.
- **Research mentions feature Z, code has no trace** — planned but unimplemented, or
  removed. Note it in the gap analysis.
- **Code has feature W, research doesn't mention it** — undocumented capability. These
  discoveries are some of the most valuable outputs of a deep dive.

## What Makes a Great Deep Dive

The best deep dives from this ecosystem share these qualities:

1. **They teach** — someone reading the output understands the project deeply, not just superficially
2. **They're honest** — gaps, limitations, and "this is impressive" moments are both documented
3. **They connect** — the comparison docs don't just list differences, they identify convergence opportunities
4. **They're actionable** — the frontier assessment tells you what to build next, not just what exists
5. **They're precise** — hard numbers, specific file paths, exact function names — not vague summaries
