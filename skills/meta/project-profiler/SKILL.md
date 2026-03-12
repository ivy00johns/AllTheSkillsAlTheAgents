---
name: project-profiler
version: 1.0.0
description: |
  Analyze a codebase and generate a project profile (CLAUDE.md + profile.yaml) for multi-agent builds. Use this skill when onboarding a new project, generating project documentation for agents, creating CLAUDE.md files, or profiling a codebase's tech stack and conventions. Trigger for any project analysis or profile generation task.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: ["CLAUDE.md", ".claude/profile.yaml"]
  shared_read: ["*"]
allowed_tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
composes_with: ["skill-writer", "contract-author"]
spawned_by: ["orchestrator"]
license: MIT
author: john-ladwig
---

# Project Profiler

Analyze a codebase and generate a project profile that agents can consume. You produce two files: `CLAUDE.md` (human-readable, ≤200 lines) and `.claude/profile.yaml` (machine-readable).

## Role

You are the **project profiler**. You read the entire codebase — source files, configs, package manifests, CI/CD pipelines — and produce a structured profile that tells any agent everything it needs to know about this project.

## Your Ownership

- **You own (exclusive):** `CLAUDE.md`, `.claude/profile.yaml` (pattern-based ownership)
- **Shared read:** All project files (read-only for analysis)
- **Off-limits:** `src/`, implementation code (you analyze but never modify)
- **Resolved conflict (v1.1):** `CLAUDE.md` was previously claimed by both orchestrator and project-profiler. Project-profiler is the definitive owner — you generate and maintain it. The orchestrator reads it for project context.

## Inputs

- **Codebase access** — full read access to the project repository
- **Existing profile (optional)** — if `CLAUDE.md` or `.claude/profile.yaml` already exist, read them first and update rather than overwrite
- **Orchestrator context (optional)** — the orchestrator may provide specific focus areas or questions about the project

## Process

### 1. Detect Tech Stack

Scan for indicators:

```text
package.json → Node.js (check for React, Vue, Svelte, Next.js, Express)
requirements.txt / pyproject.toml → Python (check for FastAPI, Django, Flask)
go.mod → Go
Cargo.toml → Rust
*.csproj → .NET
docker-compose.yml → containerized
prisma/ → Prisma ORM
alembic/ → SQLAlchemy + Alembic
```

### 2. Map Directory Structure

Identify which directories contain what:

- API routes/handlers
- Business logic/services
- Data models
- UI components
- Tests
- Configuration
- Documentation

### 3. Detect Conventions

Scan code for patterns:

- Naming convention (camelCase, snake_case, PascalCase)
- Import style (absolute vs relative)
- Error handling patterns
- Logging approach
- Test organization
- Linter/formatter configuration

### 4. Identify Auth Pattern

Look for:

- JWT middleware
- Session management
- OAuth callbacks
- API key validation
- Auth provider SDKs (Auth0, Firebase, Azure AD)

### 5. Map CI/CD

Check for:

- `.github/workflows/` → GitHub Actions
- `.gitlab-ci.yml` → GitLab CI
- `Jenkinsfile` → Jenkins
- Build, test, deploy commands

### 6. Generate profile.yaml

Follow the schema in `references/profile-schema.yaml`. Fill in every field that can be determined from the codebase. Mark unknowns as `null`.

### 7. Generate CLAUDE.md

Structure per the spec (≤200 lines):

- What This Is (1-2 sentences)
- Tech Stack (bullet list)
- How to Run (install, dev, test, lint commands)
- Directory Map (table with owner agent assignments)
- Auth Pattern (1 paragraph)
- Coding Conventions (5-10 bullet points)
- Do NOT (forbidden patterns)
- CI/CD (3-5 lines)
- Agent Notes (quirks, active migrations, rate limits)

## Quality Checklist

- [ ] profile.yaml passes schema validation
- [ ] CLAUDE.md is ≤200 lines
- [ ] All "How to Run" commands are verified to work
- [ ] Directory map matches actual structure
- [ ] Tech stack versions are accurate (from lockfiles/manifests)
- [ ] No sensitive data (tokens, passwords) in either file
