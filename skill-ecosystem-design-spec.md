# Claude Code Skill Ecosystem — Design Specification v1.0

**Status:** PRE-BUILD BLUEPRINT — requires sign-off before implementation begins  
**Date:** 2026-03-10  
**Scope:** Global multi-agent orchestration toolkit + project profile system

---

## 1. Guiding Principles

1. **Global skills never change per project.** All project-specific context lives in a thin project profile layer.
2. **Contract-first, always.** Every agent team session begins with machine-readable contracts before any implementation agent is spawned.
3. **File ownership is declarative and enforced.** No agent touches a file outside its declared ownership zone.
4. **Progressive disclosure.** Frontmatter ≤100 tokens. SKILL.md body ≤5,000 tokens. Heavy reference material in separate files loaded on demand.
5. **QE has teeth.** The `TaskCompleted` hook gates on a structured JSON QA report — agents cannot self-declare done.
6. **Two-runtime aware.** Skills gracefully degrade when Agent Teams are unavailable (claude.ai, non-Pro plans, no experimental flag).

---

## 2. Complete File Inventory

### 2.1 Global Skills (`~/.claude/skills/`)

```
~/.claude/skills/
│
├── orchestrator/
│   ├── SKILL.md                         # Lead coordinator — the primary entry point
│   └── references/
│       ├── phase-guide.md               # Detailed 14-phase build playbook
│       ├── team-sizing.md               # When to use 2 vs 3 vs 4+ agents
│       ├── circuit-breaker.md           # Failure detection + recovery patterns
│       └── handoff-protocol.md          # Session continuation / context handoff spec
│
├── roles/
│   ├── backend-agent/
│   │   ├── SKILL.md
│   │   └── references/validation-checklist.md
│   ├── frontend-agent/
│   │   ├── SKILL.md
│   │   └── references/validation-checklist.md
│   ├── infrastructure-agent/
│   │   ├── SKILL.md
│   │   └── references/validation-checklist.md
│   ├── qe-agent/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── validation-checklist.md
│   │       ├── qa-report-schema.json    # Machine-readable QA report spec
│   │       └── llm-judge-rubrics.md     # Scoring rubrics for LLM-as-judge eval
│   ├── security-agent/
│   │   ├── SKILL.md
│   │   └── references/owasp-checklist.md
│   ├── docs-agent/
│   │   ├── SKILL.md
│   │   └── references/doc-templates.md
│   ├── observability-agent/
│   │   ├── SKILL.md
│   │   └── references/monitoring-patterns.md
│   ├── db-migration-agent/
│   │   ├── SKILL.md
│   │   └── references/migration-checklist.md
│   └── performance-agent/
│       ├── SKILL.md
│       └── references/
│           ├── k6-patterns.md
│           └── neoload-patterns.md      # NeoLoad-specific (relevant to TAIS work)
│
├── contracts/
│   ├── contract-author/
│   │   ├── SKILL.md                     # Meta-skill: generates contracts before build
│   │   └── references/
│   │       ├── openapi-template.yaml
│   │       ├── asyncapi-template.yaml
│   │       ├── pydantic-template.py
│   │       ├── typescript-template.ts
│   │       └── json-schema-template.json
│   └── contract-auditor/
│       ├── SKILL.md                     # Reviews implementation vs contract
│       └── references/pact-setup.md
│
├── meta/
│   ├── skill-writer/
│   │   ├── SKILL.md                     # Generates new SKILL.md files correctly
│   │   └── references/
│   │       ├── frontmatter-spec.md      # Canonical frontmatter field reference
│   │       └── description-patterns.md  # Anti-under-trigger description templates
│   ├── project-profiler/
│   │   ├── SKILL.md                     # Analyzes a codebase → generates project profile
│   │   └── references/profile-schema.yaml  # Canonical profile schema (see §4)
│   └── code-reviewer/
│       ├── SKILL.md
│       └── references/review-rubric.md
│
└── workflows/
    ├── context-manager/
    │   ├── SKILL.md                     # Compaction strategy, handoff, token budgets
    │   └── references/compaction-guide.md
    └── deployment-checklist/
        ├── SKILL.md
        └── references/pre-deploy.md
```

