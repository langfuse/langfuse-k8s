#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# ClickHouse online sync for the Langfuse v1 -> v2 migration.
#
# Minimum source Langfuse version: v3.224.1 (latest published v3). Newer charts
# default to Langfuse v4 — keep the same appVersion / langfuse.image.tag on the
# v1 source and the v2 target while copying data.
#
# Copies Langfuse's ClickHouse data tables from a LIVE v1 cluster into the
# freshly-migrated v2 cluster using the native remote() table function, one
# incremental pass at a time keyed on an `event_ts` watermark. The big Langfuse
# tables are ReplicatedReplacingMergeTree, so overlapping re-copies are
# idempotent (identical insert blocks are deduplicated, and the sort key +
# event_ts version collapse duplicates) — this is what makes repeated
# incremental passes safe.
#
# Typical usage:
#   1) Run it repeatedly while v1 is LIVE to copy the bulk + keep catching up:
#        ./ch-online-sync.sh                       # incremental pass
#      (loop it, e.g. `watch -n 300 ./ch-online-sync.sh`, until lag is small)
#   2) Freeze v1 writers (scale web first, then worker after the queue drains),
#      then:
#        ./ch-online-sync.sh --final              # final delta only
#
# OPTIMIZE TABLE … FINAL is intentionally NOT run by this script. On large
# volumes it can be expensive / disruptive. If you observe too many duplicates
# after the transfer (unexpected for identical re-inserts), you may run it
# yourself after reading:
#   https://clickhouse.com/docs/en/sql-reference/statements/optimize
#
# It is intentionally dependency-light (kubectl + clickhouse-client in the
# target pod). Review and adapt before running against production.
# ---------------------------------------------------------------------------
set -euo pipefail

# --- Configuration (override via environment) ------------------------------
: "${KUBECTL:=kubectl}"
: "${KCTX:=}"                                   # optional kube-context (e.g. minikube)
: "${TARGET_NS:=langfuse}"                      # namespace of the v2 release
: "${TARGET_POD:=langfuse-clickhouse-0-0-0}"    # a v2 ClickHouse pod
: "${TARGET_DB:=default}"
# Source (v1) ClickHouse, reachable from the target pod over the native port:
: "${SOURCE_HOST:=langfuse-clickhouse.langfuse.svc.cluster.local:9000}"
: "${SOURCE_DB:=default}"
: "${SOURCE_USER:=default}"
# Passwords: taken from the cluster secrets by default; override to pin.
: "${TARGET_SECRET:=langfuse-clickhouse-auth}"  # v2 secret
: "${TARGET_SECRET_KEY:=password}"
: "${SOURCE_SECRET:=langfuse-clickhouse}"       # v1 Bitnami default; override when using existingSecret
: "${SOURCE_SECRET_KEY:=admin-password}"
: "${SOURCE_NS:=${TARGET_NS}}"                  # namespace holding the v1 secret

# ReplacingMergeTree data tables that carry an `event_ts` version column. These
# are safe to copy incrementally with overlap (dedup handles duplicates).
# dataset_run_items / project_environments / event_log are omitted — unused on
# Langfuse ≥ v3.224.1.
: "${INCREMENTAL_TABLES:=traces observations scores dataset_run_items_rmt blob_storage_file_log}"

# Overlap window subtracted from the stored watermark on each pass, so slightly
# late/out-of-order rows (event_ts < previous max) are re-picked-up. Dedup makes
# the overlap free. Increase if your ingestion is very bursty/out-of-order.
: "${LOOKBACK:=1 HOUR}"

: "${STATE_DIR:=./.ch-sync-state}"              # per-table watermark files
FINAL=0; [ "${1:-}" = "--final" ] && FINAL=1

kx() { $KUBECTL ${KCTX:+--context "$KCTX"} "$@"; }
mkdir -p "$STATE_DIR"

TPW=$(kx -n "$TARGET_NS" get secret "$TARGET_SECRET" -o jsonpath="{.data.$TARGET_SECRET_KEY}" | base64 -d)
SPW=$(kx -n "$SOURCE_NS" get secret "$SOURCE_SECRET" -o jsonpath="{.data.$SOURCE_SECRET_KEY}" | base64 -d)

# Run a query on the target ClickHouse. The target password and query, which can
# contain the source password in remote(), are both carried over stdin.
chq() {
  local password_length
  password_length=$(LC_ALL=C printf '%s' "$TPW" | wc -c | tr -d '[:space:]')
  {
    printf '%s' "$TPW"
    printf '%s\n' "$1"
  } | kx -n "$TARGET_NS" exec -i "$TARGET_POD" -- sh -c '
    password_length=$1
    CLICKHOUSE_PASSWORD=$({ dd bs=1 count="$password_length" 2>/dev/null; printf .; })
    CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD%?}
    export CLICKHOUSE_PASSWORD
    exec clickhouse-client --multiquery
  ' sh "$password_length"
}

remote_expr() { echo "remote('$SOURCE_HOST','$SOURCE_DB.$1','$SOURCE_USER','$SPW')"; }

copy_incremental() {
  local t="$1" wmfile="$STATE_DIR/$t.watermark" w
  w=$(cat "$wmfile" 2>/dev/null || echo '1970-01-01 00:00:00.000')
  # New high-watermark = current max(event_ts) on the source for this table.
  local wnew
  wnew=$(chq "SELECT toString(max(event_ts)) FROM $(remote_expr "$t")" | tr -d '\r')
  [ -z "$wnew" ] && wnew='1970-01-01 00:00:00.000'
  echo ">> $t: copying event_ts > ('$w' - INTERVAL $LOOKBACK)  (source max=$wnew)"
  chq "INSERT INTO $TARGET_DB.$t
       SELECT * FROM $(remote_expr "$t")
       WHERE event_ts > (toDateTime64('$w',3) - INTERVAL $LOOKBACK)"
  echo "$wnew" > "$wmfile"
}

echo "== ClickHouse online sync ($([ $FINAL -eq 1 ] && echo FINAL || echo incremental)) =="
for t in $INCREMENTAL_TABLES; do copy_incremental "$t"; done

echo "== row counts (target, FINAL) =="
for t in $INCREMENTAL_TABLES; do
  printf '   %-26s %s\n' "$t" "$(chq "SELECT count() FROM $TARGET_DB.$t FINAL" | tr -d '\r')"
done
echo "Done."
