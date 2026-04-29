# Wiki Schema Template

This file is loaded by `llm-wiki` during Setup (Step 3) and written — with placeholders filled — to `<wiki-root>/CLAUDE.md`. It is the LLM's operating manual for that specific wiki.

---

## Template

Fill `{{WIKI_NAME}}`, `{{DOMAIN}}`, `{{WIKI_ROOT}}`, `{{DATE_CREATED}}` before writing.

---

```markdown
## Wiki Schema

> This file governs how the LLM operates in this wiki. Every session starts here.

**Wiki:** {{WIKI_NAME}}
**Domain:** {{DOMAIN}}
**Root:** {{WIKI_ROOT}}
**Created:** {{DATE_CREATED}}

### What this wiki is

This is an LLM-maintained knowledge base. The LLM writes and maintains all files under
`wiki/`. The human curates sources, asks questions, and reads the wiki. Raw sources live
in `raw/` and are never modified.

### Directory layout

```
{{WIKI_ROOT}}/
├── CLAUDE.md          ← this file (the schema)
├── raw/               ← immutable source documents (human adds, LLM reads only)
│   └── assets/        ← downloaded images and attachments
└── wiki/              ← everything the LLM writes and maintains
    ├── index.md       ← content catalog — read this first before every query
    ├── log.md         ← append-only operation history
    ├── overview.md    ← evolving synthesis / thesis across all sources
    ├── sources/       ← one summary page per ingested source
    ├── entities/      ← pages for named things (people, orgs, tools, papers)
    └── concepts/      ← pages for recurring ideas and themes
```

### Core operations

#### Ingest

When the human adds a new source or pastes content:

1. Read the source fully
2. Surface 2–3 key takeaways and discuss with the human; let them guide emphasis
3. Write `wiki/sources/<slug>.md` — a structured summary page (see Page Formats below)
4. Identify entities (people, organizations, tools, datasets, papers) mentioned in the source
   - If an entity page exists: update it with new information and a reference to this source
   - If no entity page exists yet: create `wiki/entities/<slug>.md`
5. Identify concepts (recurring themes, frameworks, arguments, techniques) that deserve pages
   - Same pattern: update or create `wiki/concepts/<slug>.md`
6. Update `wiki/overview.md` — revise the synthesis to incorporate this source; explicitly
   note if it confirms, contradicts, or extends prior claims
7. Update `wiki/index.md` — add the source entry, update counts in the header
8. Append to `wiki/log.md`: `## [YYYY-MM-DD] ingest | <source title>`

A single ingest typically touches 5–15 wiki pages. Work through all of them.

#### Query

When the human asks a question:

1. Read `wiki/index.md` to identify relevant pages
2. Read those pages
3. Synthesize an answer with citations linking to wiki pages (e.g., `[[entities/openai]]`)
4. If the answer is a valuable synthesis (comparison, analysis, discovered connection),
   offer to file it as a new wiki page — good answers shouldn't disappear into chat history

#### Lint

When the human asks for a health check:

1. Read `wiki/index.md` and all pages
2. Flag: contradictions between pages, orphan pages, missing cross-references, important
   concepts mentioned but lacking pages, data gaps a web search could fill
3. Produce a lint report with specific fixes
4. Offer to apply fixes automatically

### Page formats

#### Source summary page (`wiki/sources/<slug>.md`)

```markdown
---
title: <Source Title>
type: source
date_ingested: YYYY-MM-DD
source_type: article | paper | book | transcript | other
original_url: <url or file path>
tags: [tag1, tag2]
---

# <Source Title>

**Source:** <type> | **Date ingested:** YYYY-MM-DD | **Original:** <link>

## Summary
[2–4 paragraph summary. What is this? What does it argue or report?]

## Key points
- [Bulleted list of the most important claims, findings, or insights]

## Entities mentioned
- [[entities/entity-name]] — brief note on why they appear here
- ...

## Concepts covered
- [[concepts/concept-name]] — brief note
- ...

## Relation to existing knowledge
[How does this source relate to what the wiki already contains? Confirms, contradicts,
or extends prior sources? Note specific page names.]

## Notable quotes
> "[Exact quote]" — source, page/timestamp

## Open questions
[What questions does this source raise that the wiki doesn't yet answer?]
```

#### Entity page (`wiki/entities/<slug>.md`)

```markdown
---
title: <Entity Name>
type: entity
entity_type: person | organization | tool | dataset | paper | other
tags: []
---

# <Entity Name>

[1–2 sentence description: what is this and why does it appear in this wiki?]

## Key facts
- [Bulleted list of known facts, with source citations]

## Role in this domain
[How does this entity matter to the wiki's domain?]

## Sources that mention this
- [[sources/source-slug]] — brief note on what the source says about this entity
- ...

## Related entities
- [[entities/related-entity]] — relationship description
```

#### Concept page (`wiki/concepts/<slug>.md`)

```markdown
---
title: <Concept Name>
type: concept
tags: []
---

# <Concept Name>

[Definition or explanation. What is this concept?]

## How it appears in this domain
[How does this concept manifest in the sources you've ingested?]

## Key sources
- [[sources/source-slug]] — what this source says about the concept

## Tensions and open questions
[Where do sources disagree? What's unresolved?]

## Related concepts
- [[concepts/related-concept]] — relationship
```

### Index conventions

`wiki/index.md` has this structure:

```markdown
# Index

> Wiki: {{WIKI_NAME}} | Updated: YYYY-MM-DD | Sources: N | Pages: N

## Sources
| Title | Slug | Date | Type |
|-------|------|------|------|
| [Source Title](sources/slug.md) | slug | YYYY-MM-DD | article |

## Entities
- [Entity Name](entities/slug.md) — one-line description

## Concepts
- [Concept Name](concepts/slug.md) — one-line description

## Syntheses and analyses
- [Page Title](path/to/page.md) — one-line description
```

Update the header counts and add rows/entries on every ingest.

### Log conventions

`wiki/log.md` is append-only. Each entry:

```markdown
## [YYYY-MM-DD] operation | details
```

Operations: `setup`, `ingest`, `query`, `lint`

Entries are prepended (newest first) so recent history is visible without scrolling.

### Cross-reference style

Use wiki-style links: `[[entities/openai]]` or `[OpenAI](../entities/openai.md)`.
Always link entity and concept names on first mention within a page.

### Working rules

1. Never modify anything in `raw/` — it is the immutable source of truth
2. Always update `index.md` and `log.md` on every ingest
3. Cross-references are the point — a page with no links is a missed opportunity
4. File good answers back — if a query produces a valuable synthesis, create a wiki page
5. Note contradictions explicitly — don't silently overwrite; flag the tension
6. When asked "what does the wiki say about X", read the index first, then drill to pages
```
```

---

*End of template. The `llm-wiki` skill writes this to `<wiki-root>/CLAUDE.md` with placeholders filled.*