**Total global skill files: ~35 SKILL.md files + ~30 reference files**

---

### 2.2 Per-Project Files (committed to each project repo)

```
<project-root>/
├── CLAUDE.md                            # Project profile (human-readable, ≤200 lines)
└── .claude/
    ├── settings.json                    # Committed: permissions, hooks, allowed-tools
    ├── settings.local.json              # Git-ignored: personal overrides
    ├── profile.yaml                     # Machine-readable project profile (see §4)
    ├── skills/                          # Project-specific skill overrides (rare)
    │   └── [override-skill]/SKILL.md
    ├── agents/                          # Project-specific subagent definitions (rare)
    └── commands/                        # Project-specific slash commands
        └── [project-command].md
```

**Known project profiles to build after global skills are done:**
- `tricentis-tais/` — AI-Hub API, Tosca Cloud, NeoLoad conventions
- `acu-app/` — Vue 3 / .NET 9.0, Congressional fact sheet app
- `epstein-watch/` — document processing pipeline, search DB

---

## 3. SKILL.md Frontmatter Convention

Every SKILL.md in this ecosystem uses this exact frontmatter structure:

```yaml
---
name: skill-name-kebab-case          # Required. Max 64 chars.
version: 1.0.0                       # Required. Semantic versioning.
description: |
  [Action verb] [what it does]. Use this skill when [specific trigger contexts].
  Include: [key terms]. Do NOT use for: [exclusions if important].
  # Target: ≤200 characters. Written in 3rd person. "Pushy" language encouraged.

# Runtime requirements
requires_agent_teams: false          # true = needs CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
requires_claude_code: false          # true = Claude Code CLI only, not claude.ai
min_plan: starter                    # starter | pro | team | enterprise

# File ownership (for agent role skills only)
owns:
  directories: []                    # Exclusive directory ownership
  patterns: []                       # Glob patterns for owned files
  shared_read: []                    # Directories this agent reads but doesn't own

# Tool permissions (agent role skills)
allowed_tools: []                    # Subset of available tools this agent may use

# Composition hints
composes_with: []                    # Other skill names this naturally works with
spawned_by: []                       # Which skills spawn this one (orchestrator, etc.)

license: MIT
author: john-ladwig                  # GitHub handle
---
```

### Frontmatter Field Decisions

| Field | Decision | Rationale |
|-------|----------|-----------|
| `version` | Required, semver | Community convention; enables changelog tracking |
| `requires_agent_teams` | Explicit flag | Native teams need `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; skills must declare this |
| `requires_claude_code` | Explicit flag | Some skills are CLI-only; claude.ai users need to know |
| `owns.directories` | Enforced by orchestrator | Core to zero-conflict parallel builds |
| `owns.patterns` | Glob-based | Handles files like `*.config.ts` that don't live in a single dir |
| `allowed_tools` | Per-agent whitelist | Prevents agents reaching outside their domain |
| `composes_with` | Informational | Helps skill-writer agent and future auto-composition |

---

## 4. Project Profile Schema

Every project gets a `CLAUDE.md` (human-readable) and a `.claude/profile.yaml` (machine-readable). The YAML is what agents parse; the CLAUDE.md is what humans maintain.

### 4.1 `profile.yaml` Schema

```yaml
# .claude/profile.yaml
# Auto-generated by project-profiler skill, refined by humans
# Schema version: 1.0.0

schema_version: "1.0.0"
project:
  name: string                        # e.g. "tricentis-tais"
  display_name: string                # e.g. "Tricentis AI Hub (TAIS)"
  type: web-app | api | library | monorepo | cli | data-pipeline
  description: string                 # 1-2 sentences

stack:
  language: string                    # Primary language
  runtime: string                     # e.g. "Node 22", "Python 3.12", ".NET 9.0"
  framework: string                   # e.g. "FastAPI", "Next.js", "Vue 3"
  database: string | null
  orm: string | null
  ui_library: string | null
  test_framework: string              # e.g. "pytest", "Jest", "Tosca"
  package_manager: string             # npm | pnpm | yarn | pip | poetry | cargo

