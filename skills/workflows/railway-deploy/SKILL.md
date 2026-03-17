---
name: railway-deploy
version: 1.0.0
description: >
  Deploy projects to Railway — handles Dockerfile creation, railway.toml config, environment variables,
  multi-service setups (web + worker), and deployment via CLI or GraphQL API. Use this skill whenever
  the user mentions "deploy", "Railway", "push to production", "ship it", "put this online", "deploy to staging",
  or wants to set up hosting for a web app, API, or background worker. Also trigger when the user asks about
  Railway configuration, health checks, deployment status, or environment variable management on Railway.
  This is the go-to skill for any Railway deployment workflow.
requires_claude_code: true
---

# Railway Deployment

Deploy projects to Railway with proper Dockerfile, config, and multi-environment support.

## How Railway Works

Railway builds and runs your app from a Dockerfile (or auto-detects with Nixpacks). Each project can have multiple **services** (web, worker, cron) across multiple **environments** (dev, production). Railway assigns a dynamic `PORT` env var that your app must listen on.

## Prerequisites

**Railway credentials** (for GraphQL API deployments) go in the AllTheSkillsAllTheAgents root `.env` file — see `.env.example` for the full list. Get your API token at https://railway.app/account/tokens.

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

Best for projects with multiple services (web + worker), automated deployments, or when you need programmatic control. See the `references/deploy-script.md` file for a ready-to-use deploy script pattern.

## Setting Up a New Project for Railway

### Step 1: Detect the Stack

Read the project's package.json, requirements.txt, Cargo.toml, go.mod, etc. to understand:
- Language and runtime version
- Framework (FastAPI, Express, Next.js, etc.)
- Entry point (what command starts the app)
- System dependencies (PostgreSQL client libs, etc.)

### Step 2: Create Dockerfile

Railway works best with an explicit Dockerfile. Tailor it to the stack:

**Python / FastAPI pattern:**
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# System deps (if needed for PostgreSQL, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Node.js / Express or Next.js pattern:**
```dockerfile
FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci --production

COPY . .

RUN npm run build  # if needed

EXPOSE 3000
CMD ["node", "server.js"]
```

**Astro (static or SSR) pattern:**
```dockerfile
FROM node:20-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-slim
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json .
EXPOSE 4321
CMD ["node", "./dist/server/entry.mjs"]
```

Adapt the pattern to the project. The important things:
- Use slim base images to keep builds fast
- Copy dependency files first (cache layer optimization)
- Use `--no-cache-dir` / `npm ci --production` to minimize image size
- Always `EXPOSE` the port the app listens on
- The `CMD` should respect Railway's `PORT` env var when possible

### Step 3: Create railway.toml

```toml
[build]
# Empty = use Dockerfile. Can add buildCommand here for Nixpacks.

[deploy]
startCommand = "your-start-command --host 0.0.0.0 --port ${PORT:-8000}"
healthcheckPath = "/health"
healthcheckTimeout = 60
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 5
```

The `startCommand` in railway.toml overrides the Dockerfile CMD — useful for tuning without rebuilding. If the Dockerfile CMD is sufficient, you can omit it.

### Step 4: Create .dockerignore

```
node_modules
.git
.env
*.sqlite
*.db
__pycache__
.pytest_cache
.venv
dist
.next
```

Exclude anything not needed at runtime — dev dependencies, local databases, version control.

### Step 5: Add a Health Check Endpoint

Railway uses health checks to know when your app is ready. Add one if it doesn't exist:

**Python/FastAPI:**
```python
@app.get("/health")
def health():
    return {"status": "ok"}
```

**Node.js/Express:**
```javascript
app.get('/health', (req, res) => res.json({ status: 'ok' }));
```

### Step 6: Create a Procfile (optional fallback)

```
web: uvicorn app:app --host 0.0.0.0 --port $PORT
```

Railway prefers Dockerfile but falls back to Procfile. Useful as documentation of the start command even if not strictly needed.

## Environment Variables

Set env vars through the Railway dashboard or CLI:

```bash
railway variables set KEY=value           # Current environment
railway variables set KEY=value -e prod   # Specific environment
```

Common vars to set:
- `DATABASE_URL` — Railway provides this automatically for Railway PostgreSQL
- Any API keys the app needs
- `NODE_ENV=production` or equivalent
- `PORT` — Railway sets this automatically, don't override it

## Multi-Service Setup (Web + Worker)

For projects needing background workers alongside the web service:

1. Create a separate Dockerfile for the worker (e.g., `Dockerfile.worker`)
2. In Railway dashboard: add a new service to the project
3. Point the new service at the same repo but select the worker Dockerfile
4. Both services share the same environment variables

Read `references/deploy-script.md` for a Python script pattern that manages multi-service deployments programmatically via Railway's GraphQL API.

## Deployment Checklist

Before deploying, verify:

- [ ] Dockerfile builds locally: `docker build -t test .`
- [ ] App respects `PORT` env var (Railway assigns this dynamically)
- [ ] Health check endpoint exists and returns 200
- [ ] `.dockerignore` excludes dev-only files
- [ ] Secrets are in Railway env vars, not committed to repo
- [ ] `railway.toml` has correct start command (if overriding Dockerfile CMD)

## Troubleshooting

- **Build fails**: Check Dockerfile locally with `docker build .`. Common issues: missing system deps, wrong Python/Node version.
- **Deploy succeeds but app crashes**: Check `railway logs`. Usually a missing env var or wrong start command.
- **Health check timeout**: Increase `healthcheckTimeout` in railway.toml. Default 60s is usually enough but large apps may need more.
- **Port mismatch**: Make sure your app binds to `0.0.0.0` (not `localhost`) on `$PORT`.
- **502 errors after deploy**: The app isn't binding to the Railway-assigned PORT. Check the start command uses `${PORT}`.
