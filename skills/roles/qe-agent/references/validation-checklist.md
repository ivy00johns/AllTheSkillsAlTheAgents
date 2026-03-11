# QE Agent Validation Checklist

## Pre-Testing Setup
```bash
# Verify all services are running
docker compose ps        # or check individual processes
curl -s -o /dev/null -w "%{http_code}" http://localhost:${BACKEND_PORT}/health  # 200
curl -s -o /dev/null -w "%{http_code}" http://localhost:${FRONTEND_PORT}        # 200
```

## Phase 1: Contract Conformance
```bash
# For each contracted endpoint:
# 1. Check route exists
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:${PORT}/api/v1/sessions \
  -H "Content-Type: application/json" -d '{"title": "test"}'

# 2. Check response shape
curl -s -X POST http://localhost:${PORT}/api/v1/sessions \
  -H "Content-Type: application/json" -d '{"title": "test"}' | python3 -c "
import json, sys
resp = json.load(sys.stdin)
required = ['id', 'title', 'createdAt']
missing = [f for f in required if f not in resp]
if missing: print(f'FAIL: Missing: {missing}'); sys.exit(1)
print('PASS: Response shape matches')
"

# 3. Check frontend API calls match
grep -rn "fetch\|axios\|\.get\|\.post\|\.put\|\.delete" frontend/src/ \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx"
```

## Phase 2: Integration
```bash
# CORS check (#1 failure)
curl -s -I -X OPTIONS http://localhost:${BACKEND_PORT}/api/v1/sessions \
  -H "Origin: http://localhost:${FRONTEND_PORT}" \
  -H "Access-Control-Request-Method: POST" | grep -i "access-control"

# Happy path flow
# 1. Create → 2. Retrieve → 3. Update → 4. Persist check → 5. Delete
```

## Phase 3: Adversarial
```bash
# Empty body
curl -s -w "\n%{http_code}" -X POST http://localhost:${PORT}/api/v1/sessions \
  -H "Content-Type: application/json" -d '{}'

# Non-existent ID
curl -s -w "\n%{http_code}" http://localhost:${PORT}/api/v1/sessions/nonexistent/messages

# XSS payload
curl -s -X POST http://localhost:${PORT}/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"title": "<script>alert(1)</script>"}'

# SQL injection
curl -s -X POST http://localhost:${PORT}/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"'; DROP TABLE sessions;--\"}"
```

## Phase 4: QA Report Quality
- [ ] Every contracted endpoint has at least one test result
- [ ] Every critical issue has exact reproduction steps (commands, not prose)
- [ ] Every critical issue identifies the responsible agent
- [ ] Happy path tested end-to-end with actual data flow
- [ ] CORS explicitly tested and reported
- [ ] Verdict (PASS/FAIL) stated clearly in summary
- [ ] Failed tests include both expected and actual behavior
- [ ] JSON report conforms to qa-report-schema.json
