# Upgrading Langfuse Helm Chart v1.x → v2.0

Chart `v2.0.0` replaces Bitnami sub-charts with OSS alternatives and moves ClickHouse to the
upstream [`ClickHouse/clickhouse-operator`](https://github.com/ClickHouse/clickhouse-operator):

| Component | v1.x | v2.0 |
|-----------|------|------|
| PostgreSQL | `bitnami/postgresql` | `groundhog2k/postgres` |
| ClickHouse | `bitnami/clickhouse` (+ ZooKeeper) | `ClickHouseCluster` + `KeeperCluster` |
| Redis | `bitnami/valkey` | `valkey-io/valkey` |
| Object storage | `bitnami/minio` | `seaweedfs/seaweedfs` (allInOne) |

A raw `helm upgrade` that still deploys those stores is **blocked** — StatefulSet identities, PVC
layouts and the ClickHouse coordination backend all change, and the new volumes would be empty.

Two supported paths:

1. **All stores already external** (`*.deploy: false`) — `helm upgrade` the original release in
   place. Service and Ingress names stay the same.
2. **At least one bundled store** — install a sibling v2 release, copy data while v1 serves, then
   shift traffic:
   - **Chart Ingress** (`langfuse.ingress.enabled: true`): v1 keeps the Ingress until cutover.
     Delete the v1 Ingress, then create the v2 Ingress with the same hosts.
   - **No chart Ingress**: point traffic at the new Service / labels, then confirm before the
     script continues.

The chart does not render Gateway API (`HTTPRoute`) resources — only Ingress. An Ingress or
HTTPRoute you manage yourself is treated like the no-Ingress case.

**Design targets:** ~500 GB ClickHouse, ~100 GB object storage, tens of GB Postgres, with
**<5 minutes** of application downtime.

> [!IMPORTANT]
> Rehearse in staging. Take backups of **all** components first
> ([Backup Strategies](https://langfuse.com/self-hosting/configuration/backups)).
> Reuse the same Langfuse `salt`, `encryptionKey` and `nextauth.secret` on v2 — otherwise encrypted
> Postgres columns become undecryptable. Keep the **same Langfuse application version** on the v1
> source and the v2 sibling while copying data — that means both the chart `appVersion` **and** any
> `langfuse.image.tag` overwrite must match. Minimum supported source version for this guide:
> **v3.224.1**.

## Automated migration

[`scripts/migrate-v1-to-v2.sh`](./scripts/migrate-v1-to-v2.sh) walks through the same steps as the
manual section below. It checks CLIs and the kube-context, reads your v1 values file, migrates only
the components that are bundled (`*.deploy: true`; unset defaults to true), and asks before each
larger step.

```bash
cd examples/upgrade-v1-to-v2/scripts

# Required: kubectl, helm >= 3.17, jq, python3
# YAML parsing also needs one of: yq (mikefarah), PyYAML, or Ruby
./migrate-v1-to-v2.sh --values /path/to/your-v1-values.yaml

# Skip prompts (still prints the plan)
./migrate-v1-to-v2.sh --values /path/to/your-v1-values.yaml --yes

# Preflight + generate values only
./migrate-v1-to-v2.sh --values /path/to/your-v1-values.yaml --dry-run
```

Useful flags: `--namespace`, `--source-release`, `--target-release` (default `<source>-v2`),
`--output-values`, `--output-cutover-values`, `--extra-values` (repeatable), `--context`,
`--image-tag` (defaults to the v1 Helm `appVersion` / values tag), `--skip-prereqs`,
`--worker-drain-seconds` (max wait for v1 Redis queues after web scale-down), `--force`
(continue after lag / readiness / queue-drain failures). Helm **≥ 3.17** is required.

| `*.deploy` | Action |
|------------|--------|
| `postgresql.deploy: true` | Enable logical replication on v1, subscribe the sibling, drop subscription at freeze |
| `clickhouse.deploy: true` | Incremental `remote()` copy via [`ch-online-sync.sh`](./scripts/ch-online-sync.sh) |
| `s3.deploy: true` | `mc mirror` MinIO → SeaweedFS (in-cluster `minio/mc` pod) |
| `redis.deploy: true` | Stand up empty Valkey on the sibling (queue/cache; no data copy) |
| any `deploy: false` | Skip that store; copy host/auth fields into the generated overlay |
| all stores external | No sibling; helm-upgrade the original release in place |

Generated overlays:

- all-external: `v2-values.generated.yaml` — in-place `helm upgrade`
- bundled stores: `v2-values.generated.yaml` — sibling install (Ingress off)
- bundled stores + chart Ingress: also `v2-cutover-values.generated.yaml` — Ingress on

## How <5 min downtime is achieved

| Store | Online (v1 live) | Freeze delta |
|-------|------------------|--------------|
| **Postgres** | Logical replication (initial copy + WAL streaming) | Wait `lag_bytes=0`, drop subscription |
| **Object storage (MinIO → SeaweedFS)** | `mc mirror` / `mc mirror --watch` | Final `mc mirror` (new blobs only) |
| **ClickHouse** | `remote()` INSERT…SELECT with an `event_ts` watermark loop | Final watermark pass (no `OPTIMIZE FINAL` by default) |
| **Redis / Valkey** | — (ephemeral queue/cache) | — |

Downtime ≈ freeze writers + drain v1 worker queue + final deltas + traffic shift.
The multi-hour bulk copy runs **outside** the freeze window.

## Naming (sibling path)

The sibling uses the v2 chart defaults for release `langfuse-v2`. No name overrides.

| | Source (v1) | Sibling (v2) |
|--|--|--|
| Helm release | `langfuse` | `langfuse-v2` |
| Namespace | `langfuse` | `langfuse` |
| Web | `langfuse-web` | `langfuse-v2-web` |
| Ingress | `langfuse` (kept until cutover) | `langfuse-v2` (created at cutover) |
| Postgres | `langfuse-postgresql` | `langfuse-v2-postgresql` |
| ClickHouse | `langfuse-clickhouse-shard0` | CHI `langfuse-v2` / pod `langfuse-v2-clickhouse-0-0-0` |
| Object storage | `langfuse-s3` | `langfuse-v2-s3-all-in-one` |
| Redis | `langfuse-redis-primary` | `langfuse-v2-redis` |

---

## Manual steps

Use this section if you prefer to run each command yourself, or to see exactly what the script
does.

### 0. Prerequisites

1. Install cluster-wide **cert-manager** + **clickhouse-operator** (see [minimal-installation](../minimal-installation/)).
2. Enable logical replication on **v1 Postgres** (Bitnami) and restart Postgres (or `helm upgrade` v1 once):

   ```yaml
   postgresql:
     primary:
       extendedConfiguration: |
         wal_level = logical
         max_wal_senders = 10
         max_replication_slots = 10
   ```

   Verify: `show wal_level;` → `logical`.
3. Point the sibling at the **same** Langfuse app Secret as v1 (see [`v2-values.yaml`](./v2-values.yaml)).
   If that Secret is Helm-owned by v1, protect it: `kubectl annotate secret <name> helm.sh/resource-policy=keep`.
4. Size `clickhouse.cluster.resources` in the sibling overlay for your data volume.

### All stores external — in-place upgrade

```bash
helm upgrade langfuse oci://ghcr.io/langfuse/langfuse-k8s/langfuse \
  --version 2.0.0 -n langfuse -f v2-inplace-values.yaml
```

Keep `*.deploy: false` and the existing host/auth fields. Service / Ingress names do not change.

### Bundled stores — sibling + traffic shift

#### 1. Stand up v2 (no downtime)

```bash
helm install langfuse-v2 oci://ghcr.io/langfuse/langfuse-k8s/langfuse \
  --version 2.0.0 -n langfuse -f v2-values.yaml
kubectl -n langfuse rollout status deploy/langfuse-v2-web --timeout=600s
# Schema migrations are done; keep v1 as the only writer
kubectl -n langfuse scale deploy/langfuse-v2-web deploy/langfuse-v2-worker --replicas=0
```

v1 keeps serving. Leave `langfuse.ingress.enabled: false` on the sibling so v1 keeps the domain.

#### 2. Online sync (no downtime)

Run Postgres, object storage, and ClickHouse syncs in parallel.

##### 2a. PostgreSQL — logical replication

```bash
kubectl -n langfuse exec langfuse-postgresql-0 -- \
  psql -U postgres -d postgres_langfuse -c "CREATE PUBLICATION lf_pub FOR ALL TABLES;"

SU_PW=$(kubectl -n langfuse get secret langfuse-v2-postgresql-auth -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
kubectl -n langfuse exec langfuse-v2-postgresql-0 -- env PGPASSWORD="$SU_PW" psql -U postgres -d langfuse -tAc \
  "SELECT 'TRUNCATE TABLE '||string_agg(format('%I.%I',schemaname,tablename),', ')||' CASCADE;' \
   FROM pg_tables WHERE schemaname='public';" | \
  kubectl -n langfuse exec -i langfuse-v2-postgresql-0 -- env PGPASSWORD="$SU_PW" psql -U postgres -d langfuse

V1_PW=$(kubectl -n langfuse get secret langfuse-postgresql -o jsonpath='{.data.postgres-password}' | base64 -d)
kubectl -n langfuse exec langfuse-v2-postgresql-0 -- env PGPASSWORD="$SU_PW" psql -U postgres -d langfuse -c \
  "CREATE SUBSCRIPTION lf_sub \
   CONNECTION 'host=langfuse-postgresql port=5432 dbname=postgres_langfuse user=postgres password=${V1_PW}' \
   PUBLICATION lf_pub;"
```

Watch catch-up (`lag_bytes=0`):

```bash
kubectl -n langfuse exec langfuse-postgresql-0 -- psql -U postgres -d postgres_langfuse -c \
  "SELECT application_name, state, pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes FROM pg_stat_replication;"
```

##### 2b. Object storage — MinIO → SeaweedFS

```bash
V1_KEY=$(kubectl -n langfuse get secret langfuse-s3 -o jsonpath='{.data.root-user}' | base64 -d)
V1_SECRET=$(kubectl -n langfuse get secret langfuse-s3 -o jsonpath='{.data.root-password}' | base64 -d)
V2_KEY=$(kubectl -n langfuse get secret langfuse-v2-s3-auth -o jsonpath='{.data.accessKey}' | base64 -d)
V2_SECRET=$(kubectl -n langfuse get secret langfuse-v2-s3-auth -o jsonpath='{.data.secretKey}' | base64 -d)

mc alias set v1 http://langfuse-s3.langfuse.svc.cluster.local:9000 "$V1_KEY" "$V1_SECRET"
mc alias set v2 http://langfuse-v2-s3-all-in-one.langfuse.svc.cluster.local:8333 "$V2_KEY" "$V2_SECRET"
mc mb --ignore-existing v2/langfuse
mc mirror --overwrite --watch v1/langfuse v2/langfuse
```

##### 2c. ClickHouse — `remote()` watermark loop

```bash
cd scripts
TARGET_POD=langfuse-v2-clickhouse-0-0-0 TARGET_SECRET=langfuse-v2-clickhouse-auth \
  SOURCE_HOST=langfuse-clickhouse.langfuse.svc.cluster.local:9000 SOURCE_SECRET=langfuse-clickhouse \
  ./ch-online-sync.sh
```

#### 3. Freeze & final delta (<5 min window)

```bash
kubectl -n langfuse scale deploy/langfuse-web --replicas=0
# wait until the v1 worker has drained its Redis queues
kubectl -n langfuse scale deploy/langfuse-worker --replicas=0
```

1. **Postgres** — confirm `lag_bytes=0`, then `DROP SUBSCRIPTION lf_sub;` on v2.
2. **Object storage** — final `mc mirror` (no `--watch`).
3. **ClickHouse** — `./ch-online-sync.sh --final`.

```bash
kubectl -n langfuse scale deploy/langfuse-v2-web deploy/langfuse-v2-worker --replicas=1
kubectl -n langfuse rollout status deploy/langfuse-v2-web --timeout=300s
```

#### 4. Shift traffic

**Chart Ingress** — delete v1 first so the hostname is free, then create v2 with the same hosts
(reuse `tls.secretName` so the certificate does not re-issue):

```bash
kubectl -n langfuse delete ingress langfuse
helm upgrade langfuse-v2 oci://ghcr.io/langfuse/langfuse-k8s/langfuse \
  --version 2.0.0 -n langfuse -f v2-app-values.yaml
```

**No chart Ingress** — retarget LoadBalancer / NodePort / external Ingress / HTTPRoute at
`langfuse-v2-web` (`app.kubernetes.io/instance=langfuse-v2`). Confirm that is done before
you treat the cutover as complete.

```bash
kubectl -n langfuse port-forward svc/langfuse-v2-web 3000:3000 &
curl -s localhost:3000/api/public/ready
```

Keep `langfuse` until you are confident, then `helm uninstall langfuse` and delete retained v1
PVCs (`data-langfuse-postgresql-0`, …).

#### Rollback

Until v1 is uninstalled, abort by stopping the sync loops and scaling v1 writers back up. If the
v1 Ingress was already deleted, restore it from the v1 release before sending traffic back.

---

## Files

- [`scripts/migrate-v1-to-v2.sh`](./scripts/migrate-v1-to-v2.sh) — interactive (or `--yes`) migration driver.
- [`scripts/migrate-values.py`](./scripts/migrate-values.py) — v1 → v2 values transform (`sibling` / `cutover` / `inplace`).
- [`v1-values.yaml`](./v1-values.yaml) — representative v1 source values (incl. `wal_level=logical`).
- [`v2-values.yaml`](./v2-values.yaml) — sibling overlay (Ingress off, shared app secrets).
- [`v2-app-values.yaml`](./v2-app-values.yaml) — cutover overlay (Ingress on, same hosts).
- [`scripts/ch-online-sync.sh`](./scripts/ch-online-sync.sh) — ClickHouse incremental sync helper.
