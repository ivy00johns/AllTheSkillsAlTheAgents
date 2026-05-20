# Audit: sync-skills

**Path:** skills/workflows/sync-skills/SKILL.md
**Version:** 2.0.0
**Category:** workflows
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 3 | All required fields present and well-formed; semver 2.0.0; no `<`/`>` in field values; `allowed-tools` hyphenated. **However, `composes_with: ["skill-updater", "skill-audit"]` (line 14) references TWO skills that do not exist.** The actual skills are `skill-update` and `skill-review` (verified by `ls skills/meta/`). This is a FAIL-grade broken reference per the audit checklist. |
| Description quality | 5 | 565 chars. Starts with action verb "Sync". 10+ explicit trigger phrases including the slash-command form `/sync-skills`. Covers symlinks vs copies, status checks, unlinking — full lifecycle. |
| Progressive disclosure | 4 | Body 136 lines / ~1100 words — within guidelines. No `references/` directory, instead a `scripts/` directory with the implementation. The body itself is the reference (mode descriptions, flag table, examples). Slightly heavy — the flag table + how-it-works could move to `references/cli-reference.md` to drop the body under 100 lines, but the current layout is defensible since the skill IS a CLI wrapper. |
| Instruction clarity | 5 | Imperative voice throughout. Clear modes (Link / Copy / Pull) with use cases. Excellent Quick Reference block with copy-paste commands. Flag table is crisp. Explains WHY behind flattened symlinks for Claude Code ("required because Claude Code only discovers skills at `~/.claude/skills/<skill-name>/SKILL.md`"). |
| Coordination | 2 | `composes_with` lists two non-existent skills. `owns.directories: ["skills/workflows/sync-skills/"]` is fine — self-contained. `shared_read: ["skills/"]` is accurate. But the broken composes_with prevents future auto-composition or cross-link rendering from working. |
| Completeness | 5 | The implementation script `scripts/sync-skills.sh` exists. All described modes have flag table entries. Quick Reference shows 9 worked examples. Status detection, broken-symlink handling, and non-repo-skills safety all documented. |
| Anti-patterns | 5 | No hardcoded user paths beyond conventional `~/.claude/` and `~/.cursor/`. No MUST/NEVER abuse. No duplicate content between body and scripts/. The body cross-references `scripts/sync-skills.sh:SKIP_CATEGORIES` for the exclusion list (line 39) — proper progressive disclosure to code. |

**Average:** 4.14

## Findings

### Critical (must fix to ship)
- Broken `composes_with` cross-references. — `skills/workflows/sync-skills/SKILL.md:14` — `composes_with: ["skill-updater", "skill-audit"]` references skills that do not exist. The repo's actual skill names are `skill-update` and `skill-review` (under `skills/meta/`). Per the audit checklist, "Cross-skill links pointing at nonexistent skills" is a FAIL. Fix: change to `composes_with: ["skill-update", "skill-review"]`.

### Important (should fix)
- None beyond the critical broken refs.

### Nits (won't block ship)
- The skill has a `scripts/` directory but no `references/` directory. Consider whether the flag table + How-It-Works section (lines 94-126) could move to `references/cli-reference.md` to drop the body below 100 lines. Not required — current layout is defensible.
- Line 30 says Cursor uses category-level symlinks while Claude Code uses flattened ones, but the rationale "because Claude Code only discovers skills at `~/.claude/skills/<skill-name>/SKILL.md`" is duplicated in lines 30 and 77. Could be stated once.
- "Cursor (global) | `~/.cursor/skills-cursor/`" on line 28 — the directory name `skills-cursor` is a bit awkward; if it can be `~/.cursor/skills/` to match Claude Code, the body should mention why it's `skills-cursor` instead.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Fix broken `composes_with` references (CRITICAL). — `skills/workflows/sync-skills/SKILL.md:14` — change `composes_with: ["skill-updater", "skill-audit"]` to `composes_with: ["skill-update", "skill-review"]` (the two skills that actually exist and are conceptually relevant). effort: small.
2. Remove duplicated rationale for flattened Claude Code symlinks. — `skills/workflows/sync-skills/SKILL.md:30,77` — keep the explanation in §"Link Mode" (line 77) where it's most contextual; trim line 30 to "For Claude Code, symlinks are **flattened** (see Link Mode for why)." effort: small.
3. Add a brief note explaining the `skills-cursor` vs `skills` directory-name choice. — `skills/workflows/sync-skills/SKILL.md:28` — one-line footnote: "Cursor expects `skills-cursor/` to avoid collision with its native `skills/` registry." (Verify this rationale is correct before writing.) effort: small.

## Dead links / broken references
- `composes_with: ["skill-updater", "skill-audit"]` — BOTH are broken. Correct names are `skill-update` and `skill-review`. (skill-updater and skill-audit don't exist; verified via `ls skills/meta/`.)
- `scripts/sync-skills.sh` referenced from body — exists.
