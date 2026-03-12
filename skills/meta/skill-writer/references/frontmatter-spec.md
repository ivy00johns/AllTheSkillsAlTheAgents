# Frontmatter Specification

Canonical reference for all SKILL.md frontmatter fields in the skill ecosystem.

## Required Fields

### name

- **Type:** string
- **Required:** yes
- **Max length:** 64 characters
- **Format:** kebab-case (lowercase, hyphens)
- **Example:** `backend-agent`, `contract-author`, `skill-writer`
- **Validation:** Must be unique across the ecosystem

### version

- **Type:** string
- **Required:** yes
- **Format:** Semantic versioning (MAJOR.MINOR.PATCH)
- **Example:** `1.0.0`, `1.2.3`
- **Convention:** Start at 1.0.0. Bump MINOR for features, PATCH for fixes, MAJOR for breaking changes.

### description

- **Type:** string (multiline YAML)
- **Required:** yes
- **Target length:** ≤200 characters
- **Format:** `[Action verb] [what it does]. Use this skill when [trigger contexts].`
- **Purpose:** Primary trigger mechanism — Claude reads this to decide whether to invoke the skill
- **Style:** "Pushy" — enumerate specific trigger contexts, keywords, and use cases

## Optional Fields

### requires_agent_teams

- **Type:** boolean
- **Default:** false
- **Purpose:** Set true if skill requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

### requires_claude_code

- **Type:** boolean
- **Default:** false
- **Purpose:** Set true if skill requires Claude Code CLI (bash tool, file system access)

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

### allowed_tools

- **Type:** string[]
- **Purpose:** Subset of tools this agent may use

### composes_with

- **Type:** string[]
- **Purpose:** Other skill names this naturally works with (informational)

### spawned_by

- **Type:** string[]
- **Purpose:** Which skills spawn this one

## Field Decisions

| Field | Decision | Rationale |
|-------|----------|-----------|
| `version` | Required, semver | Community convention; enables changelog tracking |
| `requires_agent_teams` | Explicit flag | Native teams need env var; skills must declare this |
| `requires_claude_code` | Explicit flag | Some skills are CLI-only; users need to know |
| `owns.directories` | Enforced by orchestrator | Core to zero-conflict parallel builds |
| `owns.patterns` | Glob-based | Handles files not in a single directory |
| `allowed_tools` | Per-agent whitelist | Prevents agents reaching outside their domain |
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

1. `name` must be unique — no two skills share a name
2. `owns.directories` must not overlap between agent roles
3. Directory ownership takes precedence over pattern ownership (see resolution rules above)
4. `description` should contain at least one action verb and one trigger context
5. `version` must be valid semver
6. `requires_agent_teams: true` skills must degrade gracefully when teams unavailable
