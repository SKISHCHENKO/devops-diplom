#!/usr/bin/env bash
set -euo pipefail
image="${1:-diplom-web:test}"
container="diplom-test-${RANDOM}-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT
docker run --rm --entrypoint nginx "$image" -t
docker run -d --name "$container" -p 127.0.0.1::80 "$image" >/dev/null
port="$(docker port "$container" 80/tcp | head -1 | awk -F: '{print $NF}')"
url="http://127.0.0.1:$port"
curl --retry 15 --retry-delay 1 --retry-connrefused -fsS "$url/healthz" | grep -qx ok
curl -fsS "$url/" | grep -q 'DevOps Diploma'
curl -fsS "$url/version.txt" | grep -q .
status="$(curl -sS -o /dev/null -w '%{http_code}' "$url/no-such-file")"
[[ "$status" == 404 ]]
echo 'nginx -t, healthz, HTML, версия и HTTP 404: OK'
