# Backend Agent Validation Checklist

Run ALL before reporting done. Fix failures. Substitute actual endpoints from the API contract.

> **The single most important gate is at the bottom of this file: run the package's own typecheck and test scripts.** Grep-based validation alone is not sufficient — it cannot catch decorator-encapsulation bugs, missing dependency declarations, or wrong runtime behavior. If your package has a `test` or `typecheck` script, you run it. If it fails, you fix it. Only then do you report done.

## Typecheck and tests pass (start here, not at the end)

Run the project's own scripts for your package — whatever the stack provides:

| Stack | Typecheck | Test |
|---|---|---|
| Node (pnpm workspace) | `pnpm --filter <pkg> run typecheck` | `pnpm --filter <pkg> run test` |
| Node (npm / yarn) | `npm run typecheck` (in package dir) | `npm test` |
| Python (FastAPI/Django) | `mypy .` or `ruff check .` | `pytest` |
| Go | `go vet ./...` | `go test ./...` |
| Rust | `cargo check` | `cargo test` |
| Ruby (Rails) | `bundle exec rubocop` | `bundle exec rspec` |
| .NET | `dotnet build` | `dotnet test` |

If your package can't be tested in isolation because it depends on workspace siblings that aren't built yet, surface that as a blocker to the orchestrator BEFORE reporting done. Do not report done with a known-failing typecheck or test.

**`test` script defaults to run-once, not watch mode.** When you wire up the package's test script, the canonical entry point — `npm test` / `pnpm test` / `yarn test` — must run the suite once and exit. Watch mode goes under `test:watch`. The reason: workspace-level recursive runs (`pnpm -r run test`, `npm run test --workspaces`) and CI invoke `test`; if `test` boots vitest/jest in watch mode, it runs the suite then sits forever waiting for file changes, hanging the wave gate and CI for ~10 minutes per package until the timeout fires. Standard pattern:

```json
// ✅ Right
"scripts": {
  "test": "vitest run",
  "test:watch": "vitest"
}

// ❌ Wrong — wave gate / CI hangs
"scripts": {
  "test": "vitest",
  "test:run": "vitest run"
}
```

Same idea for jest (`jest` not `jest --watch`), pytest (`pytest` is run-once by default — fine), Go (`go test ./...` is run-once — fine), Cargo (`cargo test` is run-once — fine). The trap is mostly Vitest/Jest-specific because their bare invocation defaults differ across versions.

## Fastify-specific: plugins must escape their encapsulation context

If you're writing Fastify plugins (anything that calls `app.decorate(...)`, `app.addHook(...)`, `app.setErrorHandler(...)`, or `app.setNotFoundHandler(...)`), the plugin MUST be wrapped with `fastify-plugin`'s `fp()` or its decorations stay inside the plugin's local scope and are invisible to siblings.

```ts
// ❌ Wrong — decorations are encapsulated, sibling routes won't see app.requireUser
export async function authPlugin(app: FastifyInstance) {
  app.decorate('requireUser', requireUser);
}

// ✅ Right — fp() breaks encapsulation, decoration applies to the parent instance
import fp from 'fastify-plugin';
async function authPluginImpl(app: FastifyInstance) {
  app.decorate('requireUser', requireUser);
}
export const authPlugin = fp(authPluginImpl, { name: 'auth' });
```

Symptoms when this is wrong: routes throw `app.requireUser is not a function` at runtime → 500 errors across every test, hours wasted because the typecheck still passes (the type declaration via `declare module 'fastify'` is global and unaffected).

This applies equally to plugins that set the global error handler or the not-found handler — without `fp()`, those handlers don't see exceptions from sibling-registered route plugins.

## Server Starts

```bash
# FastAPI: uvicorn main:app --port ${PORT}
# Express: node server.js or npm run dev
# Django: python manage.py runserver ${PORT}
# Go: go run main.go
# Expected: starts without errors, listening on configured port
```

## Database Initializes

