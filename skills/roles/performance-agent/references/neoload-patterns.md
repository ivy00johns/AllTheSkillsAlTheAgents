# NeoLoad Performance Testing Patterns

NeoLoad is Tricentis's enterprise performance testing platform. These patterns apply to NeoLoad Web and NeoLoad as-code (YAML-based test definitions).

## NeoLoad as-Code (YAML)

### Basic Test Definition
```yaml
name: api-load-test
scenarios:
  - name: main-scenario
    populations:
      - name: api-users
        rampup_load:
          min_users: 1
          max_users: 50
          increment_users: 5
          increment_every: 30s
          duration: 5m

user_paths:
  - name: api-flow
    actions:
      steps:
        - transaction:
            name: create-session
            steps:
              - request:
                  url: ${base_url}/api/v1/sessions
                  method: POST
                  headers:
                    - Content-Type: application/json
                  body: '{"title": "NeoLoad Test ${__counter}"}'
                  assertions:
                    - status_code: 201

        - delay: 1s

        - transaction:
            name: get-sessions
            steps:
              - request:
                  url: ${base_url}/api/v1/sessions
                  method: GET
                  assertions:
                    - status_code: 200

variables:
  - name: base_url
    value: http://localhost:8000

populations:
  - name: api-users
    user_paths:
      - name: api-flow
        distribution: 100%
```

### SLA Definitions
```yaml
sla_profiles:
  - name: standard-sla
    thresholds:
      - scope: per_test
        conditions:
          - avg_response_time: warn >= 500ms, fail >= 1000ms
          - error_rate: warn >= 1%, fail >= 5%
      - scope: per_transaction
        conditions:
          - p95_response_time: warn >= 800ms, fail >= 2000ms
```

## NeoLoad Web Integration

### Running via CLI
```bash
# Run test with NeoLoad Web
neoload run \
  --scenario main-scenario \
  --zone defaultzone \
  --controller-zone defaultzone \
  --lgs 1 \
  --naming-pattern "Load Test ${timestamp}"

# Get results
neoload results --junit-report results.xml
```

### CI/CD Integration
```yaml
# GitHub Actions
- name: Run NeoLoad Test
  uses: neotys-testing/neoload-cli-action@v1
  with:
    neoload-token: ${{ secrets.NEOLOAD_TOKEN }}
    test-file: load-tests/test.yaml
    scenario: main-scenario
```

## Test Scenario Types

### Capacity Test
Determine maximum throughput:
```yaml
scenarios:
  - name: capacity
    populations:
      - name: api-users
        rampup_load:
          min_users: 10
          max_users: 500
          increment_users: 10
          increment_every: 1m
          duration: 30m
```

### Endurance Test
Detect memory leaks and resource exhaustion:
```yaml
scenarios:
  - name: endurance
    populations:
      - name: api-users
        constant_load:
          users: 50
          duration: 2h
```

### Spike Test
Test sudden traffic bursts:
```yaml
scenarios:
  - name: spike
    populations:
      - name: api-users
        custom_load_profile:
          steps:
            - {users: 10, duration: 2m}
            - {users: 200, duration: 30s}  # Spike
            - {users: 10, duration: 2m}    # Recovery
            - {users: 200, duration: 30s}  # Second spike
            - {users: 10, duration: 2m}    # Recovery
```

## Results Analysis

Key metrics from NeoLoad reports:
| Metric | Where to Find | Target |
|--------|--------------|--------|
| Avg Response Time | Summary dashboard | < 200ms |
| p95 Response Time | Transaction details | < 500ms |
| Error Rate | Error summary | < 0.1% |
| Throughput | Requests/sec chart | Stable or increasing |
| Concurrent Users | Load profile | Matches scenario |

## NeoLoad + TAIS Integration Notes

When working with Tricentis AI-Hub (TAIS):
- Use NeoLoad Web API for programmatic test execution
- Integrate with Tosca for functional + performance coverage
- Store test assets in the TAIS-connected repository
- Report results through the TAIS dashboard when available
