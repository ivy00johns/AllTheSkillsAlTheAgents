# Tech Stacks Reference

Quick-reference for validation commands, project structure, and common gotchas across popular stacks. The lead uses this during Phase 2 (Agent Definition) and Phase 4 (Contracts) to fill in stack-specific details. Agents reference it for validation commands.

---

## Frontend Stacks

### React + TypeScript + Vite

**Scaffold**: `npm create vite@latest frontend -- --template react-ts`

**Validation commands:**

```bash
cd frontend
npx tsc --noEmit                    # Type checking
npm run build                       # Production build
npm run dev                         # Dev server (default: localhost:5173)
npm run lint                        # Linting (if eslint configured)
```

**API proxy (dev):** In `vite.config.ts`:

```typescript
export default defineConfig({
  server: {
    proxy: { '/api': 'http://localhost:8000' }
  }
})
```

**Env vars:** Prefix with `VITE_` — e.g., `VITE_API_URL`

**Gotchas:**

- Vite uses port 5173 by default (not 3000)
- Env vars must start with `VITE_` or they're not exposed to client code
- `import.meta.env.VITE_API_URL` (not `process.env`)

---

### Next.js + TypeScript

**Scaffold**: `npx create-next-app@latest frontend --typescript --app`

**Validation commands:**

```bash
cd frontend
npx tsc --noEmit
npm run build                       # Also runs type checking
npm run dev                         # Dev server (default: localhost:3000)
npm run lint
```

**API proxy:** In `next.config.js` using `rewrites`:

```javascript
module.exports = {
  async rewrites() {
    return [{ source: '/api/:path*', destination: 'http://localhost:8000/api/:path*' }]
  }
}
```

**Env vars:** Prefix with `NEXT_PUBLIC_` for client-side, no prefix for server-side

**Gotchas:**

- App Router (app/) vs Pages Router (pages/) — check which the plan uses
- Server Components can't use browser APIs
- `next build` fails on type errors by default (good — catches issues early)

---

### Vue 3 + TypeScript + Vite

**Scaffold**: `npm create vue@latest frontend` (select TypeScript)

**Validation commands:**

```bash
cd frontend
npx vue-tsc --noEmit               # Type checking (note: vue-tsc, not tsc)
npm run build
npm run dev                         # Default: localhost:5173
```

**Env vars:** Prefix with `VITE_` (same as React + Vite)

**Gotchas:**

- Use `vue-tsc` for type checking, not `tsc` (handles `.vue` SFCs)
- Pinia for state management (Vuex is legacy)
- Composition API (`<script setup>`) is the modern default

---

### Svelte + TypeScript + Vite (SvelteKit)

**Scaffold**: `npm create svelte@latest frontend`

**Validation commands:**

```bash
cd frontend
npm run check                       # Type checking + Svelte checks
npm run build
npm run dev                         # Default: localhost:5173
```

**Gotchas:**

- SvelteKit has server-side routes (`+server.ts`) — make sure frontend agent doesn't accidentally create API routes
- `$lib` alias for `src/lib/`
- Form actions vs API calls — clarify in the plan which pattern to use

---

## Backend Stacks

### FastAPI (Python)

**Setup:**

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install fastapi uvicorn sqlalchemy pydantic
pip freeze > requirements.txt
```

**Validation commands:**

```bash
cd backend
uvicorn main:app --port 8000        # Start server
python -m pytest tests/ -v          # Run tests (if they exist)
ruff check .                        # Linting (if ruff installed)
```

**CORS setup:**

```python
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(CORSMiddleware, allow_origins=["http://localhost:5173"], allow_methods=["*"], allow_headers=["*"])
```

**Env vars:** `python-dotenv` or `pydantic-settings`:

```python
from pydantic_settings import BaseSettings
class Settings(BaseSettings):
    database_url: str = "sqlite:///./app.db"
    frontend_origin: str = "http://localhost:5173"
    class Config:
        env_file = ".env"
```

**Gotchas:**

- FastAPI auto-generates OpenAPI docs at `/docs` — useful for QE testing
- Async endpoints (`async def`) vs sync (`def`) — async for I/O-bound work
- SQLAlchemy 2.0 syntax differs significantly from 1.x
- `uvicorn main:app --reload` for development (auto-restart on changes)

---

### Express + TypeScript (Node)

**Setup:**

```bash
cd backend
npm init -y
npm install express cors dotenv
npm install -D typescript @types/express @types/cors ts-node nodemon
npx tsc --init
```

**Validation commands:**

```bash
cd backend
npx tsc --noEmit                    # Type checking
npx ts-node src/index.ts            # Start server (dev)
npm test                            # Run tests (if configured)
```

**CORS setup:**

```typescript
import cors from 'cors';
app.use(cors({ origin: process.env.FRONTEND_ORIGIN || 'http://localhost:5173' }));
```

**Env vars:** `dotenv`:

```typescript
import dotenv from 'dotenv';
dotenv.config();
const PORT = process.env.PORT || 8000;
```

**Gotchas:**

- Express doesn't return JSON by default for errors — need `app.use(express.json())` and custom error handler
- No built-in validation — use `zod`, `joi`, or `express-validator`
- TypeScript compilation: `tsc` then `node dist/index.js`, or use `ts-node` / `tsx` for dev
- Error handler must have 4 params `(err, req, res, next)` to be recognized by Express

---

### Django + DRF (Python)

**Setup:**

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install django djangorestframework django-cors-headers
django-admin startproject config .
python manage.py startapp api
```

