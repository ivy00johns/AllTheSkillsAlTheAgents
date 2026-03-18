# 01 — Project Overview

## What gstack Is

gstack is an open-source system that turns Claude Code into a **virtual engineering
team**. Built by Garry Tan (YC President & CEO), it provides 13 specialist skills
as slash commands — a CEO, Eng Manager, Senior Designer, Staff Engineer, QA Lead,
and Release Engineer — enabling one person to ship 10,000–20,000 lines of
production code per day with full testing, review, design audit, and QA.

## The Compression Thesis

AI-assisted coding compresses implementation time 10–100x. gstack quantifies this:

| Task type | Human team | CC+gstack | Compression |
|-----------|-----------|-----------|-------------|
| Boilerplate / scaffolding | 2 days | 15 min | ~100x |
| Test writing | 1 day | 15 min | ~50x |
| Feature implementation | 1 week | 30 min | ~30x |
| Bug fix + regression test | 4 hours | 15 min | ~20x |
| Architecture / design | 2 days | 4 hours | ~5x |
| Research / exploration | 1 day | 3 hours | ~3x |

**Proven at scale:** 600,000+ lines of production code in 60 days. 140,751 lines
added in a single retro window. 362 commits across 3 projects. Part-time.

## The Stack

- **Runtime:** Bun (TypeScript)
- **Browser:** Playwright (headless Chromium, persistent daemon)
- **Binary:** `bun build --compile` → ~58MB executable
- **Skills:** Markdown templates (.tmpl) + Bash blocks
- **Testing:** Vitest + custom session-runner + LLM-as-judge
- **License:** MIT

## By the Numbers

| Metric | Value |
|--------|-------|
| Skills | 13 |
| Browse commands | 50+ |
| Browse tests | 166+ |
| Cognitive patterns | 41 (14 CEO + 15 Eng + 12 Design) |
| Design audit items | 80 |
| AI slop patterns | 10 |
| Eval tiers | 3 (free, E2E ~$3.85, LLM-judge ~$0.15) |
| Template placeholders | 10 |
| Snapshot flags | 6+ |

## Where It Sits in the Landscape

gstack occupies a unique position — it's not an orchestrator (like gastown),
not an issue tracker (like beads), and not a role definition library (like
AllTheSkillsAllTheAgents). It's the **quality intelligence layer** — the system
that knows *how to think* about code, design, architecture, and shipping.

| System | Role |
|--------|------|
| gastown | The factory floor (orchestrates agents) |
| beads | The ledger (tracks work + dependencies) |
| AllTheSkillsAllTheAgents | The blueprints (role definitions + contracts) |
| **gstack** | **The quality brain (cognitive reviews + QA + design + shipping)** |

No one else has:
1. Cognitive patterns that activate latent knowledge (not checklists)
2. A headless browser with an AI-native ref system
3. Template-generated skills that can't drift from source code
4. A 3-tier eval system for validating the skills themselves
5. Design system inference from live running sites
6. AI slop detection codified as a checklist

## Who Made This

Garry Tan, President & CEO of Y Combinator. This is his daily driver for shipping
production code. The compression ratios are measured, not theoretical.