api:
  style: REST | GraphQL | gRPC | mixed
  spec_file: string | null            # Relative path to OpenAPI/AsyncAPI spec
  base_url_local: string
  base_url_staging: string | null
  base_url_prod: string | null
  auth_header: string | null          # e.g. "Authorization: Bearer {token}"

auth:
  strategy: JWT | OAuth2 | session | API-key | none
  provider: string | null             # e.g. "Auth0", "Azure AD", "custom"
  token_location: header | cookie | query
  notes: string | null                # Any non-standard auth patterns

conventions:
  style_guide: string                 # e.g. "ESLint Airbnb", "PEP 8", "Google"
  formatter: string                   # e.g. "Prettier", "Black", "gofmt"
  linter: string                      # e.g. "ESLint", "Ruff", "golangci-lint"
  naming:
    files: kebab-case | snake_case | PascalCase | camelCase
    components: PascalCase | kebab-case
    functions: camelCase | snake_case
    constants: SCREAMING_SNAKE | UPPER_CAMEL
  branch_strategy: string             # e.g. "feature/*, fix/*, main"
  commit_style: string                # e.g. "conventional commits"

forbidden_patterns:
  - description: string              # What NOT to do
    example: string | null           # Code example of the bad pattern
  # Add as many as needed

ci_cd:
  platform: GitHub Actions | GitLab CI | Jenkins | other
  build_command: string
  test_command: string
  lint_command: string
  deploy_command: string | null

deployment:
  environments: [local, staging, prod]
  strategy: blue-green | rolling | canary | direct
  containerized: true | false
  orchestrator: Kubernetes | Docker Compose | ECS | none

directory_structure:
  # Annotated map — only non-obvious directories
  - path: string                      # e.g. "src/api"
    owns: string                      # Which agent role owns this
    description: string               # What lives here

performance_testing:
  # Only needed if performance testing is part of this project
  tool: NeoLoad | k6 | Locust | JMeter | none
  scenarios: []                       # Named test scenarios
  baseline_targets: {}                # e.g. {p95_ms: 500, error_rate_pct: 0.1}

notes: string | null                  # Anything agents need to know that doesn't fit above
```

### 4.2 `CLAUDE.md` Structure

```markdown
# [Project Display Name]

## What This Is
[1-2 sentence project description]

## Tech Stack
[Concise bullet list: language, framework, database, key libraries]

## How to Run
```bash
# Install
[command]
# Dev server
[command]
# Tests
[command]
# Lint
[command]
```

## Directory Map
| Directory | Owner Agent | Contents |
|-----------|-------------|----------|
| src/api   | backend     | Route handlers, middleware |
| ...       | ...         | ... |

## Auth Pattern
[1 paragraph: how auth works, token format, where it lives]

## Coding Conventions
[Bullet list of the 5-10 most important conventions]

## Do NOT
[Bullet list of forbidden patterns — the most important rules]

## CI/CD
[Build → test → deploy pipeline in 3-5 lines]

## Agent Notes
[Anything specific agents need to know: rate limits, quirks, active migrations, etc.]
```

**Hard limit: CLAUDE.md ≤200 lines.** Anything longer → move to `.claude/` reference files.

---

## 5. Two-Runtime Strategy

Skills must work in both Claude Code CLI and claude.ai. The strategy:

| Feature | Claude Code | claude.ai | Strategy |
|---------|------------|-----------|----------|
| Native Agent Teams | ✅ (experimental) | ❌ | Orchestrator detects env, falls back to sequential |
| Subagents (Task tool) | ✅ | ❌ | Role skills work standalone without subagent spawning |
| Git worktrees | ✅ | ❌ | Infrastructure agent skill declares worktree support as optional |
| `/compact` | ✅ | ❌ | Context-manager skill detects CLI vs web |
| Hooks (TeammateIdle, TaskCompleted) | ✅ | ❌ | QE gating documented as CLI-only feature |
| File system access | ✅ | Limited | Role skills note when bash tool required |

### Degradation Decision Tree (in orchestrator SKILL.md)

```
Is CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS set?
  YES → Use native Agent Teams (TeammateTool, inbox, shared task list)
  NO → Is this Claude Code CLI (bash tool available)?
    YES → Use subagents via Task tool (parallel but no TeammateTool)
    NO → Sequential mode: work through roles one at a time, user coordinates
