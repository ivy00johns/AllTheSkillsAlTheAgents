# DB Migration Agent Validation Checklist

Run ALL before reporting done. Fix failures. Substitute actual paths and connection strings from the project profile.

> **The single most important gate is below: actually run the migration up + rollback against a real database, not just lint the SQL.** Hand-written migrations frequently fail at runtime even when they compile and pass syntax checks. Run them.

## Typecheck and tests pass (where applicable)

If your migration code is in a typed language and the project has a typecheck/test script, run it. Examples by stack:

| Stack | Typecheck / lint | Test |
|---|---|---|
| Node + Drizzle / Knex / Prisma | `npm run typecheck` (or pnpm/yarn) | `npm test` |
| Python + SQLAlchemy / Alembic | `mypy migrations/ models/` | `pytest` |
| Django | — | `python manage.py test` |
| Go + sqlc / migrate | `go vet ./...` | `go test ./...` |
| Raw SQL only | `pg_query` syntax check OR run against a scratch DB | — |

If schema tests iterate over a schema object's exports, confirm they filter for actual table instances rather than blowing up on relation/type/helper re-exports — see `migration-checklist.md` § Schema iteration for the Drizzle pattern; the same principle applies to SQLAlchemy `Base.metadata.tables` (already filtered by SQLAlchemy) and Django's `apps.get_models()`.

## Migration runs against a live database

The exact commands depend on the migration tool. The shape is always the same: bring up the DB, apply, rollback, re-apply.

```bash
# 1. Bring up the database (whatever the data-layer profile specifies)
docker compose up -d postgres   # or mysql, mongo, etc.
# Wait for healthy — adapt to the actual database
until docker compose exec postgres pg_isready -U <user>; do sleep 1; done

# 2. Apply — invocation depends on stack
#    Drizzle (Node):      npm run migrate:up   (or pnpm/yarn)
#    Knex (Node):         npx knex migrate:latest
#    Prisma (Node):       npx prisma migrate deploy
#    Alembic (Python):    alembic upgrade head
#    Django:              python manage.py migrate
#    Raw SQL:             psql -U <user> -d <db> -f migrations/0001_initial.sql
# Expected: every CREATE TABLE / CREATE INDEX runs without error

# 3. Rollback — same tool, reverse direction
#    Drizzle:             npm run migrate:rollback   (custom; drizzle-kit ships no rollback)
#    Knex:                npx knex migrate:rollback
#    Prisma:              npx prisma migrate reset --skip-seed   (dev only)
#    Alembic:             alembic downgrade -1
#    Django:              python manage.py migrate <app> <previous>
# Expected: every DROP runs without error, schema is empty

# 4. Re-apply (idempotency check) — re-run step 2.
# Expected: clean re-apply with no leftover state from the rollback.
```

If migrate-up succeeds but rollback fails, you have a destructive migration with no escape hatch. Fix the rollback before reporting done.

## Stack-specific gotchas

**Drizzle ORM (TypeScript)** — see `migration-checklist.md` § Drizzle ORM. The `node --loader tsx` pattern is deprecated in Node 20.6 and errors in Node 24+; use `tsx <file>` as a CLI directly.

**Alembic (Python)** — autogenerate (`alembic revision --autogenerate`) misses constraint-only changes; review the generated file before applying.

**Prisma (Node)** — `prisma migrate dev` resets the DB by default in development; never run on a database with real data.

**Knex (Node)** — migrations run in alphabetical filename order; if you change a filename after committing, replays diverge. Stick with the timestamp prefix Knex generates.

## Seed determinism

```bash
# Seeds must be reproducible — same input ⇒ same output.
# 1. Run seed (whatever the project's command is — npm run seed, alembic seed, rake db:seed, etc.).
# 2. Hash the resulting table state.
psql ${DATABASE_URL} -At -c "SELECT md5(string_agg(id::text, ',' ORDER BY id)) FROM users"
# 3. Reset (rollback then re-up), re-seed, hash again.
# 4. Hashes must match.
```

If the hash changes across runs, the seed depends on `Math.random()` / `random.random()` / `rand()` / `Date.now()` / `time.time()` / another non-deterministic source. Replace it with a seeded RNG (mulberry32 in JS, `random.seed(N)` in Python, etc.) before reporting done.

## Indexes match data-layer contract

```bash
# For each index in data-layer.yaml, verify it's in the migration SQL.
psql ${DATABASE_URL} -c "\di"
# Cross-check the listed indexes against the contract's required_indexes section.
```

## Money columns use bigint or numeric, never float

```bash
# For every column documented as monetary in the contract, verify its type.
psql ${DATABASE_URL} -c "\d+ <table>" | grep -iE "amount|price|balance"
# Expected: numeric(N,0), bigint, or decimal — NEVER real, double precision, or float.
```

Floating-point currency arithmetic loses precision past ~9e15 and accumulates rounding errors on every operation. The contract specifies bigint minor units paired with a currency code. If you find a float, fix it — there is no acceptable workaround.

## Tenant scoping default present

```bash
# Every table that is part of multi-tenant data must carry a tenant_id with a documented default.
psql ${DATABASE_URL} -c "\d+ <each-tenant-scoped-table>" | grep tenant_id
# Expected: tenant_id uuid NOT NULL DEFAULT '<documented-uuid>'
```

If the contract specifies single-tenant runtime + multi-tenant schema, every relevant table needs `tenant_id NOT NULL DEFAULT '<the all-zeros UUID>'` (or whatever the contract specifies).
