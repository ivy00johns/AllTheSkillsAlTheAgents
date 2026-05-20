# Frontmatter Specification

Canonical reference for all SKILL.md frontmatter fields in the skill ecosystem.

This spec aligns with Anthropic's official Agent Skills frontmatter standard while adding fields specific to multi-agent orchestration (`owns`, `composes_with`, `spawned_by`, `requires_*`, `min_plan`). Skills written to this spec load correctly on Claude Code, Claude.ai, Claude Desktop, and the Agent SDK — the multi-agent extensions are ignored safely by parsers that don't understand them.

## Quick Reference

```yaml
---
name: my-skill                           # required, kebab-case
version: 1.0.0                           # required, semver (top-level)
description: |                           # required, ≤200 char target, 1024 char ceiling
  [What it does]. Use this skill when [when to use].
  [Key capabilities or keyword variants].

# Optional — Anthropic spec
compatibility: "Claude Code or Claude.ai; requires Bash + WebFetch"
license: MIT
allowed-tools: ["Read", "Edit", "Bash"]  # hyphen is canonical
metadata:
  author: your-name
  category: workflows
  tags: [planning, multi-agent]

# Optional — this repo's multi-agent extensions
requires_agent_teams: false
requires_claude_code: false
min_plan: starter
owns:
  directories: ["src/api/"]
  patterns: ["Dockerfile*"]
  shared_read: ["contracts/"]
composes_with: ["contract-author"]
spawned_by: ["orchestrator"]
---
```

## Required Fields

### name

- **Type:** string
- **Format:** kebab-case (lowercase, hyphens). No spaces, no capitals, no underscores.
- **Max length:** 64 characters
- **Reserved prefixes:** must not start with `claude-` or `anthropic-` — reserved by Anthropic for first-party skills
- **Must match** the skill folder name
- **Must be unique** across the ecosystem
- **Examples:** `backend-agent`, `contract-author`, `skill-writer`

### version

