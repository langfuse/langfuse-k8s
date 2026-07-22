#!/usr/bin/env bash
# Smoke tests for the rebuilt Bitnami-compatible ClickHouse image.
# Usage: ./smoke-test.sh [image]   (default: poc/bitnami-clickhouse:local)
# Requires: docker, curl. test-b/ must sit next to this script (chart ConfigMap
# extracts: scripts/setup.sh, config/00_default_overrides.xml, initdb/00_init.sh).
set -euo pipefail
IMAGE="${1:-poc/bitnami-clickhouse:local}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cleanup() { docker rm -f st-a st-b st-c st-d >/dev/null 2>&1 || true; docker volume rm -f st-a-data st-b-data st-c-data >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

wait_ping() { # port
  for _ in $(seq 1 30); do
    [[ "$(curl -s --max-time 2 "http://localhost:$1/ping" || true)" == "Ok." ]] && return 0
    sleep 2
  done
  echo "FAIL: no Ok. on /ping port $1"; return 1
}

echo "=== A: image defaults, uid 1001, persistent volume ==="
docker volume create st-a-data >/dev/null
docker run -d --name st-a --user 1001 \
  -e CLICKHOUSE_ADMIN_USER=default -e CLICKHOUSE_ADMIN_PASSWORD=changeme \
  -v st-a-data:/bitnami/clickhouse -p 18123:8123 "$IMAGE" >/dev/null
wait_ping 18123
[[ "$(docker exec st-a clickhouse-client --user default --password changeme --query 'SELECT 1')" == "1" ]]
docker exec st-a clickhouse-client --user default --password changeme --query \
  "CREATE TABLE poc_persist (id UInt32) ENGINE = MergeTree ORDER BY id; INSERT INTO poc_persist VALUES (1),(2)" >/dev/null 2>&1 || {
  docker exec st-a clickhouse-client --user default --password changeme --query "CREATE TABLE poc_persist (id UInt32) ENGINE = MergeTree ORDER BY id"
  docker exec st-a clickhouse-client --user default --password changeme --query "INSERT INTO poc_persist VALUES (1),(2)"; }
docker restart st-a >/dev/null; wait_ping 18123
[[ "$(docker exec st-a clickhouse-client --user default --password changeme --query 'SELECT count() FROM poc_persist')" == "2" ]]
docker rm -f st-a >/dev/null
docker run -d --name st-a --user 1001 \
  -e CLICKHOUSE_ADMIN_USER=default -e CLICKHOUSE_ADMIN_PASSWORD=changeme \
  -v st-a-data:/bitnami/clickhouse -p 18123:8123 "$IMAGE" >/dev/null
wait_ping 18123
[[ "$(docker exec st-a clickhouse-client --user default --password changeme --query 'SELECT count() FROM poc_persist')" == "2" ]]
[[ "$(docker logs st-a 2>&1 | grep -cE '<Error>|<Fatal>' || true)" == "0" ]]
echo "PASS A"

echo "=== B: chart-shaped (command /scripts/setup.sh, read-only rootfs, 1001:1001, emptyDirs, conf.d override) ==="
docker volume create st-b-data >/dev/null
docker run --rm --user 0 -v st-b-data:/bitnami/clickhouse "$IMAGE" bash -c \
  'chgrp -R 1001 /bitnami/clickhouse && chmod -R g+rwX /bitnami/clickhouse' # fsGroup: 1001 emulation
docker run -d --name st-b \
  --hostname langfuse-clickhouse-shard0-0 --user 1001:1001 --read-only --cap-drop ALL \
  --security-opt no-new-privileges \
  --mount type=tmpfs,destination=/opt/bitnami/clickhouse/etc,tmpfs-mode=0777 \
  --mount type=tmpfs,destination=/opt/bitnami/clickhouse/logs,tmpfs-mode=0777 \
  --mount type=tmpfs,destination=/opt/bitnami/clickhouse/tmp,tmpfs-mode=0777 \
  --mount type=tmpfs,destination=/tmp,tmpfs-mode=0777 \
  -v st-b-data:/bitnami/clickhouse \
  -v "$HERE/test-b/config":/bitnami/clickhouse/etc/conf.d/default:ro \
  -v "$HERE/test-b/scripts/setup.sh":/scripts/setup.sh:ro \
  -e BITNAMI_DEBUG=false \
  -e CLICKHOUSE_HTTP_PORT=8123 -e CLICKHOUSE_TCP_PORT=9000 -e CLICKHOUSE_MYSQL_PORT=9004 \
  -e CLICKHOUSE_POSTGRESQL_PORT=9005 -e CLICKHOUSE_INTERSERVER_HTTP_PORT=9009 \
  -e CLICKHOUSE_ADMIN_USER=default -e CLICKHOUSE_ADMIN_PASSWORD=changeme \
  -e CLICKHOUSE_SHARD_ID=shard0 -e CLICKHOUSE_REPLICA_ID=langfuse-clickhouse-shard0-0 \
  -p 28123:8123 "$IMAGE" /scripts/setup.sh >/dev/null
wait_ping 28123
[[ "$(docker exec st-b clickhouse-client --user default --password changeme --query "SELECT getMacro('shard')")" == "shard0" ]]
docker exec st-b test -f /opt/bitnami/clickhouse/etc/conf.d/00_default_overrides.xml
docker restart st-b >/dev/null; wait_ping 28123
echo "PASS B"

echo "=== C: arbitrary uid (1002:0) + initdb scripts ==="
docker volume create st-c-data >/dev/null
docker run -d --name st-c --user 1002:0 \
  -e CLICKHOUSE_ADMIN_USER=default -e CLICKHOUSE_ADMIN_PASSWORD=changeme \
  -v st-c-data:/bitnami/clickhouse \
  -v "$HERE/test-b/initdb":/docker-entrypoint-initdb.d:ro \
  -p 38123:8123 "$IMAGE" >/dev/null
sleep 20; wait_ping 38123
[[ "$(docker exec st-c clickhouse-client --user default --password changeme --query 'SELECT * FROM initdb_marker')" == "7" ]]
docker exec st-c test -f /bitnami/clickhouse/data/.user_scripts_initialized
echo "PASS C"

echo "=== D: non-default admin user ==="
docker run -d --name st-d --user 1001 \
  -e CLICKHOUSE_ADMIN_USER=admin2 -e CLICKHOUSE_ADMIN_PASSWORD=s3cret -p 48123:8123 "$IMAGE" >/dev/null
wait_ping 48123
[[ "$(curl -s "http://admin2:s3cret@localhost:48123/?query=SELECT%20currentUser()")" == "admin2" ]]
curl -s "http://default:s3cret@localhost:48123/?query=SELECT%201" | grep -q "Authentication failed"
echo "PASS D"

echo "ALL SMOKE TESTS PASSED for $IMAGE"
