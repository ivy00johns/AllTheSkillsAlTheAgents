# Contract: Per-Tool Output Spec

**Build:** Multi-Tool Installer (Slice A)
**Version:** 1.0.0
**Owner:** orchestrator (authored Phase 4)
**Consumed by:** scripts-agent (convert.sh), qe-agent (golden-file tests)

## Purpose

Defines the **output** that `scripts/convert.sh` produces in `integrations/<tool>/` for each of the 11 supported tools. Each section gives: filename pattern, frontmatter format, body handling, and concrete example.

The implementation agent MAY consult `/Users/johns/Repos/ai-tools-and-frameworks/agent-frameworks/agency-agents/scripts/convert.sh` as a reference implementation, but MUST adapt to AllTheSkillsAllTheAgents conventions documented here.

## Tool Matrix

| Tool | Scope | Filename pattern | Format | Complexity |
|---|---|---|---|---|
| claude-code | user | `claude-code/<category>/<slug>/SKILL.md` + references | passthrough | trivial |
| copilot | user | `copilot/<slug>.md` | passthrough | trivial |
| antigravity | user | `antigravity/<slug>/SKILL.md` | generated | low |
| gemini-cli | user | `gemini-cli/skills/<slug>/SKILL.md` + manifest | generated | low |
| opencode | project | `opencode/agents/<slug>.md` | generated | low |
| cursor | project | `cursor/rules/<slug>.mdc` | generated | low |
| openclaw | user | `openclaw/<slug>/{SOUL,AGENTS,IDENTITY}.md` | split | high |
| qwen | project | `qwen/agents/<slug>.md` | generated | low |
| kimi | user | `kimi/<slug>/{agent.yaml,system.md}` | generated | medium |
| aider | project | `aider/CONVENTIONS.md` (single file) | accumulate | medium |
| windsurf | project | `windsurf/.windsurfrules` (single file) | accumulate | medium |

## 1. claude-code

**Path:** `integrations/claude-code/<category>/<slug>/SKILL.md`

Preserve the canonical AllTheSkills layout. This is the only tool that gets the full frontmatter (all fields). Copy `references/` alongside.

**Frontmatter:** unchanged from source.
**Body:** unchanged.

## 2. copilot

**Path:** `integrations/copilot/<slug>.md`