**Validation commands:**

```bash
cd backend
python manage.py runserver 8000     # Start server
python manage.py test               # Run tests
python manage.py check              # System checks
python manage.py migrate            # Apply migrations
```

**CORS setup:** In `settings.py`:

```python
INSTALLED_APPS = [..., 'corsheaders']
MIDDLEWARE = ['corsheaders.middleware.CorsMiddleware', ...]
CORS_ALLOWED_ORIGINS = ['http://localhost:5173']
```

**Gotchas:**

- Django uses `snake_case` for field names — may need serializer to convert to `camelCase` for the API contract
- Migrations are separate from models — run `makemigrations` then `migrate`
- DRF serializers vs Django forms — use serializers for API
- CORS middleware must be listed before `CommonMiddleware`

---

### Go (stdlib + common libraries)

**Setup:**

```bash
mkdir backend && cd backend
go mod init [module-name]
```

**Validation commands:**

```bash
cd backend
go build ./...                      # Compile check
go run .                            # Start server
go test ./...                       # Run tests
go vet ./...                        # Static analysis
```

**CORS setup:** Using `rs/cors`:

```go
import "github.com/rs/cors"
handler := cors.New(cors.Options{
    AllowedOrigins: []string{"http://localhost:5173"},
    AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
}).Handler(router)
```

**Gotchas:**

- Go uses `PascalCase` for exported types, `camelCase` for JSON tags — always set JSON tags: `json:"fieldName"`
- No ORM by default — use `sqlx` (lightweight) or `gorm` (full ORM)
- Error handling is explicit (`if err != nil`) — every database call needs error handling
- Binary compiled — no runtime dependency issues, but longer build times

---

## Databases

### PostgreSQL

**Docker:** `postgres:16`

**Connection string:** `postgresql://user:password@host:5432/dbname`

**CLI check:**

```bash
psql -U postgres -d dbname -c "SELECT 1;"
# Docker: docker compose exec db psql -U postgres -d appdb -c "\dt"
```

**Health check (Docker):** `pg_isready -U postgres`

**Gotchas:**

- Default port: 5432
- Needs `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";` for UUID generation
- Connection pooling recommended for production (PgBouncer)

---

### SQLite

**Connection string:** `sqlite:///./app.db` (file-based)

**CLI check:**

```bash
sqlite3 app.db ".tables"
sqlite3 app.db "SELECT * FROM sessions LIMIT 5;"
```

**Gotchas:**

- No separate server process — it's a file
- Foreign keys are OFF by default — enable with `PRAGMA foreign_keys = ON;`
- No concurrent write support — fine for dev, not for production with multiple workers
- Good default for prototypes and single-user apps

---

### MySQL

**Docker:** `mysql:8`

**Connection string:** `mysql://user:password@host:3306/dbname`

**CLI check:**

```bash
mysql -u root -p -e "SHOW TABLES;" dbname
# Docker: docker compose exec db mysql -u root -p -e "\s"
```

**Health check (Docker):** `mysqladmin ping -h localhost`

**Gotchas:**

- Default port: 3306
- `utf8mb4` charset for full Unicode support (not `utf8` which is 3-byte)
- Case sensitivity varies by platform and collation

---

### MongoDB

**Docker:** `mongo:7`

**Connection string:** `mongodb://user:password@host:27017/dbname`

**CLI check:**

```bash
mongosh --eval "db.sessions.find().limit(5)"
# Docker: docker compose exec db mongosh --eval "db.stats()"
```

**Gotchas:**

- Schema-less by default — use Mongoose (Node) or Motor (Python) for schema enforcement
- `_id` field is auto-generated (ObjectId, not UUID)
- No joins — denormalize or use `$lookup` aggregation

---

## Quick Reference: Stack Combinations

| Plan Says | Frontend | Backend | Database | Notes |
|-----------|----------|---------|----------|-------|
| "React app with API" | React + Vite + TS | FastAPI or Express | SQLite (simple) or PostgreSQL | Most common 2-agent split |
| "Next.js full-stack" | Next.js | Next.js API routes | PostgreSQL + Prisma | Can be single-agent if API routes are simple |
| "Python backend, any frontend" | React + Vite + TS | FastAPI + SQLAlchemy | PostgreSQL | Clean separation, 2 agents |
| "Node everything" | React + Vite + TS | Express + TS | PostgreSQL + Prisma | Shared TypeScript types work natively |
| "Go backend, high performance" | React + Vite + TS | Go + stdlib/Gin | PostgreSQL | Different languages = strong boundary |
| "Django app" | React + Vite + TS or Django templates | Django + DRF | PostgreSQL | If templates: may be single-agent |

---

## How to Use This Reference

**During Phase 2** (Agent Definition): Look up the tech stack to determine validation commands for each agent's checklist.

**During Phase 4** (Contracts): Reference the CORS setup and env var conventions for the chosen stack when writing contracts.

**During Phase 5** (Distill Prompts): Include the stack-specific gotchas in each agent's prompt to prevent known issues.

**During Phase 8** (Validation): QE agent uses the CLI commands for database inspection and service health checks.
