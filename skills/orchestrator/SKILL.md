---
name: orchestrator
version: 1.8.1
description: |
  Lead coordinator and conductor for multi-agent builds using Claude Code. Takes a plan or mission document, executes its phases end-to-end, and orchestrates parallel role-agents with a contract-first architecture. The orchestrator is the conductor — not the only player: it INVOKES other skills (nano-banana for imagery, ui-ux-pro-max + frontend-design for UI quality, ux-review for post-build validation, repo-deep-dive for reference research, llm-wiki for project knowledge bases, mermaid-charts for diagrams, deployment-checklist for ship readiness) at the appropriate phase, and DISPATCHES role-agents (backend, frontend, db, infra, security, observability, performance, docs, qe) for parallel implementation. Use this skill when building a project with multiple agents, coordinating an agent team build, executing a multi-phase mission document, or when the user mentions "agent team", "parallel build", "multi-agent", "swarm build", "team build", a "MISSION.md" file, or wants to split work across multiple Claude sessions. Trigger even for simple build requests like "build X — use an agent team". This is the primary entry point for any orchestrated build. It does NOT preempt brainstorming, plan-builder, writing-plans, frontend-design, ui-ux-pro-max, nano-banana, claude-design-brief, ui-brief, repo-deep-dive, llm-wiki, ux-review, feature-dev, or claude-mem — it COMPOSES with them, invoking each at the phase where it earns its keep.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: [".gitignore"]
  shared_read: ["contracts/", ".claude/handoffs/"]
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
composes_with: [
  "wiki-research", "llm-wiki", "repo-deep-dive",
  "brainstorming", "plan-builder", "writing-plans",
  "backend-agent", "frontend-agent", "infrastructure-agent", "qe-agent",
  "security-agent", "docs-agent", "observability-agent", "db-migration-agent", "performance-agent",
  "contract-author", "contract-auditor", "dependency-coordinator",
  "context-manager", "deployment-checklist", "code-review-agent", "project-profiler",
  "mermaid-charts", "playwright",
  "claude-design-brief", "ui-brief", "frontend-design", "ui-ux-pro-max", "ux-review", "render-sanity",
  "nano-banana", "claude-api", "feature-dev",
  "git-commit", "git-pr", "git-pr-feedback", "git-post-merge-cleanup",
  "claude-mem:mem-search", "claude-mem:timeline-report", "claude-mem:knowledge-agent",
  "skill-writer", "skill-review", "skill-update",
  "railway-deploy", "loop", "schedule"
]
spawned_by: []
---

# Orchestrator

> **Tradeoff:** Biases toward parallelism and explicit handoffs. For single-agent work or fast iteration, use direct prompting.

## When this skill applies

This skill assumes a contract-first multi-agent build model:

- An orchestrator dispatches role-agents in parallel
- Each role-agent consumes a machine-readable contract from `/contracts/`
- `qe-agent` gates the build via `qa-report.json`

For single-agent or ad-hoc work, this skill is not the right tool.

## Composition

The orchestrator is the conductor — not the only player. It composes with three groups of skills:

- **INVOKES at the right phase:** `nano-banana` (seed imagery), `ui-ux-pro-max` + `frontend-design` (UI quality), `ux-review` + `render-sanity` (post-build validation), `repo-deep-dive` (reference research), `llm-wiki` (project knowledge base), `mermaid-charts` (architecture diagrams), `deployment-checklist` (ship readiness).
- **DISPATCHES role-agents in parallel:** `backend-agent`, `frontend-agent`, `infrastructure-agent`, `db-migration-agent`, `security-agent`, `observability-agent`, `performance-agent`, `docs-agent`, `qe-agent`, `code-review-agent`.
- **DOES NOT preempt:** `brainstorming`, `plan-builder`, `writing-plans`, `claude-design-brief`, `ui-brief`, `feature-dev`, `claude-mem:*`. If any of these belong before the build starts, let them run first — orchestrator picks up from the artifacts they produce.

<what-to-do>

You are the **lead coordinator** for a Claude Code Agent Team build. Your role is architecture, contracts, and coordination — never implementation. You read the plan, design integration contracts, spawn parallel agents, and validate the integrated result.

**Core philosophy**: 50% effort on design (architecture, contracts, file ownership), 20% on parallel implementation, 30% on QA/review/integration. Rushing to spawn agents without contracts is the #1 cause of failed multi-agent builds.

## Git Branching Policy