```bash
# SQLAlchemy: python -c "from db import engine; from models import Base; Base.metadata.create_all(engine)"
# Prisma: npx prisma db push
# Django: python manage.py migrate
# EF Core: dotnet ef database update
# Expected: no errors, tables created
```

## Every Contracted Endpoint Works

For each endpoint in the API contract, verify with curl. Substitute your actual URLs and payloads:

```bash
# Create (POST)
curl -s -X POST http://localhost:${PORT}/${contracted-path} \
  -H "Content-Type: application/json" \
  -d '{"field": "value"}' | python3 -m json.tool
# Verify: status matches contract (e.g. 201), response shape matches contract

# Read (GET)
curl -s http://localhost:${PORT}/${contracted-path}/{id} | python3 -m json.tool
# Verify: status 200, response shape matches contract

# Update (PUT/PATCH)
curl -s -X PATCH http://localhost:${PORT}/${contracted-path}/{id} \
  -H "Content-Type: application/json" \
  -d '{"field": "updated"}' | python3 -m json.tool
# Verify: status matches contract, updated fields reflected

# Delete (DELETE)
curl -s -o /dev/null -w "%{http_code}" -X DELETE http://localhost:${PORT}/${contracted-path}/{id}
# Verify: status matches contract (e.g. 204), subsequent GET returns 404

# Error case
curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT}/${contracted-path}/nonexistent
# Verify: status 404, error envelope matches contract
```

## Error Handling

```bash
# Empty body → 422 with error envelope (not 500)
curl -s -X POST http://localhost:${PORT}/${contracted-path} \
  -H "Content-Type: application/json" -d '{}'

# Malformed JSON → 400 or 422 (not 500)
curl -s -X POST http://localhost:${PORT}/${contracted-path} \
  -H "Content-Type: application/json" -d 'not json'

# Not found → 404 with error envelope
curl -s http://localhost:${PORT}/${contracted-path}/does-not-exist
```

## CORS Headers

```bash
# Substitute the actual frontend origin from the contract or project profile
curl -s -I -X OPTIONS http://localhost:${PORT}/${contracted-path} \
  -H "Origin: ${FRONTEND_ORIGIN}" \
  -H "Access-Control-Request-Method: POST" \
  | grep -i "access-control"
# Expected: Access-Control-Allow-Origin includes frontend origin
```

## Data Persistence

```bash
# 1. Create a resource
RESOURCE_ID=$(curl -s -X POST http://localhost:${PORT}/${contracted-path} \
  -H "Content-Type: application/json" \
  -d '{"field": "persistence-test"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# 2. Stop the server (Ctrl+C or kill the process)
# 3. Restart the server

# 4. Retrieve — data must still exist
curl -s http://localhost:${PORT}/${contracted-path}/${RESOURCE_ID} | python3 -m json.tool
# Verify: resource exists and matches what was created
```

## SSE/Streaming (if applicable)

```bash
# Verify streaming endpoint returns event-stream content type
curl -s -N -X POST http://localhost:${PORT}/${stream-path} \
  -H "Content-Type: application/json" \
  -d '{"field": "value"}' &
CURL_PID=$!
sleep 3
kill $CURL_PID 2>/dev/null
# Verify: received chunk events, done event, correct event shapes per contract

# Verify accumulated data is stored
curl -s http://localhost:${PORT}/${resource-path}/{id} | python3 -m json.tool
# Verify: accumulated content matches streamed chunks
```

## Environment Configuration

```bash
# .env.example exists with placeholder values
test -f .env.example && echo "PASS" || echo "FAIL: .env.example missing"

# .env is gitignored
grep -q ".env" .gitignore && echo "PASS" || echo "FAIL: .env not in .gitignore"

# No hardcoded connection strings or secrets in source
grep -rn "postgresql://\|mysql://\|mongodb://\|sk-\|password=" src/ \
  --include="*.py" --include="*.ts" --include="*.js" --include="*.go" \
  | grep -v ".env" | grep -v "node_modules"
# Expected: zero matches
```
