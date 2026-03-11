---
name: deployment-checklist
version: 1.0.0
description: |
  Run pre-deployment verification checklists before pushing to staging or production. Use this skill when preparing for deployment, running pre-deploy checks, verifying environment configs, or validating build artifacts. Trigger for any deployment preparation or release readiness task.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed_tools: ["Read", "Bash", "Glob", "Grep"]
composes_with: ["infrastructure-agent", "qe-agent"]
spawned_by: ["orchestrator"]
license: MIT
author: john-ladwig
---

# Deployment Checklist

Run pre-deployment verification before pushing to staging or production.

## Role

You verify that a build is ready for deployment by running through a structured checklist. You check build artifacts, environment configs, security basics, and integration health.

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
