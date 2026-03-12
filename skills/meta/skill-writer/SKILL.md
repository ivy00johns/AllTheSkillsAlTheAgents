---
name: skill-writer
version: 1.0.0
description: |
  Generate new SKILL.md files conforming to the ecosystem's frontmatter spec and structure conventions. Use this skill when creating any new skill, agent role definition, or workflow skill. Trigger whenever someone says "create a skill", "new agent", "write a SKILL.md", or needs to add a role to the skill ecosystem. Also use when reviewing existing skills for spec compliance.
requires_agent_teams: false
requires_claude_code: false
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: []
allowed_tools: ["Read", "Write", "Edit", "Glob", "Grep"]
composes_with: ["project-profiler", "orchestrator"]
spawned_by: []
---

# Skill Writer

Generate correctly structured SKILL.md files for the Claude Code skill ecosystem. Every skill follows the same frontmatter convention and directory structure.

## When to Use

- Creating a new agent role skill
- Creating a new workflow or meta skill
- Reviewing existing skills for spec compliance
- Adding a role to an orchestrated build

## Skill Directory Structure

```text
skill-name/
├── SKILL.md              # Required — frontmatter + instructions
└── references/           # Optional — loaded on demand
    ├── detailed-guide.md
    └── templates/
```

## Progressive Disclosure

Skills use three-level loading:

1. **Metadata** (~100 tokens) — name + description, always in context
2. **SKILL.md body** (<500 lines) — loaded when skill triggers
3. **References** (unlimited) — loaded on demand via explicit reads

Keep SKILL.md bodies concise. Move detailed checklists, templates, and reference tables to `references/` with clear pointers.

## Creating a New Skill

### Step 1: Choose the Skill Type

| Type | Directory | Purpose |
|------|-----------|---------|
| Agent role | `roles/{name}/` | Implementation agent for orchestrated builds |
| Meta skill | `meta/{name}/` | Tools for the skill ecosystem itself |
| Workflow | `workflows/{name}/` | Cross-cutting processes |
| Contract | `contracts/{name}/` | Integration contract management |
| Orchestrator | `orchestrator/` | Lead coordinator (singleton) |

### Step 2: Write the Frontmatter

Every SKILL.md starts with YAML frontmatter. See `references/frontmatter-spec.md` for the complete field reference.

Required fields:

- `name` — kebab-case, max 64 chars
- `version` — semver (start at 1.0.0)
- `description` — action verb + what it does + trigger contexts (≤200 chars target)

The description is the primary trigger mechanism. Write it "pushy" — enumerate contexts where the skill should activate. See `references/description-patterns.md` for templates.

### Step 3: Write the Body

Structure the body around:

1. **Role statement** — one paragraph defining what this agent/skill does
2. **Inputs** — what parameters it receives
3. **Process** — numbered steps, imperative voice
4. **Coordination rules** — how it interacts with other agents
5. **Guidelines** — principles and common pitfalls

For agent role skills, also include:

- **Ownership** — directories/files owned exclusively
- **Off-limits** — what this agent must never touch
- **Validation** — link to `references/validation-checklist.md`

### Step 4: Create Reference Files

Move detailed content to `references/`:

- Validation checklists with specific commands
- Templates and examples
- Detailed technical guides
- Tables longer than 20 rows

Reference files from the body with guidance on when to read:

```markdown
For the complete validation procedure, read `references/validation-checklist.md`
before reporting done.
```

### Step 5: Validate the Skill

- [ ] Frontmatter has all required fields
- [ ] Description is ≤200 characters and "pushy"
- [ ] Body is under 500 lines
- [ ] File ownership doesn't overlap with existing agents (check v1.1 resolved conflicts)
- [ ] Directory ownership takes precedence over pattern ownership
- [ ] Reference files are linked from the body
- [ ] No duplicate content between body and references

## Common Mistakes

- **Vague descriptions** — "Helps with backend stuff" won't trigger. Be specific.
- **Body too long** — Approaching 500 lines? Move content to references.
- **Missing ownership** — Agent roles must declare owned and off-limits files.
- **Overlapping ownership** — Two agents can't own the same directory. Directory ownership takes precedence over pattern ownership (see `references/frontmatter-spec.md` §Ownership Resolution Rules).
- **Ignoring resolved conflicts** — Check the v1.1 resolved conflicts table before declaring ownership of `contracts/`, `.claude/handoffs/`, `CLAUDE.md`, `README.md`, or `tests/performance/`.
- **Hardcoded project details** — Global skills never change per project. Use profile.yaml.

## Reference Files

- `references/frontmatter-spec.md` — Complete field reference with types, rules, and examples
- `references/description-patterns.md` — Templates for writing effective trigger descriptions
