#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# ClickHouse online sync for the Langfuse v1 -> v2 migration (blue/green).
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
#   2) Freeze v1 writers, let the v1 worker drain into ClickHouse, then:
#        ./ch-online-sync.sh --final              # final delta + OPTIMIZE FINAL
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
: "${TARGET_SECRET:=langfuse-clickhouse-auth}"  # v2 secret, key `password`
: "${SOURCE_SECRET:=langfuse-clickhouse}"       # v1 Bitnami secret, key `admin-password`
: "${SOURCE_NS:=${TARGET_NS}}"                  # namespace holding the v1 secret

# ReplacingMergeTree data tables that carry an `event_ts` version column. These
# are safe to copy incrementally with overlap (dedup handles duplicates).
: "${INCREMENTAL_TABLES:=traces observations scores dataset_run_items dataset_run_items_rmt project_environments blob_storage_file_log}"
# Tables without a replacing/version column (plain MergeTree). Copied ONLY on
# the --final pass, once, to avoid duplicate rows. event_log is an internal log.
: "${FINAL_ONLY_TABLES:=event_log}"

# Overlap window subtracted from the stored watermark on each pass, so slightly
# late/out-of-order rows (event_ts < previous max) are re-picked-up. Dedup makes
# the overlap free. Increase if your ingestion is very bursty/out-of-order.
: "${LOOKBACK:=1 HOUR}"

: "${STATE_DIR:=./.ch-sync-state}"              # per-table watermark files
FINAL=0; [ "${1:-}" = "--final" ] && FINAL=1

kx() { $KUBECTL ${KCTX:+--context "$KCTX"} "$@"; }
mkdir -p "$STATE_DIR"

TPW=$(kx -n "$TARGET_NS" get secret "$TARGET_SECRET" -o jsonpath='{.data.password}' | base64 -d)
SPW=$(kx -n "$SOURCE_NS" get secret "$SOURCE_SECRET" -o jsonpath='{.data.admin-password}' | base64 -d)

# Run a query on the target ClickHouse (stdin-safe).
chq() { kx -n "$TARGET_NS" exec -i "$TARGET_POD" -- clickhouse-client --password "$TPW" -q "$1"; }

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

copy_final_only() {
  local t="$1"
  echo ">> $t: full copy (final pass, plain MergeTree)"
  # Truncate first so a re-run of --final does not duplicate the log rows.
  chq "TRUNCATE TABLE IF EXISTS $TARGET_DB.$t"
  chq "INSERT INTO $TARGET_DB.$t SELECT * FROM $(remote_expr "$t")"
}

echo "== ClickHouse online sync ($([ $FINAL -eq 1 ] && echo FINAL || echo incremental)) =="
for t in $INCREMENTAL_TABLES; do copy_incremental "$t"; done

if [ $FINAL -eq 1 ]; then
  for t in $FINAL_ONLY_TABLES; do copy_final_only "$t"; done
  echo "== OPTIMIZE FINAL to collapse duplicates =="
  for t in $INCREMENTAL_TABLES; do
    echo ">> OPTIMIZE $t FINAL"; chq "OPTIMIZE TABLE $TARGET_DB.$t FINAL" || true
  done
fi

echo "== row counts (target, FINAL) =="
for t in $INCREMENTAL_TABLES $([ $FINAL -eq 1 ] && echo "$FINAL_ONLY_TABLES"); do
  printf '   %-26s %s\n' "$t" "$(chq "SELECT count() FROM $TARGET_DB.$t FINAL" | tr -d '\r')"
done
echo "Done."