Flat layout (no category nesting — Copilot's agent picker is a flat list).

**Frontmatter:** keep `name`, `version`, `description`. Strip `owns`, `allowed_tools`, `composes_with`, `spawned_by`, `requires_agent_teams`, `min_plan`. Emit one stderr line per skill: `[copilot] stripped allowed_tools/owns from <slug>`.
**Body:** unchanged.
**References:** copy as `<slug>-references/` sibling directory.

## 3. antigravity

**Path:** `integrations/antigravity/<slug>/SKILL.md`

**Frontmatter:**

```yaml
---
name: <slug>
description: <description>
risk: low
source: alltheskills
date_added: <ISO-8601 date of conversion>
---
```

**Body:** unchanged.
**References:** copy alongside `SKILL.md`.

## 4. gemini-cli

**Path:** `integrations/gemini-cli/skills/<slug>/SKILL.md` plus `integrations/gemini-cli/gemini-extension.json`.

**Manifest** (written once per conversion, not per skill):

```json
{
  "name": "alltheskills",
  "version": "1.0.0"
}
```

**Per-skill frontmatter:** minimal — `name`, `description`.
**Body:** unchanged.
**References:** copy alongside `SKILL.md`.

## 5. opencode

**Path:** `integrations/opencode/agents/<slug>.md`

**Frontmatter:**

```yaml
---
name: <name>             # original, NOT slug
description: <description>
mode: subagent
color: '#6B7280'         # default gray; AllTheSkills skills don't define color (yet)
---
```

**Body:** unchanged.
**References:** copy alongside as `<slug>-references/` sibling directory.

When the `vibe`/`color` fields land in Slice B, the converter MUST start emitting them here. For now, default `color` to gray and omit nothing else.

## 6. cursor

**Path:** `integrations/cursor/rules/<slug>.mdc`

**Frontmatter:**

```yaml
---
description: <description>
globs: ""
alwaysApply: false
---
```

Note: `name` is NOT in cursor's frontmatter (cursor identifies rules by filename).

**Body:** original body PLUS inline-bundled references. For each reference file in `references/`, append:

```markdown

## Reference: <filename without .md>

<reference body>
```

Cursor doesn't have a directory concept — bundling is the only way references travel.

## 7. openclaw

**Path:** `integrations/openclaw/<slug>/{SOUL.md, AGENTS.md, IDENTITY.md}` + optional `references/`

Most complex conversion. The body's `##` headers split into SOUL vs AGENTS:

**SOUL.md headers** (case-insensitive match):

- `identity`
- `learning & memory`
- `communication`
- `style`
- `critical rules`
- `rules you must follow`

**AGENTS.md headers:** everything else.

**IDENTITY.md** (3-line file):

```markdown
# 🤖 <name>
<description>
```

(Use 🤖 as default emoji until Slice B introduces a `vibe`/`emoji` field. Then switch to those.)

**References:** copy under the skill directory; AGENTS.md gets a footer `> Additional context: see references/`.

If a skill body has no headers at all (some short skills), put the entire body into AGENTS.md and leave SOUL.md as a single line: `# <name>` (placeholder).

## 8. qwen

**Path:** `integrations/qwen/agents/<slug>.md`

**Frontmatter:**

```yaml
---
name: <slug>
description: <description>
---
```

If the source has `allowed_tools`, MAP it to qwen's `tools` field (comma-separated). Otherwise omit.

**Body:** original PLUS inline-bundled references (same pattern as cursor).

## 9. kimi

**Path:** `integrations/kimi/<slug>/{agent.yaml, system.md}`

**agent.yaml:**

```yaml
version: 1
agent:
  name: <slug>
  extend: default
  system_prompt_path: ./system.md
```

**system.md:**

```markdown
# <name>

<description>

<body>

<inline-bundled references>
```

## 10. aider

**Path:** `integrations/aider/CONVENTIONS.md` (single file, ALL skills concatenated).

**Header (written once at top):**

```markdown
# AllTheSkillsAllTheAgents — Skill Conventions
#
# Generated by scripts/convert.sh — do not edit manually.
# Source: https://github.com/<org>/AllTheSkillsAllTheAgents
#
# To activate a skill in Aider, reference it by name in your prompt, e.g.:
#   "Apply the backend-agent skill to refactor this service."
#
```

**Per-skill block:**

```markdown
---

## <name>

> <description>

<body>
```

**References:** SKIPPED (would balloon the file). Emit stderr note per skill: `[aider] skipped references for <slug>`.

**Order:** ASCII-sorted by `category/slug`.

## 11. windsurf

**Path:** `integrations/windsurf/.windsurfrules` (single file).

**Header:**

```markdown
# AllTheSkillsAllTheAgents — Skill Rules for Windsurf
#
# Generated by scripts/convert.sh — do not edit manually.
#
```

**Per-skill block:**

```markdown
================================================================================
## <name>
<description>
================================================================================

<body>
```

**References:** SKIPPED (same as aider).

## Cross-Tool Rules

- **Determinism:** Same input MUST produce same output (sort skills, sort frontmatter keys, no timestamps except `antigravity.date_added` which uses `UTC date +%Y-%m-%d`).
- **Idempotency:** Re-running convert MUST produce byte-identical output (modulo `date_added`).
- **Stderr summary:** End-of-run summary on stderr: `[convert] processed <N> skills across <M> tools (<errors> errors, <warnings> warnings)`.
- **Exit codes:** `0` on success, `1` on any per-skill error, `2` on argument parsing error.