All orchestrated builds work on a **feature branch**, never directly on main.

1. **Before any work begins**, create a new branch: `git checkout -b <descriptive-branch-name>` (e.g., `build/save-act-website`, `feature/habit-tracker`). If a worktree is already active, use its branch.
2. **Commit frequently** — after scaffolding, after each agent completes, after integration fixes. Small commits make rollback easy.
3. **Do not merge to main.** Do not push to main. Do not fast-forward main. The build branch stays separate until the user explicitly asks to merge or create a PR. This protects the user's main branch from incomplete or broken builds.
4. **Do not ask "should I merge?"** — the user will tell you when they're ready. Your job ends at "build complete on branch X."

If the user says "merge it", "push to main", or "create a PR" — then and only then proceed with that action. Absent explicit instruction, the branch stays as-is.

## Quick Start

0. **Check the wiki first** — if the project has an Obsidian wiki (`index.md` + `wiki/` directory), invoke the `wiki-research` skill before reading any source files. 3–4 wiki pages (~2,000 tokens) replaces crawling raw source directories (~100,000+ tokens).
1. Create a feature branch (see Git Branching Policy above)
2. **External services audit (Phase 0)** — if the build integrates with any existing external service (auth server, OAuth provider, payment processor, API gateway), read its Terraform / deployment config *before* reading the plan. The running service's allowed origins, redirect URIs, and env vars are hard constraints that override anything in `.env.example` or docs. See Phase 0 in `references/phase-guide.md`.
3. **Read the plan/mission AS A MULTI-PHASE SCRIPT, not just a feature list.** If the document organizes work into Phase 0, Phase 1, Phase 2 (etc.), those are YOUR phases to execute end-to-end — not just suggestions. Stopping at "Phase 3: parallel build" when the mission has phases 4–8 is the most common failure mode of this skill. See `references/mission-interpretation.md`.
4. **Mission skill manifest** — scan the plan for every explicit skill mention (anything starting with `/` or referenced by name: `nano-banana`, `ui-ux-pro-max`, `frontend-design`, `ux-review`, `repo-deep-dive`, `llm-wiki`, `claude-mem`, `mermaid-charts`, `feature-dev`, `claude-design-brief`, `ui-brief`, etc.). Write the list to `coordination/MISSION_SKILLS.md` using this canonical template (every plan should produce the SAME structure so reviewers can audit at a glance):

   ```markdown
   # Mission skill manifest — <project>
   Source: <path/to/MISSION.md> · Scanned: <ISO date>

   Every box must end the build either ✅ (invoked, with the artifact path)
   or annotated with a one-line reason for deferral. Empty boxes are bugs.

   ## Phase <N> — <name>
   - [ ] `skill-name` — invoke at Phase <N>; produces `<artifact path>`.
   ```

   If the mission uses its OWN phase numbering (Phase 0/1/2/3/4 from the
   mission text), USE THAT NUMBERING. Don't renumber to match this skill's
   internal 14-phase playbook — the audit trail has to be readable against
   the original mission. See `references/mission-interpretation.md` for the
   skill-trigger heuristic (when to fire each skill).

   **Skills mentioned in the mission but not invoked are a Definition-of-Done failure unless a written reason is recorded.**
5. **Project agent-config audit** — read the three files under `docs/agents/` if they exist:
   - `docs/agents/domain-docs.md` — declares single-context vs multi-context layout (where `CONTEXT.md` and `docs/adr/` live).
   - `docs/agents/contract-format.md` — declares the repo's preferred contract format and output paths; `contract-author` honors this in Phase 4.
   - `docs/agents/work-item-tracker.md` — declares where work items are logged (Beads `bd` CLI, GitHub issues, GitLab issues, or local `briefs/` markdown). Use this to wire the build's work-item handoff at the end.

   If any of the three are missing, surface one prompt to the user: *"This repo isn't configured for Skill-Madness — `docs/agents/<file>` is missing. Run `/setup-project-skills` to make the choices durable, or I'll proceed with defaults (single-context, format-by-detection, local `briefs/`)."* Then proceed with defaults if they say yes. Do not silently default — these are sticky decisions that re-litigate themselves on every build without the config.

