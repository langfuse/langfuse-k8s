# External components (parity examples)

Each of the four data stores can be brought in from outside the chart independently via
`*.deploy: false`. The other three continue to be deployed by the chart.

These overlays are meant to be combined with [`../minimal-installation/values.yaml`](../minimal-installation/values.yaml)
(or any base that already supplies the Langfuse app secrets):

```bash
helm install langfuse . -n langfuse \
  -f ../../examples/minimal-installation/values.yaml \
  -f ../../examples/external-components/external-postgres.yaml
```

| Overlay | What stays bundled | What you bring |
|---------|--------------------|----------------|
| [`external-postgres.yaml`](./external-postgres.yaml) | ClickHouse, Valkey, SeaweedFS | PostgreSQL |
| [`external-redis.yaml`](./external-redis.yaml) | Postgres, ClickHouse, SeaweedFS | Redis / Valkey |
| [`external-s3.yaml`](./external-s3.yaml) | Postgres, ClickHouse, Valkey | S3-compatible blob store |
| [`external-clickhouse.yaml`](./external-clickhouse.yaml) | Postgres, Valkey, SeaweedFS | ClickHouse (e.g. operator-managed or ClickHouse Cloud) |

> For a fully external ClickHouse + Langfuse v4 image pin, see also
> [`../v4-installation`](../v4-installation/), which applies the ClickHouse operator CRs out-of-band.

## Verification checklist (per component)

For each overlay, after install:

1. `kubectl -n langfuse get pods` — the disabled component's pods are **absent**.
2. `langfuse-web` / `langfuse-worker` become Ready.
3. `curl localhost:3000/api/public/ready` (via port-forward) returns `{"status":"OK",...}`.
4. A trivial write path works (sign-up / create a project / ingest a trace) and does not error on the external store.
