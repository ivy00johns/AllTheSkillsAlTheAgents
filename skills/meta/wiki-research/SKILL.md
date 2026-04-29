---
name: wiki-research
version: 2.0.0
description: |
  Use this skill BEFORE any codebase exploration, repo-deep-dive, or raw source reading when
  the project has an Obsidian wiki (index.md + wiki/ directory). Always invoke when an
  orchestrator, code-reviewer, backend-agent, or any role skill needs project context,
  architecture understanding, component knowledge, or design decisions. Reading 3–4 wiki
  pages (~2,000 tokens) replaces crawling raw source directories (~100,000–500,000 tokens).
  Trigger on: "how does X work", "what is X", "what patterns does X use", "understand the
  architecture", "review this code", "build X" (when project context is needed), or any task
  where understanding the system before touching files would save re-work. If unsure whether a
  wiki exists, spend 5 seconds checking — the payoff is enormous. Skip only when the task is
  purely mechanical (rename a variable, fix a typo) and requires zero project understanding.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["wiki/", "index.md"]
allowed_tools: ["Read", "Glob", "Grep"]
composes_with: []
spawned_by: ["orchestrator", "code-reviewer", "repo-deep-dive", "project-profiler", "backend-agent", "frontend-agent", "security-agent", "plan-builder"]
---

# Wiki-First Research Protocol

An Obsidian wiki is a compiled, cross-linked knowledge base synthesized from raw source material. Reading it is an order of magnitude cheaper than re-reading raw sources — and faster than re-deriving understanding the hard way.

## Why Wiki-First

| Source | Typical token cost | When to use |
|--------|-------------------|-------------|
| `index.md` scan | ~300–600 tokens | Always — find what's covered |
| 1 wiki entity/concept page | ~300–800 tokens | Targeted knowledge |
| 1 wiki source page | ~600–1,500 tokens | Provenance + raw doc locations |
| 1 raw source directory (10–14 docs) | ~30,000–200,000 tokens | Only when wiki gaps exist |
| Full codebase exploration | 200,000–500,000+ tokens | Last resort |

Reading the wiki index + 3 pages costs roughly the same as scanning a single mid-sized source file. It almost always covers what you need.

## Step 1 — Detect the Wiki

Check if a wiki exists before doing anything else:

```bash
# Fast check: does wiki structure exist?
ls index.md wiki/ 2>/dev/null | head -5

# Or check CLAUDE.md for a wiki path declaration
grep -i "wiki" CLAUDE.md 2>/dev/null | grep -i "path\|root\|location" | head -3
```

If no wiki exists → skip this protocol entirely and proceed with normal exploration.  
If a wiki is found → continue.

## Step 2 — Read index.md

`index.md` is the navigation layer. It contains one-line summaries of every wiki page, organized by category. Reading it takes seconds and tells you exactly which pages are relevant — don't skip this.

Look for entries matching:
- The systems/components your task involves (entities)
- The patterns/principles that apply (concepts)
- Any known source collections you'd otherwise re-read (sources)

## Step 3 — Read Targeted Pages (2–4 pages max)

Based on index.md summaries, read the pages most relevant to your task:

**Entity pages** (`wiki/entities/<name>.md`) — for specific systems, platforms, or components  
**Concept pages** (`wiki/concepts/<name>.md`) — for patterns, principles, and architectural ideas  
**Overview** (`wiki/overview.md`) — only if you need broad ecosystem context  
**Source pages** (`wiki/sources/<name>.md`) — only if you need research provenance or raw doc pointers

Each page ends with a `## Related` section. Follow those links only if they're directly relevant — don't spider the entire wiki. Stop when your question is answered.

## Step 4 — Escalate Only When Needed

After reading targeted pages, one of three situations applies:

**Wiki covers it** → You're done. Proceed with your task using wiki knowledge.

