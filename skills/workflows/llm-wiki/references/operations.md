# Operations Reference

Detailed workflows for the three wiki operations: Ingest, Query, and Lint.

---

## Ingest

The core compounding operation. One source in → multiple wiki pages updated.

### Entry points

- User says "process this source" / "add this to the wiki" / "ingest this"
- User drops a file in `raw/` and mentions it
- User pastes article text or a URL directly into chat
- User asks you to process a source after Setup

### Step 1: Read and understand the source

Read the full source. If it's a URL, fetch it. If it's a file in `raw/`, read it.

For long sources (books, long reports):
- Read any abstract, introduction, and conclusion first to get the shape
- Then read key sections
- Note: images in markdown can't be read inline — note which images exist and offer to view them separately if they seem important

Extract:
- **Core argument or purpose** — what does this source claim or do?
- **Key entities** — people, organizations, tools, papers, datasets named
- **Key concepts** — recurring ideas, frameworks, techniques, arguments
- **Data points** — statistics, findings, quotes worth preserving
- **Tensions** — where does this source conflict with or challenge prior knowledge?

### Step 2: Surface takeaways and discuss

Tell the user the 2–3 most interesting or important things from the source. Ask:
- "Anything you want me to emphasize more?"
- "Anything I missed that matters to you?"

Keep this brief — one exchange, not a long back-and-forth. Then proceed.

### Step 3: Write the source summary page

Create `wiki/sources/<slug>.md` using the source page format from the wiki's CLAUDE.md.

Slug convention: `kebab-case-title` (e.g., `attention-is-all-you-need`, `anthropic-q3-safety-report-2025`)

For books being ingested chapter-by-chapter: create `wiki/sources/<book-slug>/` as a directory with a `_index.md` overview and one file per chapter. Update the book's `_index.md` with each new chapter.

### Step 4: Update entity pages

For each named entity (person, org, tool, paper, dataset) in the source:

1. Check if `wiki/entities/<slug>.md` exists
2. If yes: add a bullet to "Sources that mention this" and update "Key facts" if new info
3. If no: create the entity page using the entity page format from the wiki's CLAUDE.md

Priority: create entity pages for entities that are likely to appear in future sources. Don't create a page for a person mentioned once in passing.

### Step 5: Update concept pages

For each recurring concept, framework, or argument:

1. Check if `wiki/concepts/<slug>.md` exists
2. If yes: add to "Key sources" and update if the new source adds nuance or contradicts
3. If no: create the concept page

Good candidates for concept pages: things likely to appear across multiple sources. Skip one-off mentions.

### Step 6: Update overview.md

`wiki/overview.md` is the evolving synthesis — the "so what" of everything ingested so far.

After the first ingest, create it. After subsequent ingests, update it:
- Does this source reinforce the current thesis?
- Does it introduce a new dimension or nuance?
- Does it contradict something? Flag the tension explicitly:
  > ⚡ **Tension:** [Source A] argues X, but [Source B] argues Y. Currently unresolved.

Keep `overview.md` readable as a standalone document. It should represent your best current synthesis, not just a list of what's been ingested.

### Step 7: Update index.md

Add a row to the Sources table. Update the header counts (Sources: N, Pages: N).

If you created new entity or concept pages, add entries to those sections.

### Step 8: Append to log.md

Prepend to `wiki/log.md`:

```markdown
## [YYYY-MM-DD] ingest | <Source Title>

- Source type: article / paper / book chapter / transcript
- Pages touched: sources/slug, entities/name1, entities/name2, concepts/theme1, overview
- Key addition: [one sentence on what this source contributes]
- Tensions flagged: [any contradictions with existing content, or "none"]
```

### After ingest: tell the user

Summarize what was done:

> "Ingested: **[Source Title]**
> - Created: `sources/slug.md`
> - Updated: `entities/name1`, `concepts/theme`
> - New entities created: `name2`, `name3`
> - Overview updated: [one sentence on how the synthesis changed]
>
> Questions this raises: [1–2 open questions worth investigating]"

---

## Query

Answer questions using the wiki as the knowledge base.

### Entry points

- User asks a question about the domain
- User says "what does the wiki say about X"
- User wants a comparison, analysis, or synthesis

### Step 1: Read the index

Always start with `wiki/index.md`. Identify which pages are likely relevant.

For simple factual questions: the index alone often shows where to look.
For synthesis questions: you may need to read multiple pages.