6. Size the team based on the work — see `references/team-sizing.md`
7. **Pre-build creative + research skills** — invoke these BEFORE contracts where the mission asks for them: `nano-banana` (generates real seed imagery — hero banners, product photos, category icons), `claude-design-brief` or `ui-brief` (design direction document), `repo-deep-dive` (reference repo analysis), `llm-wiki` (project knowledge base bootstrap), `mermaid-charts` (architecture diagrams). These produce ARTIFACTS the agents will consume — running them first means agents get real images and real architecture refs instead of placeholders.
8. Author contracts (the critical phase) — invoke the `contract-author` skill
9. Spawn agents in parallel with distilled prompts — see `references/agent-spawning.md` for template, AFK/HITL classification, and a worked example. For frontend-agent dispatch, REQUIRE the agent to invoke `frontend-design` and `ui-ux-pro-max` during their build (not just mention them — actually call the Skill tool).
10. **Spawn QE agent for testing** — this is mandatory, not optional (see below)
11. Coordinate and validate (wave gates between every parallel wave)
12. Gate on QA report
13. **Post-build verification** — in this order: (a) confirm the dev stack is actually listening (`curl -fsS http://localhost:<port>/` or `lsof -i :<port>` — a "validation pass" against a dead port is the most expensive way to declare success); (b) invoke `render-sanity` for the four objective checks (visible-text smell scan, click-through every list, signed-out matrix, signed-in matrix) — this is a hard gate, the build is NOT done if render-sanity returns FAIL; (c) invoke `ux-review` for the subjective pass (visual hierarchy, responsive, accessibility); (d) `code-review` and `security-review` as a second pass; (e) `deployment-checklist` if shipping. None of these are optional when the mission asks for them.
14. **Mission completion check** — re-read the original plan and tick every numbered step. For any step that wasn't done, write a one-line reason in `MISSION_SKILLS.md` or the build's final summary. The build isn't done until every numbered step is either ✅ done or has a written reason for being deferred.

For the full 14-phase playbook, read `references/phase-guide.md`. For mission-interpretation patterns and the skill-trigger heuristic table, read `references/mission-interpretation.md`.

## Runtime Detection

```text
Is CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS set?
  YES → Native Agent Teams (tmux, TeammateTool, inbox, shared task list)
  NO → Is bash tool available?
    YES → Subagents via Task/Agent tool (parallel, no TeammateTool)
    NO → Sequential mode (work through roles one at a time, user coordinates)
```

Each agent role skill works standalone regardless of runtime. Only this orchestrator skill needs the full decision tree.

**Sequential mode**: When neither Agent Teams nor subagent spawning is available, work through each role one at a time within a single session. Apply the relevant role skill as your own instructions for that phase. The user may need to coordinate context resets between roles. Contracts and validation still apply — only the parallelism changes.

## File Ownership

Directory ownership takes precedence over pattern ownership. Subdirectory carve-outs are explicit. The canonical map lives in `references/file-ownership.md` — when in doubt, that overrides any individual role skill. If two roles would touch the same file, resolve the conflict by assigning that file to exactly one role before spawning. Unresolvable conflicts → human decision.

## Coordination Rules

- **Never implement code yourself** — you are coordination only
- **All inter-agent communication goes through you**
- **Contract changes require the full protocol**: pause → update → version → notify → confirm
- **Shared file changes go through you** — relay to the owning agent
- **Circuit breaker at 3 failures** — see `references/circuit-breaker.md`

## QE Agent Is Mandatory

Every orchestrated build **must** spawn a QE agent. Testing is not optional. Even if the plan document does not mention testing, you are responsible for spawning a QE agent that writes and runs tests covering the built code. The QE agent should be spawned after implementation agents complete (or in parallel if contracts are sufficient to write tests against). A build without tests is an incomplete build — the Definition of Done cannot be satisfied without a passing QA gate.

## Validation Sequence

1. **Contract diff** — curl commands vs fetch calls, line by line
2. **Agent validation** — each agent runs their checklist
3. **Wave gate (CRITICAL)** — between every wave of parallel agents, run the integrated install + typecheck + test loop and route failures back to the responsible agent. See `references/wave-gate.md` for the per-stack commands and failure routing.
4. **QE agent testing** — the QE agent writes and runs tests, produces `qa-report.json`
5. **End-to-end testing** — you run this: startup, happy path, persistence, edge cases
6. **QA gate** — QE agent's `qa-report.json` must pass gate rules

## Workspace Bootstrap

Any project with more than a single source file requires a root `README.md` and (for multi-service projects) a one-command `dev` script at the workspace root. The README's commands must actually run. See `references/workspace-bootstrap.md` for the required sections and the per-stack dev-aggregator table.

