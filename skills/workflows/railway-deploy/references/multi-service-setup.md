# Multi-Service Setup, Env Vars, and Troubleshooting

How to wire web + worker setups, manage environment variables, and debug deploys that fail.

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

- **Build fails:** Check Dockerfile locally with `docker build .`. Common issues: missing system deps, wrong Python/Node version.
- **Deploy succeeds but app crashes:** Check `railway logs`. Usually a missing env var or wrong start command.
- **Health check timeout:** Increase `healthcheckTimeout` in railway.toml. Default 60s is usually enough but large apps may need more.
- **Port mismatch:** Make sure your app binds to `0.0.0.0` (not `localhost`) on `$PORT`.
- **502 errors after deploy:** The app isn't binding to the Railway-assigned PORT. Check the start command uses `${PORT}`.
