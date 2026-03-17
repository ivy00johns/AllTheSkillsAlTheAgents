# Railway GraphQL Deploy Script

For projects with multiple services or environments that need programmatic deployment control, use this pattern. It calls Railway's GraphQL API directly — no CLI needed in CI/CD.

## Setup

1. Get an API token: https://railway.app/account/tokens
2. Get project and service IDs from your Railway project dashboard URL
3. Add to your project's `.env`:

```
RAILWAY_API_TOKEN=your-token
RAILWAY_PROJECT_ID=your-project-id
RAILWAY_DEV_ENV_ID=env-id-for-dev
RAILWAY_PROD_ENV_ID=env-id-for-prod
RAILWAY_DEV_SERVICE_ID=service-id-for-dev-web
RAILWAY_PROD_SERVICE_ID=service-id-for-prod-web
RAILWAY_DEV_WORKER_SERVICE_ID=service-id-for-dev-worker    # optional
RAILWAY_PROD_WORKER_SERVICE_ID=service-id-for-prod-worker  # optional
```

## Script Template

Save as `scripts/deploy.py` in your project:

```python
#!/usr/bin/env python3
"""
Deploy to Railway environments.

Usage:
    python scripts/deploy.py dev          # Redeploy dev web service
    python scripts/deploy.py prod         # Redeploy prod web service
    python scripts/deploy.py worker-dev   # Redeploy dev worker
    python scripts/deploy.py worker-prod  # Redeploy prod worker
    python scripts/deploy.py status       # Check all deployments
"""

import os
import sys
import json
from pathlib import Path
from datetime import datetime

try:
    import requests
except ImportError:
    print("Error: requests library required. Run: pip install requests")
    sys.exit(1)

# Load .env
ENV_PATH = Path(__file__).parent.parent / ".env"
if ENV_PATH.exists():
    for line in ENV_PATH.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, value = line.partition("=")
            if key.strip() not in os.environ:
                os.environ[key.strip()] = value.strip()

API_URL = "https://backboard.railway.app/graphql/v2"
API_TOKEN = os.environ.get("RAILWAY_API_TOKEN")
PROJECT_ID = os.environ.get("RAILWAY_PROJECT_ID")

ENVIRONMENTS = {
    "dev": os.environ.get("RAILWAY_DEV_ENV_ID"),
    "prod": os.environ.get("RAILWAY_PROD_ENV_ID"),
}

SERVICES = {
    "dev": os.environ.get("RAILWAY_DEV_SERVICE_ID"),
    "prod": os.environ.get("RAILWAY_PROD_SERVICE_ID"),
}

WORKER_SERVICES = {
    "dev": os.environ.get("RAILWAY_DEV_WORKER_SERVICE_ID"),
    "prod": os.environ.get("RAILWAY_PROD_WORKER_SERVICE_ID"),
}


def railway_query(query, variables=None):
    headers = {"Authorization": f"Bearer {API_TOKEN}", "Content-Type": "application/json"}
    payload = {"query": query}
    if variables:
        payload["variables"] = variables
    resp = requests.post(API_URL, headers=headers, json=payload)
    if resp.status_code != 200:
        print(f"API error {resp.status_code}: {resp.text}")
        sys.exit(1)
    data = resp.json()
    if "errors" in data:
        for e in data["errors"]:
            print(f"GraphQL error: {e.get('message', e)}")
        sys.exit(1)
    return data.get("data", {})


def redeploy(service_id, env_id):
    return railway_query(
        """mutation($sid: String!, $eid: String!) {
            serviceInstanceRedeploy(serviceId: $sid, environmentId: $eid)
        }""",
        {"sid": service_id, "eid": env_id},
    )


def status():
    for env, env_id in ENVIRONMENTS.items():
        if not env_id:
            continue
        print(f"\n{env.upper()}:")
        result = railway_query(
            """query($pid: String!, $eid: String!) {
                deployments(input: {projectId: $pid, environmentId: $eid}, first: 3) {
                    edges { node { status createdAt } }
                }
            }""",
            {"pid": PROJECT_ID, "eid": env_id},
        )
        for edge in result.get("deployments", {}).get("edges", []):
            d = edge["node"]
            icon = {"SUCCESS": "ok", "FAILED": "FAIL", "DEPLOYING": "..."}.get(d["status"], "?")
            print(f"  [{icon}] {d['status']:12} {d['createdAt'][:16]}")


def main():
    if not API_TOKEN or not PROJECT_ID:
        print("Set RAILWAY_API_TOKEN and RAILWAY_PROJECT_ID in .env")
        sys.exit(1)
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd == "status":
        status()
    elif cmd in ("dev", "prod"):
        env_id, svc_id = ENVIRONMENTS[cmd], SERVICES[cmd]
        redeploy(svc_id, env_id)
        print(f"Redeployed {cmd} web service")
    elif cmd.startswith("worker-"):
        env = cmd.split("-", 1)[1]
        env_id, svc_id = ENVIRONMENTS[env], WORKER_SERVICES[env]
        redeploy(svc_id, env_id)
        print(f"Redeployed {env} worker service")
    else:
        print(f"Unknown: {cmd}. Use: dev, prod, worker-dev, worker-prod, status")


if __name__ == "__main__":
    main()
```

## Finding Your IDs

- **API Token**: https://railway.app/account/tokens
- **Project ID**: In the project dashboard URL: `railway.app/project/<PROJECT_ID>`
- **Environment ID**: Click the environment tab, find in URL or via `railway environment`
- **Service ID**: Click a service, find in the URL: `railway.app/project/.../service/<SERVICE_ID>`