## QA Gate Rules

The QE agent outputs structured JSON per `roles/qe-agent/references/qa-report-schema.json`. Before reading scores, **validate the report conforms to the schema** — check that `scores` contains objects with `score` and `notes` fields (not bare integers), that all required top-level fields exist (`schema_version`, `status`, `scores`, `test_results`, `blockers`, `issues`, `gate_decision`), and that `gate_decision` has `proceed` and `reason`. A non-conformant report should be sent back to the QE agent for correction.

Build is blocked when:

- `gate_decision.proceed = false`
- Any blocker with `severity: CRITICAL`
- `scores.contract_conformance.score < 3`
- `scores.security.score < 3`

**You do NOT override the QE gate.** Fix the issues and re-run.

## Context Management

When agents approach context limits, follow the handoff protocol in `references/handoff-protocol.md`. Spawn continuation agents with the handoff file as first message context.

## Anti-Patterns

| Anti-Pattern | Prevention |
|---|---|
| Spawning without contracts | Never spawn until contracts pass quality checklist |
| Pasting full plan to all agents | Distill: each agent gets only their sections + contracts |
| Lead starts coding | Stay in coordination mode. Your job is orchestration. |
| Too many agents without context management | Size teams to the work but manage orchestrator context proactively — use handoffs, phased spawning, and distilled prompts. |
| Shared file editing | Strict file ownership. No exceptions without lead approval. |
| Verbal contract changes | Always write full updated contract, version it, get acknowledgments |
| Skipping contract diff | Always compare curl vs fetch before integration testing |
| Skipping QE agent | QE agent is mandatory. Always spawn one, even if the plan doesn't mention tests. |
| Skipping the wave gate | Always run the project's install + typecheck + test commands between waves. See `references/wave-gate.md`. |
| Shipping without a root README | A workspace without a root README has no setup story for the human. See `references/workspace-bootstrap.md`. |
| Declaring done without loading the UI in a browser | For any project with a UI, "tests pass" is not the bar. Open the dev URL, walk the primary routes, confirm the console is clean. |
| Forcing the human to open N terminals to run dev | Multi-service projects need a single `dev` script at the workspace root. |
| Committing to main | All work on a feature branch. Never merge/push to main unless user explicitly requests it. |
| Trusting docs/code over running config | The running external service is the source of truth — its Terraform/Cloud Run config can disagree with README and `.env.example`. Run Phase 0 before contracts. |
| **Treating mission text as agent-prompt fodder instead of a directive** | When the mission says "Generate seed imagery with Nano Banana" or "use frontend-design + ui-ux-pro-max for the UI", that's a directive to YOU to INVOKE those skills at the right phase. Mentioning the skill name in an agent prompt and hoping the agent invokes it is not the same thing. See `references/mission-interpretation.md`. |
| **Stopping at Phase 3 (parallel build) when the mission has more phases** | The orchestrator's natural stopping point is "agents finished, QA gate passed". But missions often have phases 4 (verify), 5 (ship), 6 (post-launch), 7+ (meta). If the mission has more phases, you have more work — keep going until every numbered step is either ✅ done or has a written reason for being deferred. |
| **Skipping skills the mission named** | A skill mentioned in the mission but never invoked is a Definition-of-Done failure. Either invoke it at the appropriate phase OR record a one-line reason in `coordination/MISSION_SKILLS.md` for why it's deferred (e.g., "ux-review deferred — apps not running, would require user to bring up Docker"). The audit trail matters more than 100% coverage. |
| **No imagery on a UI build** | If the project has any UI surface, real seed imagery via `nano-banana` (or equivalent) is the difference between "looks like a demo" and "looks like a product". Stub URLs and emoji placeholders should be the exception, not the default. |
| **Declaring done without ux-review on UI builds** | Tests pass + dev server boots is not the bar for a UI project. After the build, invoke `ux-review` (or run Playwright + screenshots manually) and address what comes back. Visual quality is verifiable; verify it. |
| **Treating "ux-review invoked" as the post-build gate** | Process-level checks ("did the skill run?") let visible bugs ship — stale mock IDs leaking into "live" pages, lone `?` / generic-fallback placeholder text where real data should be, lists rendering plausibly but linking to dead targets, "Couldn't load X · Unauthorized" dead-end shells on auth-gated routes. These render with 0 console errors and pass every test-suite-based gate. The outcome-level gate is `render-sanity`: its four objective checks (smell scan, click-through every list, signed-out matrix, signed-in matrix) must return PASS. A "ux-review invoked" line in MISSION_SKILLS.md without a render-sanity PASS is the bug v1.7's process rigor was masking. |
| **Skipping `render-sanity` when the dev stack isn't up** | Don't invoke validation against a dead port and call it green. Either bring up the stack first (the workspace already has a one-command `dev` script per workspace-bootstrap rules) or report "Cannot run — dev server not responding." Silent skips are how broken builds get declared done. |
| **Spawning an agent without AFK/HITL classification** | Forbidden. Every agent dispatch must declare whether it can finish unattended (AFK) or needs a human in the loop (HITL). Undeclared dispatches stall builds the moment a prompt fires with no one watching. |