```

Each agent role SKILL.md works standalone. The orchestrator is the only skill that needs the full runtime decision tree.

---

## 6. File Ownership Map

This is the canonical ownership table the orchestrator enforces before any agent is spawned.

| Agent Role | Owns (Exclusive) | Shared Read | Never Touches |
|------------|-----------------|-------------|---------------|
| backend | `src/api/`, `src/services/`, `src/models/`, `src/middleware/`, `src/utils/` | `contracts/`, `shared/`, `src/types/` | `src/components/`, `src/pages/` |
| frontend | `src/components/`, `src/pages/`, `src/hooks/`, `src/styles/`, `public/` | `contracts/`, `shared/`, `src/types/` | `src/api/`, `src/services/` |
| infrastructure | `Dockerfile*`, `docker-compose*`, `.github/workflows/`, `nginx/`, `k8s/`, `terraform/`, `scripts/deploy/` | All (read-only audit) | `src/` |
| qe | `tests/`, `e2e/`, `__tests__/`, `*.test.*`, `*.spec.*` | All (read-only) | `src/` (creates test files only) |
| security | `SECURITY.md`, `.github/security/` | All (read-only audit) | Nothing else |
| docs | `docs/`, `README.md`, `CHANGELOG.md`, `*.md` (non-config) | All (read-only) | `src/`, configs |
| observability | `src/telemetry/`, `src/logging/`, `monitoring/`, `alerts/` | `src/` (read-only) | Other `src/` subdirs |
| db-migration | `migrations/`, `seeds/`, `prisma/`, `alembic/` | `src/models/` (read-only) | `src/` otherwise |
| performance | `tests/performance/`, `load-tests/` | All (read-only) | `src/`, `tests/` |
| contract-author | `contracts/`, `schemas/`, `openapi.yaml`, `asyncapi.yaml` | All (read-only) | `src/` |

**Rule:** If two roles would touch the same file, the orchestrator resolves the conflict by assigning that file to exactly one role before spawning agents. Conflicts → human decision.

---

## 7. QA Report Schema

The QE agent outputs this JSON schema. The orchestrator's `TaskCompleted` hook parses it.

```json
{
  "schema_version": "1.0.0",
  "timestamp": "ISO8601",
  "agent_role": "qe",
  "build_session_id": "string",
  "status": "PASS | FAIL | PARTIAL | BLOCKED",
  
  "scores": {
    "correctness": { "score": 1-5, "notes": "string" },
    "completeness": { "score": 1-5, "notes": "string" },
    "code_quality": { "score": 1-5, "notes": "string" },
    "security": { "score": 1-5, "notes": "string" },
    "contract_conformance": { "score": 1-5, "notes": "string" }
  },
  
  "test_results": {
    "unit": { "pass": 0, "fail": 0, "skip": 0 },
    "integration": { "pass": 0, "fail": 0, "skip": 0 },
    "e2e": { "pass": 0, "fail": 0, "skip": 0 },
    "contract": { "pass": 0, "fail": 0, "skip": 0 },
    "security_scan": { "pass": 0, "fail": 0, "skip": 0 }
  },
  
  "blockers": [
    {
      "id": "string",
      "severity": "CRITICAL | HIGH",
      "category": "contract_violation | security | build_failure | test_failure | other",
      "file": "string | null",
      "line": "number | null",
      "description": "string",
      "suggested_fix": "string"
    }
  ],
  
  "issues": [
    {
      "id": "string",
      "severity": "MEDIUM | LOW | INFO",
      "category": "string",
      "file": "string | null",
      "line": "number | null",
      "description": "string",
      "suggested_fix": "string"
    }
  ],
  
  "recommendations": ["string"],
  
  "gate_decision": {
    "proceed": true,
    "reason": "string"
  }
}
```

**Orchestrator rule:** `gate_decision.proceed = false` when:
- Any `status = FAIL` or `BLOCKED`
- Any blocker with `severity = CRITICAL`
- `scores.contract_conformance < 3`
- `scores.security < 3`

---

## 8. Handoff Protocol

When an agent approaches context limits (~80% usage), it writes a structured handoff file and signals the orchestrator.

### Handoff File Format (`.claude/handoffs/{agent-role}-{timestamp}.yaml`)

```yaml
handoff_version: "1.0.0"
agent_role: string
timestamp: ISO8601
session_id: string
context_usage_pct: number

