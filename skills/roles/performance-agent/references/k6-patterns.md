# k6 Performance Testing Patterns

## Installation

```bash
# macOS
brew install k6

# Docker
docker run --rm -i grafana/k6 run - <script.js
```

## Basic Load Test Script

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 10 },  // Ramp up
    { duration: '1m', target: 10 },   // Sustain
    { duration: '30s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% under 500ms
    http_req_failed: ['rate<0.01'],    // <1% errors
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000';
const RESOURCE_PATH = __ENV.RESOURCE_PATH || '/api/v1/resource';

export default function () {
  // Create resource
  const createRes = http.post(`${BASE_URL}${RESOURCE_PATH}`,
    JSON.stringify({ title: `Load Test ${Date.now()}` }),
    { headers: { 'Content-Type': 'application/json' } }
  );
  check(createRes, {
    'create status is 201': (r) => r.status === 201,
    'has id': (r) => JSON.parse(r.body).id !== undefined,
  });

  if (createRes.status === 201) {
    const resourceId = JSON.parse(createRes.body).id;

    // Get resource
    const getRes = http.get(`${BASE_URL}${RESOURCE_PATH}/${resourceId}`);
    check(getRes, {
      'get status is 200': (r) => r.status === 200,
    });
  }

  sleep(1);
}
```

## Smoke Test

```javascript
export const options = {
  vus: 1,
  duration: '30s',
  thresholds: {
    http_req_failed: ['rate==0'],
    http_req_duration: ['p(99)<1000'],
  },
};
```

## Stress Test

```javascript
export const options = {
  stages: [
    { duration: '2m', target: 10 },
    { duration: '5m', target: 10 },
    { duration: '2m', target: 50 },
    { duration: '5m', target: 50 },
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '5m', target: 0 },
  ],
};
```

## Soak Test

```javascript
export const options = {
  stages: [
    { duration: '2m', target: 20 },
    { duration: '30m', target: 20 },
    { duration: '2m', target: 0 },
  ],
};
```

## Running

```bash
# Basic run
k6 run script.js

# With environment variables
k6 run -e BASE_URL=http://localhost:8000 script.js

# JSON output
k6 run --out json=results.json script.js

# HTML report (with extension)
k6 run --out json=results.json script.js
# Then use k6-reporter or similar for HTML
```

## Key Metrics to Watch

| Metric | Description | Good Target |
|--------|-------------|-------------|
| `http_req_duration` | Total request time | p95 < 500ms |
| `http_req_failed` | Failed request rate | < 0.1% |
| `http_reqs` | Total requests/second | Depends on scale |
| `iteration_duration` | Full scenario time | Depends on flow |
| `vus` | Active virtual users | As configured |

## Custom Metrics

```javascript
import { Trend, Counter } from 'k6/metrics';

const createResourceDuration = new Trend('create_resource_duration');
const createResourceErrors = new Counter('create_resource_errors');

export default function () {
  const res = http.post(`${BASE_URL}${RESOURCE_PATH}`, ...);
  createResourceDuration.add(res.timings.duration);
  if (res.status !== 201) createResourceErrors.add(1);
}
```
