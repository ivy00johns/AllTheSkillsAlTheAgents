# Contract: Skill Source Format

**Build:** Multi-Tool Installer (Slice A)
**Version:** 1.0.0
**Owner:** orchestrator (authored Phase 4)
**Consumed by:** scripts-agent (convert.sh), qe-agent (test fixtures)

## Purpose

Defines the **input** that `scripts/convert.sh` walks. The canonical source format is the existing AllTheSkillsAllTheAgents SKILL.md layout — this contract pins down the parsing and walking rules so the converter never guesses.

## Source Layout

```
skills/
├── orchestrator/<skill>/SKILL.md
├── roles/<skill>/SKILL.md
├── contracts/<skill>/SKILL.md
├── meta/<skill>/SKILL.md
├── git/<skill>/SKILL.md
├── workflows/<skill>/SKILL.md
└── <category>/<skill>/references/*.md   (optional, unlimited)
```

The converter MUST walk `skills/**/SKILL.md` exactly. It MUST NOT walk `claude_docs/.claude/skills/` — those are personal skills excluded from the OSS bundle (see `CLAUDE.md`).

For each match, derive:

| Field | Derivation |
|---|---|
| `skill_dir` | `dirname(SKILL.md)` |
| `slug` | `basename(skill_dir)` (e.g., `backend-agent`) |
| `category` | `basename(dirname(skill_dir))` (e.g., `roles`) |
| `references_dir` | `${skill_dir}/references/` (may not exist) |
| `frontmatter` | YAML between the first two `---` markers at the top of `SKILL.md` |
| `body` | Everything after the second `---` (no trailing whitespace trim) |

Skills in `skills/orchestrator/` have no category-level grandparent — treat their category as `orchestrator`.

## Frontmatter Schema (input)

The converter MUST recognize every field defined in `skills/meta/skill-writer/references/frontmatter-spec.md`. The relevant fields for conversion:

**Required (used by every tool):**

- `name` — string, kebab-case
- `version` — string, semver
- `description` — string

**Optional (per-tool handling — see `per-tool-output-spec.md`):**

- `owns` (object with `directories`, `patterns`, `shared_read`) — preserve only for Claude Code; strip for all others
- `allowed_tools` (string[]) — preserve only for Claude Code; **strip with stderr warning** for all others
- `composes_with` (string[]) — preserve only for Claude Code; strip for all others
- `spawned_by` (string[]) — preserve only for Claude Code; strip for all others
- `requires_agent_teams` (bool) — preserve only for Claude Code
- `requires_claude_code` (bool) — if true, **skip skill entirely** for non-Claude-Code targets and emit a stderr warning
- `min_plan` (enum) — preserve only for Claude Code
- `vibe` (string, optional, future Slice B) — converter MUST tolerate its presence; per-tool handling defined later

**Unknown fields:** preserve in Claude Code output; strip silently for other tools (forward-compat).

## Body Handling

The body is preserved as-is for tools that accept full markdown (Claude Code, Antigravity, Gemini CLI, OpenCode, Cursor, OpenClaw, Qwen, Kimi).

For consolidated tools (Aider `CONVENTIONS.md`, Windsurf `.windsurfrules`):

- The body is appended to the consolidated file under a `## <name>` header
- Inter-skill delimiters per tool spec (Aider: `---`; Windsurf: 80-char `=` line)
- The accumulation order MUST be deterministic: sort by `category/slug` ASCII

## `references/` Handling

References are per-skill supplementary docs. Per-tool behavior:

| Tool | Strategy |
|---|---|
| claude-code | Copy `references/` alongside `SKILL.md` (preserves disclosure pattern) |
| antigravity | Copy `references/` alongside `SKILL.md` |
| gemini-cli | Copy `references/` alongside `SKILL.md` |
| opencode | Copy `references/` alongside the per-skill `.md` |
| openclaw | Append a footer line `> Additional context: see references/` to AGENTS.md, copy `references/` into the skill's directory |
| cursor | Inline-bundle by appending each reference file under a `## Reference: <filename>` header in the `.mdc` body |
| qwen | Same as cursor (inline-bundle) |
| kimi | Inline-bundle into `system.md` |
| aider | Skip references — the consolidated file would explode. Emit stderr note per skill. |
| windsurf | Skip references — same reason as aider |
| copilot | Copy `references/` alongside the `.md` (mirrors claude-code) |

## Walking Rules

1. **Sort:** Walk in deterministic ASCII order on `category/slug` for reproducible output.
2. **Skip non-skills:** Files outside `skills/**/SKILL.md` are ignored.
3. **Frontmatter required:** A SKILL.md without a leading `---` block is a hard error — fail conversion with a non-zero exit code and identify the file.
4. **No silent skips:** Every skill processed (or excluded by `requires_claude_code`) MUST appear in the converter's stderr summary.

## Test Fixtures

The qe-agent MUST validate the converter against:

1. A minimal skill (only required fields)
2. A full agent role skill (all `owns`, `allowed_tools`, `composes_with`, `spawned_by`)
3. A skill with `references/` containing 2+ files
4. A skill with `requires_claude_code: true`
5. A skill with malformed frontmatter (expect non-zero exit + clear error)

Fixtures live in `tests/installer/fixtures/skills/`. The qe-agent owns this path.
