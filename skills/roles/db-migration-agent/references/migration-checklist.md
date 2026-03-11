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
