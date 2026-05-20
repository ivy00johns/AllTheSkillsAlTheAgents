# Performance Notes Pattern

Document for the `## Performance Notes` body section described in Anthropic's guide (p.26): an explicit-encouragement block that combats model laziness on long-running or validation-heavy skills.

## What It Is

A short body section, placed near the top of the SKILL.md instructions, that explicitly tells Claude to slow down, prioritize quality over speed, and not skip validation. It exists because the model's default optimization pressure is toward token efficiency — which sometimes manifests as cutting corners on the very tasks where corner-cutting is most costly.

## When to Use It

Use it on:

- Long-running role agents (backend-agent, frontend-agent, qe-agent, security-agent) where the cost of a missed step is high
- Validation-heavy skills (code-review, contract-auditor, security-review)
- Skills where you've **observed** the model cutting corners in prior runs — taking shortcuts, skipping the validation checklist, marking work complete without running tests

Do NOT use it on:

- Fast-response utility skills (git-commit, skill-explorer recall mode) — the encouragement to slow down works against the intended fast response
- Skills where there is no observable corner-cutting problem — paranoid prophylactic use dilutes the signal across the ecosystem

## The Pattern

```markdown
## Performance Notes

- Take your time to do this thoroughly
- Quality is more important than speed
- Do not skip validation steps
- [Add one or two domain-specific encouragements — e.g., "Run the full test suite, not a subset", "Read every file you claim to have reviewed", "Verify each contract field individually"]
```

Place this section near the top of the body — directly under the role/intro paragraph and before `## Instructions` — so it loads with the highest weight.

## Why It Works

The body of a triggered skill loads into the model's working context with high prominence. Explicit, plainly-worded instructions in that context counterweight the default token-efficiency pressure. The bullets are intentionally simple — "Take your time", "Quality over speed" — because subtle instructions get pattern-matched into the noise.

The domain-specific bullet is the load-bearing one. Generic "be careful" instructions plateau quickly; "run the full test suite, not a subset" or "verify each contract field individually" name the specific corner that was being cut.

## Anti-Pattern: Paranoid Adoption

Adding `## Performance Notes` to every skill regardless of need is the most common failure mode. Three reasons it backfires:

1. **Signal dilution** — when every skill says "take your time", the model stops weighing the instruction. It becomes part of the boilerplate the model skims past.
2. **Conflicts with fast-response skills** — telling `git-commit` or `skill-explorer` to "take its time" produces noticeably worse UX with no quality benefit.
3. **Hides where the real problem is** — when every skill has the same prophylactic block, you can't tell which skills actually had a quality issue worth fixing.

The right discipline: add this section when you have observed a specific corner-cutting failure, name the failure in the domain-specific bullet, and remove the section if a later version of the model stops exhibiting the problem.