task_state:
  assigned_task: string
  completion_pct: number           # Honest estimate
  completed_subtasks: [string]
  remaining_subtasks: [string]
  blockers: [string]

decisions_made:
  - decision: string
    rationale: string
    affects_files: [string]

files_modified: [string]           # Relative paths
files_created: [string]
contracts_consumed: [string]       # Which contract files were read

continuation_context: |
  [Free-text: what the continuation agent needs to know immediately.
   Key variable names, error states, partial work, next action.
   ≤500 words.]

suggested_first_action: string     # Exact next step for continuation agent
```

**Orchestrator behavior on handoff:** Spawn continuation agent with handoff file as first message context. Tag the task as `in_progress_handoff` in shared task list.

---

## 9. Build Order

Skills will be built in this sequence to ensure each new file can reference already-defined standards:

**Phase 1 — Foundation (build first)**
1. `meta/skill-writer/SKILL.md` + frontmatter-spec.md + description-patterns.md
2. `roles/qe-agent/references/qa-report-schema.json` (the gate spec)
3. `contracts/contract-author/references/` (all template files)

**Phase 2 — Agent Roles**
4. `roles/backend-agent/`
5. `roles/frontend-agent/`
6. `roles/infrastructure-agent/`
7. `roles/qe-agent/`
8. `roles/security-agent/`
9. `roles/docs-agent/`
10. `roles/observability-agent/`
11. `roles/db-migration-agent/`
12. `roles/performance-agent/`

**Phase 3 — Meta Skills**
13. `contracts/contract-author/SKILL.md`
14. `contracts/contract-auditor/SKILL.md`
15. `meta/project-profiler/SKILL.md` + profile-schema.yaml
16. `meta/code-reviewer/SKILL.md`
17. `workflows/context-manager/SKILL.md`
18. `workflows/deployment-checklist/SKILL.md`

**Phase 4 — Orchestrator**
19. `orchestrator/references/` (all reference files)
20. `orchestrator/SKILL.md` (built last — references everything else)

**Phase 5 — Project Profiles**
21. Tricentis TAIS profile (CLAUDE.md + profile.yaml)
22. ACU app profile
23. EpsteinFilesWatch profile

---

## 10. Open Decisions (Needs Sign-off)

These are the only unresolved questions. Everything else above is decided.

| # | Decision | Option A | Option B | Recommendation |
|---|----------|----------|----------|----------------|
| 1 | **Orchestrator trigger style** | Single orchestrator SKILL.md triggered by "build", "create app", etc. | Separate entry-point skills per project type (web app, API, CLI) | **A** — simpler, project profiles handle the rest |
| 2 | **Specialist agents** | Include auth/ML/search/worker agent skills in Phase 2 | Leave as future additions | **B** — scope creep; add when needed |
| 3 | **Performance agent scope** | NeoLoad + k6 both covered | NeoLoad-only (matches TAIS use case) | **A** — generic toolkit, NeoLoad depth in project profile |
| 4 | **Plugin manifest** | Include `.claude-plugin/plugin.json` for marketplace distribution | Skip for now, add later | **A** — trivial to add, future-proofs for community release |
| 5 | **Version lock** | Pin skills to specific Claude model versions | Float to latest model | **B** — float; model pinning is enterprise concern |

---

## 11. What We Are NOT Building (Scope Exclusions)

To keep this deliverable finite:

- No Smithery/SkillsMP marketplace submission tooling
- No CI/CD for the skill repo itself (manual git management)
- No automated skill eval test suite (the skill-creator skill handles this on-demand)
- No Agent Skills standard `.skill` packaging (directory structure is sufficient)
- No A2A protocol integration (local orchestration only)
- No multi-LLM portability (Claude-first, SKILL.md cross-platform is a bonus)

---

*Sign off on §10 Open Decisions, then Phase 1 build begins.*
