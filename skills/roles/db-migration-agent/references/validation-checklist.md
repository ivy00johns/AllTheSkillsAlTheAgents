# DB Migration Agent Validation Checklist

Run ALL before reporting done. Fix failures. Substitute actual paths and connection strings from the project profile.

> **The single most important gate is below: actually run the migration up + rollback against a real database, not just lint the SQL.** Hand-written migrations frequently fail at runtime even when they compile and pass syntax checks. Run them.

## Typecheck and tests pass

```bash
pnpm --filter <db-package> run typecheck   # zero type errors
pnpm --filter <db-package> run test        # if a test script exists, all pass
```

If schema tests iterate over `Object.values(schema)`, confirm they filter for actual table objects rather than blowing up on relation/type re-exports — see `migration-checklist.md` § Schema iteration.

## Migration runs against a live database

```bash
# Bring up Postgres (or whatever the data layer profile specifies)
docker compose up -d postgres
# Wait for healthy
until docker compose exec postgres pg_isready -U <user>; do sleep 1; done

# Apply
pnpm --filter <db-package> run migrate:up
# Expected: every CREATE TABLE / CREATE INDEX runs without error

# Rollback
pnpm --filter <db-package> run migrate:rollback
# Expected: every DROP runs without error, schema is empty

# Re-apply (idempotency check)
pnpm --filter <db-package> run migrate:up
# Expected: clean re-apply with no leftover state from the rollback
```

If migrate:up succeeds but migrate:rollback fails, you have a destructive migration with no escape hatch. Fix the rollback before reporting done.

## tsx invocation (Node-stack only)

```bash
# Verify package.json migrate scripts use tsx as a CLI, not as a Node --loader.
# --loader was deprecated in Node 20.6 and errors in Node 24+.
grep -E '"migrate.*node --loader|"seed.*node --loader' packages/<db-package>/package.json
# Expected: zero matches. If it matches, fix it before testing.
```

The correct pattern is `"migrate:up": "tsx ./src/migrate.ts up"` — see `migration-checklist.md` § Drizzle ORM.

## Seed determinism

```bash
# Seeds must be reproducible — same input ⇒ same output.
pnpm --filter <db-package> run seed
# Hash the resulting table state.
psql ${DATABASE_URL} -At -c "SELECT md5(string_agg(id::text, ',' ORDER BY id)) FROM users"
# Reset.
pnpm --filter <db-package> run migrate:rollback && pnpm --filter <db-package> run migrate:up
# Re-seed and verify the hash matches.
```

If the hash changes across runs, the seed depends on `Math.random()`, `Date.now()`, or another non-deterministic source. Replace it with a seeded RNG (mulberry32, sha1-derived UUIDs) before reporting done.

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
