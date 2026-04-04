# Skill Composition Audit Fix — Design Spec

**Date:** 2026-04-04
**Trigger:** Mermaid-charts skill was not invoked during orchestrator MASTER-PLAN build
**Root cause:** Systemic composition gaps across 33 skills — 22 missing connections found
**Approach:** 5 parallel agents with exclusive file ownership, deployed overnight

---

## Problem Statement

The `composes_with` field in skill frontmatter signals which skills naturally work together. An audit of all 33 skills revealed 22 gaps: missing connections, asymmetric relationships, disconnected clusters, and orchestrator phase guide omissions. The composition graph has isolated islands — the build cluster, git cluster, mermaid/visual tools, and standalone workflows don't know about each other.

## Workstream Architecture

5 parallel agents. No file is touched by more than one agent.

```
W1: orchestrator-fix    (2 files,  5 fixes)
W2: mermaid-fix         (3 files,  5 fixes — 1 file no-change ownership guard)
W3: roles-fix           (14 files, 8 fixes — 9 files no-change ownership guards)
W4: orphans-fix         (2 files,  2 fixes)
W5: git-fix             (1 file,   2 fixes)
```

---

## W1: Orchestrator + Phase Guide

**Agent:** orchestrator-fix
**Files:**
- `skills/orchestrator/SKILL.md`
- `skills/orchestrator/references/phase-guide.md`

### SKILL.md — Frontmatter Edit

