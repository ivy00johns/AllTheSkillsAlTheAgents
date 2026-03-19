#!/usr/bin/env bash

set -euo pipefail

echo "checking node"
command -v node >/dev/null 2>&1 || {
  echo "missing: node"
  exit 1
}

echo "checking docker"
command -v docker >/dev/null 2>&1 || {
  echo "missing: docker"
  exit 1
}

echo "checking docker daemon"
docker info >/dev/null 2>&1 || {
  echo "docker daemon is not running"
  exit 1
}

echo "ok"
