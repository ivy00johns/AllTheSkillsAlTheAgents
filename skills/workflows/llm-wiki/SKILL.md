---
name: llm-wiki
version: 1.1.0
description: |
  Bootstrap and maintain LLM-powered personal knowledge bases (wikis) for any project or
  domain. Use when the user wants to create a "second brain", knowledge base, personal wiki,
  research tracker, reading companion, competitive analysis wiki, team knowledge base, or
  project notes. Trigger when the user says "set up a wiki for X", "I want to track my
  research on Y", "build me a knowledge base", "create an llm wiki", "organize my notes",
  "set up my second brain", "I'm reading a book and want to track it", or "maintain a wiki
  for this project". Also trigger when already inside a wiki directory for ingest, query, or
  lint operations — "add this article to the wiki", "what does the wiki say about X",
  "clean up the wiki", "process this source". This is distinct from RAG: the wiki is a
  persistent, maintained artifact that compounds over time.
requires_agent_teams: false
requires_claude_code: false
min_plan: starter
owns:
  directories: []
  patterns: ["index.md", "log.md", "overview.md"]
  shared_read: ["raw/", "wiki/"]
allowed_tools: ["Read", "Write", "Edit", "Glob", "Grep"]
composes_with: ["wiki-research", "repo-deep-dive", "project-profiler", "mermaid-charts"]
spawned_by: []
---

# LLM Wiki

Bootstrap and operate a persistent, LLM-maintained knowledge base for any domain.

The key idea: instead of re-deriving answers from raw sources every time, the LLM builds and maintains a structured wiki of markdown files. Sources are ingested once, knowledge is compiled into cross-linked pages, and the wiki compounds with every new source and question. You read it; the LLM writes it.

**Announce at start:** "Using llm-wiki to [set up / operate] your [domain] wiki."

## Entry Detection

First, check what situation you're in:

| Signal | Mode |
|--------|------|
| No `CLAUDE.md` with wiki schema present in cwd | **Setup** — bootstrap a new wiki |
| `CLAUDE.md` exists with wiki schema AND user wants to add a source | **Ingest** |
| `CLAUDE.md` exists with wiki schema AND user is asking a question | **Query** |
| `CLAUDE.md` exists with wiki schema AND user wants health check | **Lint** |
| `CLAUDE.md` exists with wiki schema AND no specific operation given | Ask: "Ingest a new source, query the wiki, or run a health check?" |

Detect a wiki CLAUDE.md by looking for the `## Wiki Schema` marker in the file.

---

## Setup Mode

Bootstrap a new wiki from scratch. Quick interview, then create the structure.

### Step 1: Interview (3 questions max, combine if possible)

Ask:
1. **Domain and purpose** — What is this wiki for? (topic, project, use case)
2. **Location** — Where should the wiki live? (default: `~/wikis/<domain-name>/` — confirm or let them specify a path)
3. **Sources you already have** — Any existing docs/articles/notes to ingest immediately? (optional — can start empty)

If the user's initial message already answers some of these, don't re-ask. Bias toward action.

### Step 2: Create directory structure

```
<wiki-root>/
├── CLAUDE.md          ← the wiki schema (LLM operating manual)
├── raw/               ← immutable source documents (user adds, LLM reads only)
│   └── assets/        ← downloaded images and attachments
├── wiki/              ← LLM-generated and LLM-maintained markdown pages
│   ├── index.md       ← content catalog (updated on every ingest)
│   ├── log.md         ← append-only operation history
│   ├── overview.md    ← evolving synthesis / thesis (created after first ingest)
│   └── sources/       ← one summary page per ingested source
│       └── .gitkeep
└── .gitignore         ← ignore nothing by default (wiki is just markdown)
```

Create these directories and files. The `wiki/sources/` directory holds one page per ingested source. Additional subdirectories (`wiki/entities/`, `wiki/concepts/`, etc.) are created as needed during ingest.

### Step 3: Write the wiki CLAUDE.md

