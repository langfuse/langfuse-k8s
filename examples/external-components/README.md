# External components (parity examples)

Each of the four data stores can be brought in from outside the chart independently via
`*.deploy: false`. The other three continue to be deployed by the chart.

**Overlays are additive** — you can combine several in the same `helm install` / `helm upgrade`
(for example Postgres + Redis both external) as long as their keys do not conflict:

```bash
helm install langfuse . -n langfuse \
  -f ../../examples/minimal-installation/values.yaml \
  -f ../../examples/external-components/external-postgres.yaml \
  -f ../../examples/external-components/external-redis.yaml
```

| Overlay | What stays bundled | What you bring |
|---------|--------------------|----------------|
| [`external-postgres.yaml`](./external-postgres.yaml) | ClickHouse, Valkey, SeaweedFS | PostgreSQL |
| [`external-redis.yaml`](./external-redis.yaml) | Postgres, ClickHouse, SeaweedFS | Redis / Valkey |
| [`external-s3.yaml`](./external-s3.yaml) | Postgres, ClickHouse, Valkey | S3-compatible blob store |
| [`external-clickhouse.yaml`](./external-clickhouse.yaml) | Postgres, Valkey, SeaweedFS | ClickHouse (operator-managed, ClickHouse Cloud, …) |

For an in-cluster ClickHouse managed by the operator **outside** the chart (instead of
`clickhouse.deploy: true`), apply [`clickhouse-cluster.yaml`](./clickhouse-cluster.yaml) and use
[`external-clickhouse.yaml`](./external-clickhouse.yaml).

## Verification checklist (per component)

For each overlay, after install:

1. `kubectl -n langfuse get pods` — the disabled component's pods are **absent**.
2. `langfuse-web` / `langfuse-worker` become Ready.
3. `curl localhost:3000/api/public/ready` (via port-forward) returns `{"status":"OK",...}`.
4. A trivial write path works (sign-up / create a project / ingest a trace) and does not error on the external store.
