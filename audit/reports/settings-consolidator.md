# Audit: settings-consolidator

**Path:** skills/workflows/settings-consolidator/SKILL.md
**Version:** 1.2.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields present; semver 1.2.0; no `<`/`>` in field values (the `>` on line 4 is a YAML block scalar marker). `allowed-tools` hyphenated. `composes_with: ["sync-skills"]` — sync-skills exists. `owns.patterns: ["settings.local.json"]` and `shared_read` reasonable for a settings tool. |
| Description quality | 5 | 1011 chars (very close to 1024 ceiling but under). Starts with action verb "Scan". 10+ trigger contexts/keyword variants ("stop prompting me", "bootstrap permissions", "autonomous mode", "I want to go to sleep and let this run", "unattended session", colon-wildcards/space-wildcards). Pushy and comprehensive. |
| Progressive disclosure | 5 | Body 118 lines / ~1100 words — well within guidelines. Two reference .md files (permission-categories 85 lines, safety-deny-list 75 lines) plus a JSON baseline (autonomous-permissions.json) — all linked from body with explicit "when to read" guidance (e.g., line 100 "See `references/permission-categories.md` for the full rule sets"). |
| Instruction clarity | 5 | Imperative voice throughout. Two-mode structure (Bootstrap mode for autonomous, Consolidation mode for merging) clearly separated. Six-step consolidation workflow numbered with rationale. Bootstrap workflow has six numbered steps. Explains WHY ("This is the safer interpretation of conflicting sources"). |
| Coordination | 5 | `composes_with: ["sync-skills"]` accurate (both manage `~/.claude/`). Non-agent skill so no ownership conflicts; `owns.patterns: ["settings.local.json"]` is meaningful and doesn't conflict with any agent role. |
| Completeness | 5 | All three referenced files exist on disk: `permission-categories.md` (85 lines), `safety-deny-list.md` (75 lines), `autonomous-permissions.json` (9 KiB). All linked from body. Six-step consolidation workflow + six-step bootstrap workflow = complete coverage. Edge cases enumerated in `safety-deny-list.md:60-68`. |
| Anti-patterns | 4 | One minor: description is at 1011 chars (very close to 1024 hard ceiling) — risky if any future text edit pushes it over. No hardcoded project details (uses `~/.claude/` and YYYY-MM-DD placeholders). No MUST/NEVER abuse. Body and references don't duplicate — body summarizes mechanics, references hold the rule tables. |

**Average:** 4.86

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description is 1011 chars — only 13 chars under the 1024 hard ceiling. Any future edit risks pushing it over and triggering FAIL. Recommend tightening to ≤800 chars by collapsing the "Use this skill whenever" sentence (line 9-14) and the "Also trigger" sentence (line 15-16) into one. — `skills/workflows/settings-consolidator/SKILL.md:4-16`.

### Nits (won't block ship)
- Body line 116 lists `references/autonomous-permissions.json` in the reference files section but the file is a JSON template, not a markdown reference — consider noting this in the section header to set reader expectation (currently fine, just a presentation nit).
- `references/permission-categories.md` uses escaped asterisks (`\*\*`) in the markdown table on lines 25-43 — works in rendered markdown but visually noisy in raw form. Minor.
- Body line 35 says "use this workflow instead of (or before) the consolidation workflow" — clearer as "use the bootstrap workflow first, then optionally consolidate" to remove the parenthetical ambiguity.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Tighten description to ≤800 chars to give breathing room under the 1024 ceiling. — `skills/workflows/settings-consolidator/SKILL.md:4-16` — collapse the two trigger sentences (one starts "Use this skill whenever the user mentions...", the other "Also trigger when users want..."), drop redundant keyword duplicates like "consolidating settings/merging permissions/scanning settings/deduping permissions/compiling settings" which all mean the same thing. effort: small.
2. Reword the "instead of (or before)" parenthetical for clarity. — `skills/workflows/settings-consolidator/SKILL.md:35` — change to "Run the bootstrap workflow first; consolidation can follow on top of it." effort: small.
3. Annotate the JSON reference more clearly in the reference files list. — `skills/workflows/settings-consolidator/SKILL.md:116` — prefix entry with "(template, not docs)" or move it under a separate "Templates" heading. effort: small.

## Dead links / broken references
- None. All three references (`permission-categories.md`, `safety-deny-list.md`, `autonomous-permissions.json`) exist. `composes_with` target `sync-skills` exists in `skills/workflows/sync-skills/`.