Load `references/wiki-schema-template.md` and fill in the placeholders:
- `{{WIKI_NAME}}` — human-readable wiki name (e.g., "AI Research Wiki")
- `{{DOMAIN}}` — brief domain description (e.g., "AI safety research papers and blog posts")
- `{{WIKI_ROOT}}` — absolute path to the wiki root directory
- `{{DATE_CREATED}}` — today's date (YYYY-MM-DD)

Write the filled template to `<wiki-root>/CLAUDE.md`.

### Step 4: Initialize index.md and log.md

**`wiki/index.md`:**
```markdown
# Index

> Wiki: {{WIKI_NAME}} | Created: {{DATE}} | Sources: 0 | Pages: 0

## Sources
*(none yet — ingest your first source to begin)*

## Concepts
*(none yet)*

## Entities
*(none yet)*
```

**`wiki/log.md`:**
```markdown
# Log

Append-only record of wiki operations. Format: `## [YYYY-MM-DD] operation | details`

---

## [{{DATE}}] setup | Wiki initialized

Domain: {{DOMAIN}}
Wiki root: {{WIKI_ROOT}}
```

### Step 5: Confirm and offer first ingest

Tell the user:

> "Wiki created at `<path>`. Structure:
> - `raw/` — drop your source documents here
> - `wiki/` — I maintain this; you read it
> - `CLAUDE.md` — the schema that governs how I work in this wiki
>
> Ready to ingest your first source? Drop a file in `raw/` and tell me, or paste a URL/article directly."

If the user mentioned existing sources in step 1, proceed immediately to Ingest Mode.

---

## Ingest Mode

Process a new source into the wiki. This is the core compounding operation.

Read `references/operations.md` § Ingest for the full workflow. Summary:

1. **Read the source** — the user drops a file in `raw/` or provides content directly
2. **Discuss** — briefly surface the 2–3 most interesting takeaways; invite the user to guide emphasis
3. **Write a source summary page** to `wiki/sources/<slug>.md`
4. **Update or create entity and concept pages** — identify named things (people, orgs, tools, papers) and concepts that warrant their own pages; update cross-references
5. **Update `wiki/index.md`** — add the source entry, update page counts
6. **Append to `wiki/log.md`** — one entry: `## [DATE] ingest | <title>`
7. **Update `wiki/overview.md`** — revise the synthesis to incorporate the new source; note if it confirms, contradicts, or extends prior claims

A single source typically touches 5–15 wiki pages. Work through them systematically.

---

## Query Mode

Answer questions using the wiki as the knowledge base.

Read `references/operations.md` § Query for the full workflow. Summary:

1. Read `wiki/index.md` first to find relevant pages
2. Read the relevant pages
3. Synthesize an answer with wiki citations (link to the wiki pages, not raw sources)
4. Offer to file the answer as a new wiki page if it represents valuable synthesis (comparisons, analyses, discovered connections)

---

## Lint Mode

Health-check the wiki and surface improvements.

Read `references/operations.md` § Lint for the full workflow. Summary:

Check for:
- Contradictions between pages (newer sources superseding old claims)
- Orphan pages (no inbound links from other wiki pages)
- Concepts mentioned but lacking their own page
- Missing cross-references (entity A mentioned on page B but not linked)
- Data gaps (questions the wiki can't answer that a targeted search could fill)

Produce a lint report and offer to fix issues automatically or suggest new sources to investigate.

---

## Working Style

The user reads; the LLM writes. Some principles:

- **Never modify files in `raw/`** — they are the immutable source of truth
- **Always update `index.md` and `log.md`** on every ingest — these are how the LLM navigates at scale
- **Cross-references are the point** — a page with no links to other wiki pages is a missed opportunity
- **File good answers back** — if a query produces a valuable synthesis, create a wiki page for it
- **Note contradictions explicitly** — when new sources conflict with existing claims, update the relevant pages to flag the tension rather than silently overwriting

When the wiki grows large (100+ pages), suggest adding a search tool like `qmd` for more efficient navigation.

## Reference files

- `references/wiki-schema-template.md` — the CLAUDE.md template written into new wikis; load during Setup Step 3
- `references/operations.md` — detailed ingest, query, and lint workflows; load when executing those operations
