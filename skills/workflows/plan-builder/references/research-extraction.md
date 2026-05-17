# Research Extraction

How to pull a plan out of research documents, Compass artifacts, PRDs, and reference material.

## Step 1: Synthesize Source Material

Read all provided artifacts. As you read, extract:

- **Content domains** — what topics does this material cover? (e.g., "voter registration law, demographic impact, legislative status, state-by-state analysis")
- **Natural sections** — how is the material organized? What are its structural boundaries?
- **Data points** — are there statistics, tables, comparisons, timelines, or other structured data?
- **Implied features** — what would a user of the finished product want to do with this information? (search it? compare states? check their own status?)
- **Content volume** — is this a single page of content or an entire site's worth?

## Step 2: Map Content to Architecture

This is the step most planning approaches miss. Research-heavy projects need *information architecture* before code architecture.

Think about how a human would navigate and consume this content:

- Which sections become distinct pages or views?
- What needs its own navigation entry vs. being a section within a page?
- Are there natural groupings (by topic, by audience, by geography)?
- Is there interactive potential? (calculators, filters, lookups, comparisons)
- What's the primary user journey through this content?

Produce a content map:

```text
Source Section → Application Component → User Purpose
"Demographics data" → Interactive checker tool → "Am I affected?"
"State-by-state analysis" → Filterable state grid → "What's happening in my state?"
"Legislative timeline" → Timeline component → "Where does this stand?"
```

## Step 3: Check Existing Codebase (Path A+ variant)

If working within an existing project (not a blank repo):

1. Read the project structure, package.json/requirements.txt, existing routes/pages
2. Identify where new content integrates — new pages? new section of existing page? new API endpoints?
3. Note existing conventions (framework, styling approach, data patterns) that the plan must follow
4. Flag any conflicts between existing architecture and what the new content requires

## Step 4: Confirm with User

Before writing the plan, present your content-to-architecture mapping and key decisions. Keep this concise — a short list, not an essay:

- "Here's how I'd organize the content: [content map]"
- "Tech stack recommendation: [X] because [reason]"
- "This would be [N] pages/components — does that feel right?"

Ask at most **3 clarifying questions** total across the entire process. If you need more, you're probably overthinking it — make a decision, note it as an assumption, and let the user correct you in the draft.
