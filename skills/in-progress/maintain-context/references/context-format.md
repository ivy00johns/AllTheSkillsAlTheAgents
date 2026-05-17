# CONTEXT.md format

`CONTEXT.md` is a domain glossary, nothing else. One file at the repo root. Entries are alphabetized within each section. New contributors should be able to read it top-to-bottom in under five minutes and walk away knowing how this project talks about itself.

## File structure

```markdown
# CONTEXT

Domain vocabulary for <project>. When writing code, comments, commits, PRs, or docs in this repo, use these terms exactly as defined. Synonyms listed under `_Avoid_:` are forbidden — they mean something else here, or they're ambiguous.

## Domain terms

<entries alphabetized>

## Service-level terms

<entries alphabetized>

## Deprecated aliases

<terms that used to mean something and now don't — kept here so old PRs and tickets remain readable>
```

## Header conventions

- Each term is an `## H2` heading, exact canonical casing (e.g. `## Subscriber`, not `## subscriber` or `## Subscribers`).
- Sections are `## H2` for term groups (`Domain terms`, `Service-level terms`, `Deprecated aliases`). If your project has only one group, drop the section headers and keep entries flat.
- No `### H3` inside an entry. If you need subheadings, the entry is doing too much — split it.

## Entry shape

```markdown
## <Term>
<One-sentence canonical definition. Reference the data shape or code location if there is one.>
_Avoid_: <synonym> (<one-clause reason>), <synonym> (<one-clause reason>).
```

The `_Avoid_:` line is mandatory. If you can't think of a forbidden synonym, the term probably doesn't need a glossary entry — nobody is going to say the wrong word.

## Worked examples

### A domain term

```markdown
## Subscriber
A customer record with `subscription_status = active` in `users` table. Has access to paid features and counts toward MRR.
_Avoid_: user (too generic — every row in `users` is a user, but most aren't subscribers), member (legacy term from v1 community feature), client (means a B2B account in marketing copy).
```

### A service-level term

```markdown
## Ingestion
The pipeline that pulls events from Kafka, validates against the schema registry, and writes to ClickHouse. Owned by the `ingestion` service in `services/ingestion/`.
_Avoid_: pipeline (too generic — we have three), ETL (we don't transform; validation is not transformation), stream processor (Flink is the stream processor; ingestion is the consumer).
```

### A deprecated alias

```markdown
## Workspace (deprecated)
Old term for what is now called **Organization**. Kept here because issues #200–#480 and the `workspaces` URL prefix in v1 API still reference it. Do not introduce new uses.
_Avoid_: using this in new code, docs, or commits. If you find it in an existing file you're editing, rename it as part of the change.
```

## What does NOT go in CONTEXT.md

- API endpoint lists → OpenAPI / README
- Runbooks → `docs/runbooks/`
- Architecture overviews → `ARCHITECTURE.md` or `docs/architecture/`
- TODOs, scratch notes → not this file, not any file in the repo
- Implementation notes → code comments

If a contributor asks "how does X work?", the glossary should tell them what to call X, then point them to the real document. The glossary is an index of vocabulary, not a manual.
