---
name: railway-deploy
version: 1.2.0
description: >
  Deploy projects to Railway — handles Dockerfile creation, railway.toml config, environment variables,
  multi-service setups (web + worker), and deployment via CLI or GraphQL API. Use this skill whenever
  the user mentions "deploy", "Railway", "push to production", "ship it", "put this online", "deploy to staging",
  or wants to set up hosting for a web app, API, or background worker. Also trigger when the user asks about
  Railway configuration, health checks, deployment status, or environment variable management on Railway.
  This is the go-to skill for any Railway deployment workflow.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: ["railway.toml"]
  shared_read: ["*"]
allowed_tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
composes_with: ["infrastructure-agent", "deployment-checklist"]
spawned_by: []
---

# Railway Deployment

Deploy projects to Railway with proper Dockerfile, config, and multi-environment support.

## How Railway Works

Railway builds and runs your app from a Dockerfile (or auto-detects with Nixpacks). Each project can have multiple **services** (web, worker, cron) across multiple **environments** (dev, production). Railway assigns a dynamic `PORT` env var that your app must listen on.

## Prerequisites

**Railway credentials** (for GraphQL API deployments) go in the Skill Madness root `.env` file — see `.env.example` for the full list. Get your API token at https://railway.app/account/tokens.

**Railway CLI** should be installed and authenticated. Verify:

```bash
railway --version    # Should show v4.x+
railway whoami       # Should show logged-in user
```

If not installed: `brew install railway` (macOS) or `npm i -g @railway/cli`, then `railway login`.

## Deployment Approaches

Railway supports two deployment methods. Choose based on the project's needs:

### Approach 1: Railway CLI (simple projects)

Best for quick deploys, single-service apps, and projects where you want Railway to auto-detect the build.

```bash
# Link to existing project (or create new)
railway link          # Interactive — select project + environment
# OR
railway init          # Create new project

# Deploy
railway up            # Builds and deploys from current directory

# Check status
railway status
railway logs
```

### Approach 2: GraphQL API + Deploy Script (multi-service, CI/CD)

Best for projects with multiple services (web + worker), automated deployments, or when you need programmatic control. See `references/deploy-script.md` for a ready-to-use deploy script pattern.

## Setting Up a New Project for Railway

1. **Detect the stack.** Read `package.json` / `requirements.txt` / `Cargo.toml` / `go.mod` to identify language, framework, entry point, and system deps. See `references/dockerfile-recipes.md` for the full stack detection checklist.

2. **Create the Dockerfile.** Pick the recipe matching your stack — `references/dockerfile-recipes.md` has Python/FastAPI, Node.js/Express/Next.js, and Astro templates, plus Dockerfile best practices.

3. **Create `railway.toml`.** The standard template with `startCommand`, `healthcheckPath`, `restartPolicyType` is in `references/dockerfile-recipes.md`.

4. **Create `.dockerignore`.** Exclude dev deps, local DBs, build artifacts. Template in `references/dockerfile-recipes.md`.

5. **Add a health check endpoint.** Railway uses it to know when the app is ready. Python/FastAPI and Node/Express snippets are in `references/dockerfile-recipes.md`.

6. **Optional: Procfile fallback.** Railway prefers Dockerfile but falls back to Procfile — see `references/dockerfile-recipes.md`.

## Environment Variables, Multi-Service, Troubleshooting

For env var management (`railway variables set`), multi-service setups (web + worker on the same project), the full deployment checklist, and troubleshooting common deploy failures (build errors, crash loops, health check timeouts, 502 errors, port binding), read `references/multi-service-setup.md`.

## Reference Files

- `references/dockerfile-recipes.md` — per-language Dockerfile templates (Python, Node, Astro), railway.toml, .dockerignore, health check endpoints, Procfile
- `references/multi-service-setup.md` — env vars, multi-service (web + worker), deployment checklist, troubleshooting
- `references/deploy-script.md` — Python deploy script pattern using Railway's GraphQL API