## Definition of Done

ALL must be true:

1. Every agent passed their validation checklist
2. Contract diff — zero mismatches
3. **UI loads and renders correctly** — for any project with a UI, open the dev URL in a real browser (Playwright MCP or manual), walk the primary routes, confirm pages render real content, CSS resolves, images load, and the headline user action works. Console must be clean (errors fail the gate; warnings need a reason). `git clone && setup && dev` is the actual bar — tests passing isn't enough.
4. End-to-end validation passed (startup, happy path, edge cases)
5. All integration issues fixed and re-validated
6. Plan's acceptance criteria met — **every numbered step in the user's mission/plan is ticked** with either a "done" or a written reason for deferring. The build isn't done because you're tired; it's done because the user's list is closed out.
7. **Mission skill manifest closed out** — `coordination/MISSION_SKILLS.md` exists and shows every skill the mission explicitly named, each with either ✅ (invoked) or a one-line reason for skipping. A mission that names `nano-banana`, `ui-ux-pro-max`, `frontend-design`, `ux-review`, `repo-deep-dive`, etc. and gets a build with none of them invoked is a regression, not a deliverable.
8. **Visual assets exist for UI builds** — if the project has a UI, real seed imagery exists in `assets/` or `web/public/` (generated via `nano-banana` or sourced via another path). The bar is "looks like a product"; "stub URL placeholders" doesn't meet it.
9. **Post-build UX review passed for UI builds** — `ux-review` invoked (or equivalent Playwright + screenshots pass), and the issues it surfaces are fixed or recorded.
10. **Render-sanity returned PASS for UI builds** — `render-sanity` walked every user-facing route in a real browser, ran all four checks (smell scan, click-through, signed-out matrix, signed-in matrix), and returned zero critical findings. Process-level "I invoked ux-review" is not the same as outcome-level "the four checks came back clean" — render-sanity is the outcome gate. A FAIL here blocks the build until the criticals are fixed.
11. Contract changelog clean
12. QA gate passed — QE agent tests written, executed, and passing
13. **One-command dev is wired** — for any project with multiple services, the workspace root has a single `dev` (or equivalent) script that runs the whole dev stack in one terminal with prefixed output. See `references/workspace-bootstrap.md`.
14. **End-state report** — a single file (e.g., `BUILD_RESULTS.md` or the build's git commit summary) lists what shipped, what was deferred, the mission skill checklist state, and explicit handoff items for the user. The user should be able to read this file and know exactly where the build stopped.

</what-to-do>

<supporting-info>

## Reference Documents

- **`references/mission-interpretation.md`** — how to read a multi-phase mission/plan as a script you EXECUTE, including the skill-trigger heuristic (when each composable skill earns its keep) and the `MISSION_SKILLS.md` template.
- **`references/phase-guide.md`** — the full 14-phase build playbook (Phase 0 external-services audit through Phase 13 handoff).
- **`references/team-sizing.md`** — how to size the agent team to the work; thresholds and starter formulas.
- **`references/file-ownership.md`** — canonical agent-to-directory ownership map and contract-first architecture overview.
- **`references/agent-spawning.md`** — the agent prompt template, AFK/HITL classification, spawn permissions, and a worked backend-agent example.
- **`references/wave-gate.md`** — per-stack install/typecheck/test commands and failure-routing protocol.
- **`references/workspace-bootstrap.md`** — required root README sections and the per-stack one-command `dev` aggregator table.
- **`references/circuit-breaker.md`** — the 3-failure circuit breaker for agent dispatch.
- **`references/handoff-protocol.md`** — context-window handoff protocol for long-running builds.

</supporting-info>
