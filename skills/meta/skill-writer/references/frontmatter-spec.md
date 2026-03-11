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

### license
- **Type:** string
- **Default:** `MIT`

### author
- **Type:** string
- **Format:** GitHub handle

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

## Validation Rules

1. `name` must be unique — no two skills share a name
2. `owns.directories` must not overlap between agent roles
3. `description` should contain at least one action verb and one trigger context
4. `version` must be valid semver
5. `requires_agent_teams: true` skills must degrade gracefully when teams unavailable
