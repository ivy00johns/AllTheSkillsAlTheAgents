# Validation Script Pattern

Document for the "bundle a deterministic check script" pattern from Anthropic's guide (p.26, "Advanced technique"): when a skill's invariants can be expressed deterministically, bundle a script that checks them instead of relying on the model to validate in prose.

## What It Is

A skill bundles a script — typically `scripts/validate.sh` or `scripts/validate.py` — inside its folder that programmatically verifies the skill's invariants. The body of SKILL.md instructs the model to run the script before declaring the work done; the script exits non-zero on failure with an actionable message.

This shifts validation from "the model asserts the invariant holds" to "the script proves the invariant holds". The model is no longer the judge of its own work.

## When to Use It

Use a validation script when the invariant can be expressed deterministically:

- A specific file must exist at a specific path
- A JSON file must conform to a JSON Schema
- All required frontmatter fields must be present
- A forbidden pattern (e.g., `console.log`, hardcoded secrets, `TODO`) must not appear
- A file count or naming convention must hold
- A generated artifact must parse / compile / lint cleanly

These checks are cheap to write once and run in milliseconds, and they catch the exact class of error where prose validation has been observed to be inconsistent.

## When NOT to Use It

Skip the script when the check is a judgment call:

- "Is the description clear?"
- "Is this instruction well-written?"
- "Is this design good?"
- "Does this code feel idiomatic?"

Also skip it when the check changes faster than the skill's intent — a script that needs editing every other run is just friction with extra steps.

## In-Repo Example

`skills/contracts/contract-auditor` uses this pattern. It bundles validation logic that programmatically verifies a generated contract (OpenAPI, AsyncAPI, Pydantic, TypeScript, JSON Schema) parses, type-checks, and conforms to the spec — rather than asking the model to read the contract and "check it looks right". Review its layout when designing your own validation script.

## Skeleton

Folder layout:

```text
skill-name/
├── SKILL.md
└── scripts/
    └── validate.sh
```

In the SKILL.md body, link the script from the workflow steps and from the validation section:

```markdown
## Validation

Before declaring done, run:

\`\`\`bash
scripts/validate.sh
\`\`\`

The script exits 0 on success and non-zero with an actionable error on failure. If it fails, fix the underlying issue and re-run — do NOT suppress or work around the script.
```

Keep the script's output terse and actionable: one line per failure, formatted as `path:line: problem` so the model can jump straight to the fix.

## Failure Handling

The contract with the model is one-way:

- Script exits 0 → skill may declare done
- Script exits non-zero → skill must read the error, fix the underlying issue, and re-run the script

Explicitly forbid the model from suppressing the script, commenting it out, or marking the work complete despite a failure. The whole point of the pattern is that the script is the source of truth — letting the model overrule it returns you to prose-based validation with extra ceremony.

If a check genuinely is too strict for a legitimate edge case, the fix is to update the script (so future runs benefit), not to skip it.
