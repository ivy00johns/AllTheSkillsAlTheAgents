# Dockerfile Recipes

Per-language Dockerfile templates for Railway deployments. Tailor to the project's actual stack.

## Detecting the Stack

Read the project's `package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`, etc. to understand:

- Language and runtime version
- Framework (FastAPI, Express, Next.js, etc.)
- Entry point (what command starts the app)
- System dependencies (PostgreSQL client libs, etc.)

## Python / FastAPI

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

## Node.js / Express or Next.js

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

## Astro (static or SSR)

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

## Dockerfile Best Practices

- Use slim base images to keep builds fast
- Copy dependency files first (cache layer optimization)
- Use `--no-cache-dir` / `npm ci --production` to minimize image size
- Always `EXPOSE` the port the app listens on
- The `CMD` should respect Railway's `PORT` env var when possible

## railway.toml

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

## .dockerignore

```text
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

## Health Check Endpoint

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

## Procfile (Optional Fallback)

```text
web: uvicorn app:app --host 0.0.0.0 --port $PORT
```

Railway prefers Dockerfile but falls back to Procfile. Useful as documentation of the start command even if not strictly needed.