Add to `composes_with`:
- `mermaid-charts` (fix #1 — orchestrator unaware mermaid exists)
- `plan-builder` (fix #13 — plan→orchestrate pipeline disconnected)
- `git-commit` (fix #14 — builds create branches/commits without convention awareness)
- `git-pr` (fix #15 — post-build PR creation not referenced)

**Before:**
```yaml
composes_with: [
  "backend-agent", "frontend-agent", "infrastructure-agent", "qe-agent",
  "security-agent", "docs-agent", "observability-agent", "db-migration-agent", "performance-agent",
  "contract-author", "contract-auditor",
  "context-manager", "deployment-checklist", "code-reviewer", "project-profiler"
]
```

**After:**
```yaml
composes_with: [
  "backend-agent", "frontend-agent", "infrastructure-agent", "qe-agent",
  "security-agent", "docs-agent", "observability-agent", "db-migration-agent", "performance-agent",
  "contract-author", "contract-auditor",
  "context-manager", "deployment-checklist", "code-reviewer", "project-profiler",
  "mermaid-charts", "plan-builder", "git-commit", "git-pr"
]
```

### phase-guide.md — Content Additions

**Phase 1 (Read and Analyze the Plan):** After the "Extract:" bullet list, add:

> **Visualize the architecture** — use the mermaid-charts skill to generate an architecture overview diagram showing major components, their layers, and dependency flow. This diagram becomes the visual anchor for the rest of the build and is included in final documentation.

**Phase 6 (Pre-Create Scaffolding):** After the branch creation bullet, add:

> - Follow git-commit conventions for branch naming (`build/<project-name>`) and commit messages throughout the build

**Phase 14 (Post-Build):** After "Spawn docs-agent to write README.md", add:

> 2. Generate final architecture diagram(s) using mermaid-charts — system overview, data flow, and deployment topology as appropriate. Include in README or `docs/`.

---

## W2: Mermaid Composition Hub

**Agent:** mermaid-fix
**Files:**
- `skills/workflows/mermaid-charts/SKILL.md`
- `skills/workflows/plan-builder/SKILL.md`
- `skills/workflows/repo-deep-dive/SKILL.md` (ownership guard, no changes)

### mermaid-charts/SKILL.md — Frontmatter Edit

Add to `composes_with`:
- `orchestrator` (fix #3 — asymmetric, neither skill knew about the other)
- `infrastructure-agent` (fix #6 — network topology, deployment architecture diagrams)
- `contract-author` (fix #7 — entity relationship, API dependency diagrams)
- `observability-agent` (fix #20 — monitoring architecture, alert flow diagrams)

**Before:**
```yaml
composes_with:
  - docs-agent
  - backend-agent
  - frontend-agent
  - skill-writer
  - project-profiler
```

**After:**
```yaml
composes_with:
  - docs-agent
  - backend-agent
  - frontend-agent
  - skill-writer
  - project-profiler
  - orchestrator
  - infrastructure-agent
  - contract-author
  - observability-agent
```

### plan-builder/SKILL.md — Frontmatter Edit

Add to `composes_with`:
- `mermaid-charts` (fix #4 — plans should include architecture diagrams)
- `contract-author` (fix #12 — plans should reference contract patterns)

**Before:**
```yaml
composes_with: ["orchestrator", "project-profiler"]
```

**After:**
```yaml
composes_with: ["orchestrator", "project-profiler", "mermaid-charts", "contract-author"]
```

---

## W3: Role Agent Compositions

**Agent:** roles-fix
**Files that change:**
- `skills/roles/docs-agent/SKILL.md`
- `skills/roles/security-agent/SKILL.md`
- `skills/workflows/deployment-checklist/SKILL.md`
- `skills/meta/code-reviewer/SKILL.md`
- `skills/meta/project-profiler/SKILL.md`

**Files owned but unchanged (ownership guards):**
- `skills/roles/backend-agent/SKILL.md`
- `skills/roles/frontend-agent/SKILL.md`
- `skills/roles/infrastructure-agent/SKILL.md`
- `skills/roles/qe-agent/SKILL.md`
- `skills/roles/observability-agent/SKILL.md`
- `skills/roles/db-migration-agent/SKILL.md`
- `skills/roles/performance-agent/SKILL.md`
- `skills/contracts/contract-author/SKILL.md`
- `skills/contracts/contract-auditor/SKILL.md`

### Exact Changes

**docs-agent** — add `mermaid-charts`, `contract-author` (fixes #5, #19)
```yaml
# Before
composes_with: ["backend-agent", "frontend-agent", "infrastructure-agent"]
# After
composes_with: ["backend-agent", "frontend-agent", "infrastructure-agent", "mermaid-charts", "contract-author"]
```

**security-agent** — add `infrastructure-agent` (fix #10)
```yaml
# Before
composes_with: ["backend-agent", "frontend-agent", "qe-agent", "code-reviewer"]
# After
composes_with: ["backend-agent", "frontend-agent", "qe-agent", "code-reviewer", "infrastructure-agent"]
```

**deployment-checklist** — add `security-agent`, `observability-agent` (fixes #8, #9)
```yaml
# Before
composes_with: ["infrastructure-agent", "qe-agent"]
# After
composes_with: ["infrastructure-agent", "qe-agent", "security-agent", "observability-agent"]
```

**code-reviewer** — add `backend-agent`, `frontend-agent` (fix #11)
```yaml
# Before
composes_with: ["qe-agent", "security-agent"]
# After
composes_with: ["qe-agent", "security-agent", "backend-agent", "frontend-agent"]
```

**project-profiler** — add `orchestrator` (fix #16)
```yaml
# Before
composes_with: ["skill-writer", "contract-author"]
# After
composes_with: ["skill-writer", "contract-author", "orchestrator"]
```

---

## W4: Standalone Orphans

**Agent:** orphans-fix
**Files:**
- `skills/workflows/nano-banana/SKILL.md`
- `skills/workflows/railway-deploy/SKILL.md`

### nano-banana — add `composes_with` field (fix #18)

This skill has no `composes_with` at all. Add:
```yaml
composes_with: ["frontend-agent", "docs-agent"]
```
Rationale: nano-banana generates images for hero banners and product shots (frontend) and illustration (docs).

### railway-deploy — add `composes_with` field (fix #17)

This skill has no `composes_with` at all. Add:
```yaml
composes_with: ["infrastructure-agent", "deployment-checklist"]
```
Rationale: railway-deploy handles Dockerfiles and deployment config (infrastructure) and is a deployment target (checklist).

---

## W5: Git Cluster + Minor

**Agent:** git-fix
**Files:**
- `skills/git/git-clean-worktrees/SKILL.md`

### git-clean-worktrees — fix namespace references (fix #21)

The `composes_with` references `using-git-worktrees` and `finishing-a-development-branch` without the `superpowers:` namespace prefix. These are superpowers skills.

**Before:**
```yaml
composes_with: ["git-branch-cleanup", "using-git-worktrees", "finishing-a-development-branch"]
```

**After:**
```yaml
composes_with: ["git-branch-cleanup", "superpowers:using-git-worktrees", "superpowers:finishing-a-development-branch"]
```

### Fix #22 (skill-writer ↔ orchestrator asymmetry)

No action needed. skill-writer already composes with orchestrator. The orchestrator not listing skill-writer is correct — skill-writer is a meta tool, not part of builds. Documenting this as intentional.

---

## Validation Criteria

After all agents complete:

1. **Parse check** — Every edited SKILL.md must have valid YAML frontmatter (no broken delimiters, correct array syntax)
2. **Symmetry audit** — For every critical pair (orchestrator↔mermaid, docs↔mermaid, plan-builder↔mermaid), verify both sides reference each other
3. **No regressions** — No existing `composes_with` entries removed
4. **Phase guide readability** — New phase-guide content reads naturally in context, uses imperative voice consistent with existing phases
5. **Grep verification** — `grep -r "composes_with" skills/` output confirms all 22 fixes applied

## Execution Plan

1. Create feature branch `fix/skill-composition-audit`
2. Spawn 5 agents in parallel worktrees
3. Merge all worktree changes to feature branch
4. Run validation checks
5. Single commit with all changes
