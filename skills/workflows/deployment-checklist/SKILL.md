---
name: deployment-checklist
version: 1.2.0
description: |
  Run pre-deployment verification checklists before pushing to staging or production. Use this skill when preparing for deployment, running pre-deploy checks, verifying environment configs, or validating build artifacts. Trigger on: "pre-deploy check", "deployment checklist", "ready to ship", "is this ready for prod", "deploy readiness", "release checklist", "can we deploy", "verify the build", "pre-flight check".
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed_tools: ["Read", "Write", "Bash", "Glob", "Grep"]
composes_with: ["infrastructure-agent", "qe-agent", "security-agent", "observability-agent"]
spawned_by: ["orchestrator"]
---

# Deployment Checklist

Run pre-deployment verification before pushing to staging or production.

## Role

You verify that a build is ready for deployment by running through a structured checklist. You check build artifacts, environment configs, security basics, and integration health.

## Inputs

- **Target environment** — `staging` or `production` (determines which checks apply and which URLs to verify)
- **QA report** — the qe-agent's `qa-report.json` must show `gate_decision.proceed: true` before you run; if QA hasn't passed, block deployment
- **Infrastructure state** — the infrastructure-agent should have completed Docker builds, health check endpoints, and CI/CD config before this checklist runs
- **Project profile** — `CLAUDE.md` / `.claude/profile.yaml` for environment-specific commands and URLs

## Coordination

- **qe-agent**: Deployment-checklist runs *after* the QE gate passes. If `qa-report.json` shows `gate_decision.proceed: false`, do not proceed — report the blocker to the orchestrator.
- **infrastructure-agent**: Infrastructure-agent owns Docker, CI/CD, and deployment configs. Deployment-checklist *validates* their output (Docker builds, health checks, resource limits) but does not modify infrastructure files. Route infrastructure failures back to the infrastructure-agent via the orchestrator.
- **Orchestrator**: Report the final `READY / NOT READY` verdict to the orchestrator. Include the structured report so it can be appended to the build record.

## Process

Run through `references/pre-deploy.md` in order. Each section must pass before moving to the next. Report results as a structured checklist.

### Quick Reference

1. **Build Verification** — does it compile/build cleanly?
2. **Test Verification** — do all tests pass?
3. **Environment Config** — are all env vars set?
4. **Security Basics** — no secrets in code, no debug mode?
5. **Database** — migrations applied, rollback tested?
6. **Infrastructure** — Docker builds, health checks pass?
7. **Integration** — services connect, CORS works?

### Required Step Before Sign-Off

After all seven sections pass, run the assumption audit — see `references/assumption-audit.md` — and resolve the most-dangerous assumption before issuing the final `READY` verdict. A clean checklist with an unexamined load-bearing assumption is still a `NOT READY`.

## Reference Documents

- **`references/pre-deploy.md`** — the seven-section pre-deploy checklist with commands and acceptance criteria.
- **`references/assumption-audit.md`** — required pre-sign-off discipline that surfaces explicit and implicit assumptions, names the most-dangerous one, and defines executable tests for each implicit assumption.

## Output

```markdown
# Pre-Deployment Report
Environment: [staging | production]
Generated: [timestamp]

## Results
| Check | Status | Notes |
|-------|--------|-------|
| Build | PASS/FAIL | |
| Tests | PASS/FAIL | X passed, Y failed |
| Env Config | PASS/FAIL | |
| Security | PASS/FAIL | |
| Database | PASS/FAIL | |
| Infrastructure | PASS/FAIL | |
| Integration | PASS/FAIL | |

## Blockers (if any)
[List of issues preventing deployment]

## Verdict
READY / NOT READY
```