**Wiki has a gap** (page flags "not yet documented", contradiction exists, or your specific question wasn't covered):
- Check the relevant source page for raw doc pointers
- Read the specific raw files identified — not entire directories
- Return to your task once the gap is filled

**Topic isn't in the wiki at all**:
- Check `CLAUDE.md` or `confluence-overview.md` for source maps
- Proceed with targeted codebase exploration (Grep/Glob first, not broad reads)

## Standard Lookup Cost

```
1. Read index.md            →  ~500 tokens   (mandatory)
2. Read 2–3 targeted pages  →  ~1,500 tokens  (pick relevant ones)
3. Source page if needed    →  ~1,000 tokens  (optional)
──────────────────────────────────────────────
Total:  ~3,000 tokens  ←→  1 small source file
```

## Wiki Page Structure

Every page follows this format — knowing this helps you skim efficiently:

```markdown
---
title: Page Title
type: entity | concept | comparison | source | overview
tags: [...]
sources: [...]
---

# Page Title
One-paragraph summary.         ← Read this. Usually enough.

## Sections                    ← Read what's relevant to your task.

## Related
- [[linked-page]] — why linked  ← Scan for follow-up reads.
```

The opening paragraph is often sufficient. Read sections selectively.

## Standard Wiki Directory Layout

```
<project-root>/
├── index.md          ← TOC, start here always
└── wiki/
    ├── overview.md   ← Ecosystem synthesis and roadmap
    ├── entities/     ← Named systems, platforms, components
    ├── concepts/     ← Architectural patterns and principles
    ├── comparisons/  ← Side-by-side analyses
    └── sources/      ← Per-source research summaries
```

---

## TheHiveWiki Quick Reference

For The Hive ecosystem at `/Users/johns/Repos/the-hive-ecosystem/DeepResearch/`:

**Wiki root:** `/Users/johns/Repos/the-hive-ecosystem/DeepResearch/index.md`

**Two research clusters (intentionally disconnected):**
- **The Hive cluster** — autonomous software delivery platform (beads, gastown, overstory, gstack, deerflow, mission-control, claude-code, claw-code, mempalace, codex, alltheskills)
- **MarketsBeRigged cluster** — AI-native quantitative trading (marketsberiggged, quantdinger, inteldeck)

**Key gotchas that will burn you if you don't know them:**
- **Codex ≠ OpenAI Codex.** `wiki/entities/codex` is the *Future Stack Synthesis* — convergence of gstack+gastown+beads. The `The-Hive/codex/overview/` directory holds this synthesis.
- **Two Claude Code deep dives.** `claude-code/` = v2.1.88 behavioral/architectural. `claude-code-source/` = v2.1.87 tool system and permissions. Intentionally separate.
- **AllTheSkills is part of The Hive** — it's the prompt library running in Claude Code right now.
- **MarketsBeRigged is a separate project** — zero wiki links to The Hive cluster.

**Raw source map** (use when wiki gaps exist):

| Wiki entity | Raw source location | Approx size |
|-------------|-------------------|-------------|
| beads | `The-Hive/beads/source-material/` | 13 docs, 225k LoC |
| gastown | `The-Hive/gastown/source-material/` | 13 docs, 377k LoC |
| overstory | `The-Hive/overstory/source-material/` | 13 docs, 96k LoC |
| gstack | `The-Hive/gstack/source-material/` | 14 docs |
| deerflow | `The-Hive/deerflow/source-material/` | 13 docs |
| mission-control | `The-Hive/mission-control/source-material/` | 14 docs |
| claude-code | `The-Hive/claude-code/source-material/` | 12 docs |
| claude-code-source | `The-Hive/claude-code-source/source-material/` | 14 docs |
| claw-code | `The-Hive/claw-code/source-material/` | 13 docs |
| codex (synthesis) | `The-Hive/codex/overview/` | 9 docs |
| mempalace | `The-Hive/mempalace/source-material/` | 12 docs |
| alltheskills | `AllTheSkills/alltheskills-design/` | 12 docs |
| the-hive spec | `The-Hive/the-hive-spec/` | 21+ docs |
| quantdinger | `MarketsBeRigged/QuantDinger_deepdive/source-material/` | 10 docs |
