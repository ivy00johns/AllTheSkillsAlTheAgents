# Migration Checklist

## Pre-Migration

- [ ] Schema changes match the data layer contract
- [ ] Migration is reversible (has down/rollback)
- [ ] Migration is idempotent
- [ ] No data loss in production (additive changes preferred)

## By Stack

### SQLAlchemy / Alembic (Python)

```bash
# Generate migration
alembic revision --autogenerate -m "description"

# Review generated migration
cat alembic/versions/[latest].py

# Apply
alembic upgrade head

# Rollback
alembic downgrade -1

# Verify
python -c "from database import engine; print(engine.table_names())"
```

### Prisma (Node.js)

```bash
# Generate migration
npx prisma migrate dev --name description

# Apply to production
npx prisma migrate deploy

# Reset (dev only)
npx prisma migrate reset

# Verify
npx prisma db pull  # Should match schema.prisma
```

### Django

```bash
# Generate migration
python manage.py makemigrations

# Review
python manage.py showmigrations
python manage.py sqlmigrate app_name 0001

# Apply
python manage.py migrate

# Rollback
python manage.py migrate app_name 0001_previous
```

### Knex (Node.js)

```bash
# Generate migration
npx knex migrate:make description

# Apply
npx knex migrate:latest

# Rollback
npx knex migrate:rollback

# Seed
npx knex seed:run
```

### Drizzle ORM (TypeScript)

```bash
# Generate migration from schema changes
pnpm --filter <db-package> exec drizzle-kit generate

# Apply
pnpm --filter <db-package> run migrate:up

# Rollback (custom — drizzle-kit does not ship a rollback runner)
pnpm --filter <db-package> run migrate:rollback
```

> **Critical: invoke tsx as a CLI, never as a Node loader.** `node --loader tsx <file>` was deprecated in Node 20.6 and emits a hard error in Node 24+: `Error: tsx must be loaded with --import instead of --loader`. The migration scripts MUST use `tsx <file>` directly:
>
> ```json
> // ✅ Right — works on every Node version that has tsx as a dep
> "scripts": {
>   "migrate:up":       "tsx ./src/migrate.ts up",
>   "migrate:rollback": "tsx ./src/migrate.ts rollback",
>   "seed":             "tsx ./src/seed.ts"
> }
>
> // ❌ Wrong — Node 20.6+ deprecation, Node 24+ hard error
> "scripts": {
>   "migrate:up": "node --loader tsx ./src/migrate.ts up"
> }
> ```
>
> If you generate the migrate runner yourself rather than using a built-in CLI, this matters — drizzle-kit doesn't ship its own runner.

### Schema iteration: filter for actual table objects

Tests or runtime code that walks `Object.values(schema)` will trip on non-table exports (relations, type aliases, helper functions) — those don't have `._.columns`. Filter for actual Drizzle pgTable instances:

```ts
for (const [name, value] of Object.entries(schema)) {
  const inner = (value as { _?: { columns?: Record<string, unknown> } })?._;
  if (!inner || typeof inner.columns !== 'object' || inner.columns === null) {
    continue; // skip relations, types, helpers
  }
  // value is a pgTable; inspect inner.columns
}
```

### Raw SQL

```bash
# Apply
psql -U postgres -d dbname -f migrations/001_create_tables.sql

# Verify
psql -U postgres -d dbname -c "\dt"
psql -U postgres -d dbname -c "\d+ table_name"
```

## Post-Migration Verification

- [ ] All tables/collections created
- [ ] Column types match contract
- [ ] Foreign keys enforced (test cascade delete)
- [ ] Indexes exist for contracted query patterns
- [ ] Seed data loads without errors
- [ ] Application can connect and query successfully

## Common Mistakes

| Mistake | Prevention |
|---------|------------|
| Missing foreign key ON DELETE | Always specify CASCADE or SET NULL per contract |
| Wrong column type for UUIDs | Use UUID type (Postgres) or CHAR(36) (MySQL/SQLite) |
| Missing index on FK columns | Add index on every foreign key column |
| Forgetting to enable FK in SQLite | `PRAGMA foreign_keys = ON;` |
| Destructive migration without backup | Always flag DROP/ALTER COLUMN to the lead |
