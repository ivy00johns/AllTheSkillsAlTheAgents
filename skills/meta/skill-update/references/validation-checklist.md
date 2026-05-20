# Post-Edit Validation Checklist

Run this after every batch of edits — before the sync prompt — to catch broken skills before they reach the global skill locations.

## Per-File Checks

For every SKILL.md modified in the pass:

### Frontmatter

- [ ] YAML parses cleanly (no tab/space mix, no unclosed quotes)
- [ ] Field order matches house style: `name`, `version`, `description`, `compatibility`, `license`, `allowed-tools`, `metadata`, `requires_agent_teams`, `requires_claude_code`, `min_plan`, `owns`, `composes_with`, `spawned_by`
- [ ] `name` is kebab-case, ≤64 chars, unique across the ecosystem. `claude-*` / `anthropic-*` names are discouraged (reserved by Anthropic) but acceptable as a documented exception when the skill targets the corresponding Anthropic product.
- [ ] No `<` or `>` anywhere in the frontmatter block (security rule)
- [ ] `version` is valid semver — bump MINOR for new behavior, PATCH for fixes, MAJOR for breaks
- [ ] `description` includes at least one action verb and one trigger phrase
- [ ] `description` target ≤200 chars per the spec — flag overflow but don't block. Hard ceiling 1024 chars — block if exceeded.
- [ ] `compatibility` string (1-500 chars) present for skills with host/tool/env requirements
- [ ] `requires_agent_teams` and `requires_claude_code` are booleans
- [ ] `min_plan` is one of `starter | pro | team | enterprise`
- [ ] `owns.directories` does not overlap with any other agent role (see resolved-conflicts table in `skills/meta/skill-writer/references/frontmatter-spec.md`)
- [ ] `allowed-tools` (hyphen, canonical) only lists tools the skill actually uses. `allowed_tools` (underscore) still accepted as deprecated alias — note and migrate when convenient.
- [ ] `metadata` is a nested object if present (author, category, tags, mcp-server)
- [ ] `composes_with` references real skill names (or planned skills explicitly noted)
- [ ] `spawned_by` is empty unless the skill is genuinely spawned by another

Spec source: `skills/meta/skill-writer/references/frontmatter-spec.md`.

### Body

- [ ] Body ≤5,000 words (Anthropic guideline) — soft warning past this
- [ ] Body ≤500 lines (this repo's rule of thumb) — soft warning past this
- [ ] Heavy skills (`orchestrator`, `ui-ux-pro-max`, `repo-deep-dive`) may exceed both — note as accepted divergence
- [ ] Body under ~150 lines for SKILL.md files where references absorb the detail — the 100-line rule of thumb favors moving long tables and checklists out
- [ ] Imperative voice — "Read the file", not "the agent reads the file"
- [ ] No emojis (house style)
- [ ] No trailing whitespace
- [ ] All fenced code blocks declare a language
- [ ] All reference links resolve (`references/<file>.md` exists)
- [ ] All cross-skill links point at real skills
- [ ] No duplicate content between body and references

### Markdownlint

Run from repo root if a markdownlint binary is installed:

```bash
npx markdownlint-cli2 skills/<path>/SKILL.md
```

Config lives at `.markdownlint.json`. The repo disables MD013 (line length), MD036 (emphasis as heading), MD026 (trailing punctuation in headings), and MD060. Everything else is on.

If markdownlint is not installed, skip this step and note it in the validation report.

## Cross-File Checks

After all per-file checks:

- [ ] No two skills declare overlapping `owns.directories`
- [ ] Cross-skill references in `composes_with` and `spawned_by` are consistent in both directions where the relationship implies it (a `spawned_by: ["orchestrator"]` should match what `orchestrator` actually spawns)
- [ ] If a skill was renamed, all references to the old name across the repo were updated — search with `grep -rn "<old-name>" skills/`

## Reporting

Output the validation summary in this shape:

```markdown
## Validation Results
- Files modified: X
- Frontmatter valid: X/X
- Body line counts within limits: X/X
- Links resolved: X/X
- Ownership clean: yes/no
- Markdownlint: pass / fail / skipped

### Issues Found
- <file>: <issue> — suggested fix: <fix>
```

If anything fails, ask the user whether to fix now or leave for later — do not auto-fix without confirmation, since validation failures often surface real intent the plan missed.
