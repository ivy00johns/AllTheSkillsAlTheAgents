# Contract: Lint Rules

**Build:** Multi-Tool Installer (Slice A)
**Version:** 1.1.0
**Owner:** orchestrator (authored Phase 4)
**Consumed by:** scripts-agent (lint-skills.sh), infrastructure-agent (CI workflow), qe-agent (lint test fixtures)

**Changelog:**
- 1.1.0 — Demoted `description` length checks from ERROR to WARN at every threshold. Reason: `CLAUDE.md` explicitly endorses "pushy" descriptions that over-enumerate trigger contexts to combat under-triggering. Hard ERROR-on-length conflicted with the ecosystem's intentional design. Length is now a quality signal, not a CI gate.

## Purpose

Defines what `scripts/lint-skills.sh` validates against every `skills/**/SKILL.md`. The lint script is the CI gate — failures block PR merges via `.github/workflows/lint-skills.yml`.

The canonical frontmatter spec is at `skills/meta/skill-writer/references/frontmatter-spec.md`. This contract translates that spec into machine-checkable rules.

## Severity Levels

- **ERROR** — exit code 1, blocks CI. Skill is malformed in a way that breaks tooling.
- **WARN** — exit code 0 (does NOT block CI), printed to stderr. Skill is valid but suboptimal.
- **INFO** — exit code 0, printed only with `--verbose`.

## Required Frontmatter (ERROR if missing)

| Field | Validation |
|---|---|
| `name` | present, non-empty, kebab-case (`^[a-z][a-z0-9-]*$`), ≤64 chars, equals the parent directory name |
| `version` | present, valid semver (`^\d+\.\d+\.\d+$`) |
| `description` | present, non-empty (length WARN-only — see below) |

The `name` MUST match the directory name. Mismatch is ERROR — both `/sync-skills` symlinks and the converter rely on this invariant.

## Recommended Frontmatter (WARN if missing on agent role skills)

Applied only to skills under `skills/roles/`:

| Field | Reason |
|---|---|
| `owns.directories` | Agent roles need exclusive ownership for orchestrated builds |
| `allowed_tools` | Tool whitelist prevents agents reaching outside their domain |

Applied to all skills:

| Field | Reason |
|---|---|
| `composes_with` | Helps the orchestrator understand skill relationships |

## Cross-Skill Validation (ERROR)

These checks require reading multiple skills:

| Check | Severity |
|---|---|
| `name` is unique across the ecosystem | ERROR (collision) |
| `owns.directories` between two agent role skills do not overlap (resolution rules in `frontmatter-spec.md` § Ownership Resolution apply) | ERROR (conflict) |
| Every name in `composes_with` resolves to an existing skill | WARN (broken reference) |
| Every name in `spawned_by` resolves to an existing skill | WARN (broken reference) |

## Body Validation

| Check | Severity |
|---|---|
| Body present (≥1 non-frontmatter line) | ERROR |
| Body word count ≥50 | WARN (likely a stub) |
| Body line count ≤500 | WARN (progressive disclosure violated; move detail to `references/`) |

## Description Length (WARN)

Length thresholds are advisory. The `CLAUDE.md` design philosophy intentionally favors "pushy" descriptions that enumerate trigger contexts. Use these as soft guides:

- ≤200 chars — clean (no warning)
- 200–500 chars — WARN, soft target exceeded but acceptable for pushy triggering
- >500 chars — WARN, consider whether some trigger context belongs in the body or references

No description length is ever an ERROR — only missing/empty `description` fails the gate.

## Description Quality (WARN)

The description is the trigger mechanism. Heuristics:

- Starts with an action verb (presence of an imperative-mood word in the first 5 words: `use`, `apply`, `generate`, `validate`, `coordinate`, `author`, `review`, `audit`, `create`, `build`, `analyze`, `check`, `extract`, `prepare`, `design`, `manage`, `track`, `convert`, `install`, `lint`, `fix`, `refactor`, `test`, etc.) — the list is illustrative, not exhaustive
- Mentions ≥1 trigger context (heuristic: ≥1 occurrence of `when`, `for`, `whenever`, `if`)

These are heuristics — false negatives WARN, never ERROR.

## YAML Wellformedness (ERROR)

- The first non-blank line MUST be `---`
- A second `---` MUST close the block within 100 lines
- The block MUST parse as YAML (use a portable parser; suggested: `python3 -c "import yaml; yaml.safe_load(...)"` if `python3` is available, else a hand-rolled key-value parser limited to the documented schema)

If `python3` is not available and a multi-line value is encountered that the hand-rolled parser cannot handle, fall back to ERROR with a clear message: `install python3 for full YAML validation`.

## CLI Contract

```
Usage: scripts/lint-skills.sh [OPTIONS] [PATH ...]

Options:
  --quiet            Suppress WARN output
  --verbose          Show INFO output
  --fix-trivial      Auto-fix trivial issues (e.g., trailing whitespace) — interactive prompt before each fix
  --format FORMAT    Output format: text (default) or junit (for CI consumption)
  --help             Print this and exit

If no PATH given, lints all skills/**/SKILL.md.
PATH may be a directory (recurse) or an individual SKILL.md.

Exit codes:
  0 — no errors (warnings allowed)
  1 — at least one error
  2 — argument parsing failure
```

## Output Format (text)

```
Linting 38 skills...

ERROR  skills/roles/backend-agent/SKILL.md:2  name 'backend' does not match directory 'backend-agent'
WARN   skills/workflows/ui-brief/SKILL.md     description is 215 chars (target ≤200)
WARN   skills/meta/skill-audit/SKILL.md       composes_with references unknown skill 'skill-deepreview' (did you mean 'skill-deep-review'?)

Results: 1 error, 2 warnings across 38 skills.
FAILED: fix the errors above before merging.
```

Errors include file path, line number when available, and a single-sentence message. Warnings same format.

## Output Format (junit)

For CI: emit a JUnit XML report to stdout, suitable for GitHub Actions test result rendering.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="skill-lint" tests="38" failures="1" errors="0">
  <testsuite name="skills/roles/backend-agent" tests="1" failures="1">
    <testcase classname="frontmatter" name="name-matches-directory">
      <failure message="name 'backend' does not match directory 'backend-agent'"/>
    </testcase>
  </testsuite>
  ...
</testsuites>
```

## Self-Test

`lint-skills.sh` MUST lint all 38 current skills cleanly when first committed. The implementation agent MUST run it against `skills/` before reporting done — any pre-existing ERROR in a current skill is a finding that gets fixed (in a separate commit on the same branch) or escalated to the orchestrator.

## CI Integration

The infrastructure-agent owns `.github/workflows/lint-skills.yml`. The workflow:

- Triggers on `push` to any branch and `pull_request` to `main`
- Runs `scripts/lint-skills.sh --format junit > lint-results.xml || true`
- Uploads `lint-results.xml` as an artifact
- Fails the job if `scripts/lint-skills.sh` exits non-zero
- Targets `ubuntu-latest` (bash 4+ available) and runs on macOS-latest as a smoke check (bash 3.2)