### Step 2: Read relevant pages

Read entity pages, concept pages, and source summaries as needed.

For large wikis: use the index strategically — read page descriptions first, then drill to full content only for the most relevant pages.

### Step 3: Synthesize and cite

Write your answer. Citation style:

> "According to [[sources/paper-slug]], ... This is supported by [[entities/org-name]]'s position on ..."

Link to wiki pages, not raw sources. The wiki is the knowledge layer.

Acknowledge gaps honestly:
> "The wiki doesn't currently have coverage on X. The closest is [[concepts/related-thing]]. Worth ingesting [suggested source type] to fill this gap."

### Step 4: Offer to file the answer

If the answer involved non-trivial synthesis — comparing sources, discovering a connection, building a comparison table — offer to file it:

> "This comparison is worth keeping. Should I save it as `wiki/analyses/comparison-of-x-and-y.md`?"

File it if the user agrees. Add it to the index under "Syntheses and analyses."

---

## Lint

Health-check the wiki and surface maintenance work.

### Entry points

- User says "lint the wiki" / "health check" / "clean up the wiki" / "what's stale?"
- Periodic maintenance (suggest after every ~10 ingests)

### Step 1: Read the full wiki

Read `wiki/index.md` and then all pages listed in it.

For large wikis: do a targeted scan — read page headers and first paragraphs, drilling to full content only when a specific issue is suspected.

### Step 2: Check for issues

**Contradictions**
- Do any two pages make incompatible claims?
- Has a newer source superseded a claim in an older source page?
- Flag with: ⚡ Tension marker and both page links

**Orphan pages**
- Pages in `wiki/` that no other wiki page links to
- These are invisible to query mode navigation

**Missing concept pages**
- Concepts mentioned across 3+ pages that don't have their own page yet
- Entity names that appear frequently without a dedicated entity page

**Missing cross-references**
- Entity A is mentioned on page B but isn't linked
- Concept C is discussed in source D but the concept page doesn't list source D

**Data gaps**
- Questions the wiki should be able to answer but can't
- Topics where coverage is thin given the domain

**Stale overview**
- `wiki/overview.md` hasn't been updated after the last several ingests
- Claims in overview that newer sources have challenged

### Step 3: Produce lint report

Format:

```markdown
## Lint Report — [DATE]

### Contradictions (N)
- **[Topic]:** [[sources/a]] says X, but [[sources/b]] says Y. Suggested fix: update
  [[concepts/topic]] to flag the tension.

### Orphan pages (N)
- [[entities/name]] — not linked from any other page. Add links from [[sources/where-it-appears]].

### Missing pages (N)
- **[Concept]**: mentioned in [[sources/a]], [[sources/b]], [[sources/c]] — warrants its own page.

### Missing cross-references (N)
- [[sources/slug]]: mentions [[entities/name]] but doesn't link to it.

### Data gaps (N)
- No coverage on [topic]. Suggested next source type: [research paper / article / etc.]

### Stale content (N)
- [[wiki/overview]] hasn't reflected [[sources/recent-slug]] yet.
```

### Step 4: Offer to fix

For each category, offer:
> "I can fix the orphan links and missing cross-references automatically. The contradictions need your judgment — want to walk through them?"

Apply fixes the user approves. Add a lint entry to `wiki/log.md`:

```markdown
## [YYYY-MM-DD] lint | health check

- Issues found: N contradictions, N orphans, N missing pages, N missing xrefs
- Fixed automatically: orphan links, missing cross-references
- Pending human review: contradictions (see lint report)
```

---

## Tips for large wikis

Once the wiki grows past ~50 sources or ~200 pages:

- **Index navigation becomes critical** — keep it well-organized and current
- **Consider `qmd`** for search: a local hybrid BM25/vector search engine for markdown files with both a CLI and MCP server. Install from `github.com/tobi/qmd`. The LLM can shell out to it (`qmd search "query"`) instead of reading all pages.
- **Chapter-by-chapter book ingestion**: use `wiki/sources/<book>/` subdirectory pattern
- **Batch ingest**: for ingesting many sources at once with less supervision, run ingest for each source and defer the discussion step — useful for bootstrapping with an existing research archive
- **Dataview**: if using Obsidian, adding YAML frontmatter to pages (already in the templates) enables Dataview queries for dynamic tables by tag, date, or source count
