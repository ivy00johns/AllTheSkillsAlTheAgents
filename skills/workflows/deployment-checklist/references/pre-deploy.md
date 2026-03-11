# Pre-Deployment Checklist

Run each section in order. Stop on any CRITICAL failure.

## 1. Build Verification

```bash
# Frontend
cd frontend && npm run build      # Zero errors
npx tsc --noEmit                   # Zero type errors

# Backend (Python)
cd backend && python -m py_compile main.py  # No syntax errors
# Backend (Node)
cd backend && npx tsc --noEmit

# Docker
docker compose build               # All images build successfully
```

- [ ] Frontend builds without errors
- [ ] Backend compiles without errors
- [ ] Docker images build successfully
- [ ] No warnings that indicate potential runtime issues

## 2. Test Verification

```bash
# Unit tests
npm test                           # or pytest, go test, etc.

# Integration tests (if separate)
npm run test:integration

# E2E tests (if available)
npm run test:e2e
```

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] No skipped tests without documented reason
- [ ] Test coverage meets minimum threshold (if defined)

## 3. Environment Configuration

```bash
# Check .env.example has all required vars
diff <(grep -oP '^\w+' .env.example | sort) <(grep -oP '^\w+' .env | sort)

# Verify no placeholder values in target environment
grep -n "TODO\|CHANGEME\|xxx\|your-.*-here" .env
```

- [ ] All variables from .env.example are set in target environment
- [ ] No placeholder values remain
- [ ] Database connection string points to correct environment
- [ ] API URLs point to correct environment
- [ ] CORS origins match the target frontend URL
- [ ] Secret values are not the same as development defaults

## 4. Security Basics

```bash
# Check for hardcoded secrets
grep -rn "password\s*=\|api_key\s*=\|secret\s*=" src/ --include="*.py" --include="*.ts" --include="*.js"

# Check debug mode
grep -rn "DEBUG\s*=\s*[Tt]rue\|debug:\s*true" .env src/

# Check .gitignore covers sensitive files
cat .gitignore | grep -E "\.env$|\.env\.local|node_modules|\.pyc|__pycache__"

# Dependency audit
npm audit --production             # or pip-audit
```

- [ ] No hardcoded secrets in source code
- [ ] Debug mode disabled for target environment
- [ ] .gitignore covers sensitive files
- [ ] No critical dependency vulnerabilities
- [ ] HTTPS enforced (if production)

## 5. Database

```bash
# Check pending migrations
alembic heads                      # or prisma migrate status
alembic current

# Test migration
alembic upgrade head               # Apply all
alembic downgrade -1               # Rollback last
alembic upgrade head               # Re-apply (idempotent?)
```

- [ ] All migrations applied to target database
- [ ] Latest migration is reversible (rollback tested)
- [ ] No pending migrations
- [ ] Backup exists (production deployments)

## 6. Infrastructure

```bash
# Docker health
docker compose up -d
sleep 10
docker compose ps                  # All "running" or "healthy"
docker compose logs --tail=20      # No errors

# Health endpoints
curl -sf http://localhost:8000/health        # 200
curl -sf http://localhost:8000/health/ready   # 200
```

- [ ] All containers start successfully
- [ ] Health checks pass
- [ ] No error logs on startup
- [ ] Resource limits configured (memory, CPU)
- [ ] Restart policies set

## 7. Integration Verification

```bash
# Backend reachable
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/v1/health

# Frontend reachable
curl -s -o /dev/null -w "%{http_code}" http://localhost:5173

# CORS working
curl -s -I -X OPTIONS http://localhost:8000/api/v1/sessions \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: POST" \
  | grep -i "access-control-allow-origin"

# Happy path
curl -s -X POST http://localhost:8000/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"title": "deploy test"}' | python3 -m json.tool
```

- [ ] Backend responds to health check
- [ ] Frontend loads successfully
- [ ] CORS headers present and correct
- [ ] API happy path works end-to-end
- [ ] Data persists across service restart

## Post-Deployment Verification

After deployment, run these checks against the target environment:
- [ ] Health endpoints return 200
- [ ] Frontend loads without console errors
- [ ] Primary user flow works
- [ ] Monitoring/alerting is active
- [ ] Logs are being collected
