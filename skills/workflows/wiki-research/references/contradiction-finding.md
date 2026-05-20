# Contradiction-Finding Discipline

A heuristic for surfacing where sources actually disagree when synthesizing research from multiple sources. Most research synthesis flattens contradictions into consensus prose; this discipline forces the conflicts to stay visible.

## When to Use

Invoke during wiki-research synthesis whenever you have **3 or more sources on the same topic** and you are about to write a summary, an overview page, or a comparison entry.

Skip for single-source notes, raw transcripts, or pages that simply restate one document — there is nothing to triangulate.

## The 5-Step Process

Work through these in order. Each step has a target output size — resist expanding them. The discipline is in the compression.

### 1. Surface consensus (1 sentence)

State the one thing most sources agree on. If you can't compress it to a sentence, you don't actually have consensus — you have a vague topic.

### 2. Name contradictions (3 bullets)

Identify the three sharpest places where sources, data points, or arguments conflict. For each, name **both sides** with a short quote or paraphrase attributed to its source. No generalities — show the disagreement on the page.

### 3. The weakest claim (1 bullet)

Pick the single statement in the material with the least support and the highest chance of being wrong. This is often a confident assertion repeated by one source and echoed by others without verification.

### 4. The real debate (1 paragraph)

Describe what experts actually disagree on — the unresolved question underneath the surface dispute. The surface dispute is usually "is X good or bad"; the real debate is usually "what should we measure to decide, and whose interests does each measure serve?"

### 5. Confidence verdict (1 sentence)

Given the contradictions you surfaced, how confident should the reader be in the overall summary? Pick one: *high confidence*, *medium confidence — load-bearing claims contested*, or *low confidence — the field is unsettled*.

## Worked Example

Synthesizing 4 sources on whether the Bun runtime is production-ready:

1. **Consensus:** Bun is significantly faster than Node for startup and most I/O benchmarks.
2. **Contradictions:**
   - Source A (vendor benchmark) reports "3x faster than Node in production workloads"; Source C (independent benchmark on real apps) reports "1.2–1.6x faster, sometimes slower under memory pressure."
   - Source B claims "full Node.js API compatibility"; Source D documents 14 native modules that still crash or silently misbehave.
   - Sources A and B treat the test runner as ready; Source C calls it "missing the long tail of Jest features teams actually depend on."
3. **Weakest claim:** "Full Node.js API compatibility" — repeated everywhere, contradicted by Source D's specific failure list.
4. **Real debate:** Not "is Bun fast" (it is) but "is Bun's compatibility surface stable enough that adopting it does not become a permanent migration tax." Performance is settled; the operational risk of edge-case incompatibility is not.
5. **Verdict:** Medium confidence — the speed claims hold up, the compatibility claims do not, and the gap matters for any non-trivial Node port.

## Anti-Patterns

| Anti-Pattern | Why It Fails |
|---|---|
| Smoothing over conflicts ("sources broadly agree…") | Erases the most useful signal in the research; the disagreements are where understanding lives |
| Strawman contradictions | Manufacturing disagreement between sources that actually agree just to fill the bullets — readers detect this immediately |
| "More research is needed" as the real debate | Cop-out. The real debate is a *specific unresolved question*, not a generic request for more sources |
| Burying the weakest claim in a footnote | If a claim is load-bearing and shaky, it belongs in the body so downstream readers don't build on it |
| Listing every minor difference as a contradiction | Three sharp conflicts beat ten trivial ones; the discipline is selection, not enumeration |