- **Type:** string
- **Format:** Semantic versioning (`MAJOR.MINOR.PATCH`) — e.g., `1.0.0`, `1.2.3`
- **Position:** top-level (this repo's canonical form). Anthropic's spec also allows `version` nested under `metadata`; both are accepted, but top-level is preferred here so the semver is visible at a glance.
- **Convention:** Start at `1.0.0`. Bump MINOR for features, PATCH for fixes, MAJOR for breaking changes.

### description

- **Type:** string (multiline YAML via `|` is fine)
- **Target length:** ≤200 characters — forces tight, scannable triggers
- **Hard ceiling:** 1024 characters (Anthropic spec maximum)
- **Anatomy:** `[What it does] + [When to use it] + [Key capabilities or keyword variants]`
- **Style:** "Pushy" — enumerate specific trigger contexts and keyword variants users might actually say
- **Forbidden:** XML angle brackets (`<`, `>`) — frontmatter loads into Claude's system prompt and could be used for prompt injection
- **Purpose:** Primary trigger mechanism. Claude reads this to decide whether to invoke the skill.

See `description-patterns.md` for templates and worked examples.

## Optional Fields — Anthropic Spec

### compatibility

- **Type:** string
- **Length:** 1–500 characters
- **Purpose:** Human-readable declaration of environment requirements: intended host (Claude Code, Claude.ai, API), required system packages, network access, MCP servers, etc.
- **Cross-platform parsers use this string.** For programmatic runtime gating, use the `requires_*` booleans below.
- **Example:** `"Claude Code only; requires Bash + WebFetch tools and a clean git working tree"`

### license

- **Type:** string
- **Purpose:** Per-skill license override. Usually unnecessary for skills shipped in this repo — the repo-level LICENSE applies.
- **Examples:** `MIT`, `Apache-2.0`

### allowed-tools

- **Type:** string[]
- **Canonical form:** `allowed-tools` (hyphen — matches Anthropic spec)
- **Deprecated alias:** `allowed_tools` (underscore) is still accepted for back-compat; new skills should use the hyphenated form
- **Purpose:** Whitelist of tools the skill may invoke. Cross-platform parsers respect this.
- **Example:** `["Read", "Edit", "Bash", "WebFetch"]`

### metadata

- **Type:** object (free-form key/value)
- **Purpose:** Attribution, cataloging, and integration metadata
- **Common subfields:**
  - `author` — skill author or team
  - `category` — e.g., `workflows`, `roles`, `meta`, `git`, `contracts`
  - `tags` — list of discovery keywords
  - `mcp-server` — name of the MCP server this skill enhances, if any
  - `documentation` — URL to extended docs
  - `support` — contact for issues
- **Example:**

  ```yaml
  metadata:
    author: ivy00johns
    category: workflows
    tags: [planning, multi-agent]
  ```

## Optional Fields — Multi-Agent Extensions

This repo's extensions for orchestrated builds. Not part of Anthropic's spec; parsers that don't understand them ignore them safely.

### requires_agent_teams

- **Type:** boolean
- **Default:** false
- **Purpose:** Set true if skill requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

### requires_claude_code

- **Type:** boolean
- **Default:** false
- **Purpose:** Set true if skill requires Claude Code CLI (bash, filesystem access)

### min_plan

- **Type:** enum (`starter` | `pro` | `team` | `enterprise`)
- **Default:** `starter`

### owns (agent role skills only)

#### owns.directories

- **Type:** string[]
- **Purpose:** Directories this agent owns exclusively
- **Example:** `["src/api/", "src/services/", "src/models/"]`

#### owns.patterns

- **Type:** string[] (glob patterns)
- **Purpose:** File patterns this agent owns
- **Example:** `["Dockerfile*", "docker-compose*"]`

#### owns.shared_read

- **Type:** string[]
- **Purpose:** Directories this agent reads but doesn't own
- **Example:** `["contracts/", "shared/", "src/types/"]`

### composes_with

- **Type:** string[]
- **Purpose:** Other skill names this naturally works with (informational)

### spawned_by

- **Type:** string[]
- **Purpose:** Which skills spawn this one

## Forbidden in Frontmatter

These rules come from Anthropic's spec. `skill-review` enforces them.

- **XML angle brackets `<` and `>`** anywhere in the frontmatter — security risk, since frontmatter loads into Claude's system prompt
- **Names starting with `claude-` or `anthropic-`** — reserved by Anthropic for first-party skills
- **Code execution in YAML** — parsers use safe-YAML; tagged Python objects and similar constructs will fail to parse

## Body Length Guidance

- **Guideline:** SKILL.md body ≤ 5,000 words (Anthropic recommendation)
- **Soft warning** at 500 lines OR 5,000 words — `skill-review` flags and suggests moving content to `references/`
- **No hard gate.** Heavy skills (`orchestrator`, `ui-ux-pro-max`, `repo-deep-dive`) deliberately exceed the guideline because their body needs to load atomically. Trade-off accepted.
- Content moved to `references/` is loaded on demand — the third level of progressive disclosure.

## Field Decisions

| Field | Decision | Rationale |
|-------|----------|-----------|
| `version` (top-level) | Required | Semver visibility; Anthropic also allows `metadata.version` but top-level is canonical here |
| `description` ≤200 char target | Soft guidance | Forces concise triggers; 1024 is the hard ceiling per Anthropic spec |
| `allowed-tools` (hyphen) | Canonical from this version | Aligns with Anthropic spec; `allowed_tools` accepted as deprecated alias |
| `compatibility` | Added | Cross-platform parsers use this string; `requires_*` booleans complement for programmatic gating |
| `metadata` | Adopted (optional) | Free-form attribution; nested form matches Anthropic spec |
| `requires_agent_teams` | Explicit boolean | Native teams need env var; skills must declare this for runtime gating |
| `requires_claude_code` | Explicit boolean | Some skills are CLI-only; users need to know |
| `owns.directories` | Enforced by orchestrator | Core to zero-conflict parallel builds |
| `owns.patterns` | Glob-based | Handles files not in a single directory |
| `composes_with` | Informational | Helps skill-writer and future auto-composition |

## Ownership Resolution Rules (v1.1)

When declaring `owns`, follow these precedence rules:

1. **Directory ownership takes precedence over pattern ownership.** If a file matches agent A's glob pattern but lives inside agent B's owned directory, agent B owns it. Example: `src/api/routes.test.ts` matches qe-agent's `*.test.*` pattern but lives in backend-agent's `src/api/` — backend-agent owns it.
2. **Subdirectory carve-outs are explicit.** A more specific directory path overrides a parent. Example: performance-agent owns `tests/performance/` even though qe-agent owns `tests/`.
3. **Orchestrator resolves ambiguity at spawn time.** If a conflict can't be resolved by rules 1-2, the orchestrator assigns the file to one agent before spawning. Unresolvable conflicts → human decision.

### Resolved Conflicts (v1.0 → v1.1)

| Resource | Resolved Owner | Rationale |
|----------|----------------|-----------|
| `contracts/` | contract-author | Creates and maintains contracts; orchestrator reads |
| `.claude/handoffs/` | context-manager | Writes handoffs at context limits; orchestrator reads to spawn continuations |
| `CLAUDE.md` | project-profiler | Generates it; orchestrator reads for project context |
| `README.md` | docs-agent | Writes documentation; orchestrator reads |
| `*.md` (broad) | docs-agent (narrowed to `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`) | Broad `*.md` conflicted with `qa-report.md`, `SECURITY.md`, `CLAUDE.md` |
| `tests/performance/` | performance-agent (carved out from qe's `tests/`) | Specialized concern distinct from functional QA |

## Validation Rules

`skill-review` enforces these.

1. `name` is kebab-case, ≤64 chars, unique, and does NOT start with `claude-` or `anthropic-`
2. `version` is valid semver (top-level or under `metadata`)
3. `description` is present, ≤1024 chars, contains no `<` or `>`
4. No `<` or `>` anywhere in frontmatter
5. `owns.directories` does not overlap with any other agent role
6. Directory ownership takes precedence over pattern ownership (see resolution rules above)
7. `description` contains at least one action verb and one trigger context
8. `requires_agent_teams: true` skills degrade gracefully when teams unavailable
9. Body ≤ 5,000 words OR ≤ 500 lines (guideline — warn, don't fail)

## Spec Alignment Notes

This spec aligns with Anthropic's open Agent Skills standard while preserving multi-agent extensions:

| Anthropic field | This repo | Notes |
|---|---|---|
| `name` | `name` | Identical rules + reserved-prefix enforcement |
| `description` | `description` | Same; we add a tighter 200-char *target* on top of the 1024 ceiling |
| `allowed-tools` | `allowed-tools` (with `allowed_tools` alias) | Aligned this version |
| `metadata` | `metadata` | Adopted as optional nested object |
| `compatibility` | `compatibility` | Adopted |
| `license` | `license` | Adopted |
| — | `version` (top-level, required) | Extension: visible at a glance |
| — | `requires_agent_teams`, `requires_claude_code`, `min_plan` | Extensions: runtime gating |
| — | `owns`, `composes_with`, `spawned_by` | Extensions: multi-agent coordination |

A skill written to this spec uploads to Claude.ai, runs on Claude Code, and works with the Agent SDK.
