# Troubleshooting Guide

In this guide, we collect common issues and solution approaches to address problems you might encounter while the Langfuse Helm chart.

## Invalid ClickHouse Password - Avoid special characters

If you encounter an error like
```
clickhouse 18:12:26.18 INFO  ==> ** Starting ClickHouse **
Processing configuration file '/opt/bitnami/clickhouse/etc/config.xml'.
Merging configuration file '/opt/bitnami/clickhouse/etc/conf.d/00_default_overrides.xml'.
Poco::Exception. Code: 1000, e.code() = 0, Exception: Failed to preprocess config '/opt/bitnami/clickhouse/etc/config.xml': SAXParseException: Invalid token in line 1 column 18, Stack trace (when copying this message, always include the lines below):
```
or
```
2025.06.27 09:30:06.335559 [ 47 ] {} <Error> DynamicQueryHandler: Code: 194. DB::Exception: default: Authentication failed: password is incorrect, or there is no user with such name.
```
or
```
error: failed to open database: driver: bad connection
Applying clickhouse migrations failed. This is mostly caused by the database being unavailable.
```
it is often due to a ClickHouse password that contains special characters.

Known bad characters include (but are not limited to): `%, @, :, &, #, ?, $`

## Data randomly disappears within the Langfuse UI

If you observe inconsistent reads, e.g. seeing different values within a table on each reload, or receiving 404 errors when opening a trace from a table,
this is often due to a misconfigured ClickHouse replication setup.

This can happen in two cases:
- **Multi-shard setup**: You've configure more than one ClickHouse shard. Langfuse only supports single-shard setups. Recreate your cluster with a single shard to resolve this.
- **Moving from single-replica to multi-replica**: If you previously had a single-replica setup and then added a second replica, the tables are not configured for replication. Recreate your cluster with a multi-replica setup to resolve this.

## ClickHouse Configuration Conflicts

If you experience odd connection behavior to ClickHouse, including authentication failures, connection timeouts, or inconsistent connectivity, this may be due to conflicting ClickHouse configurations.

The chart validates that ClickHouse configuration is not set in both the new `clickhouse` structure and the legacy `langfuse.additionalEnv` environment variables simultaneously.
If you have ClickHouse environment variables in `langfuse.additionalEnv` (such as `CLICKHOUSE_URL`, `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_MIGRATION_URL`), you must either:

1. Remove these from `langfuse.additionalEnv` and use only the new `clickhouse` configuration structure, or
2. Continue using only `langfuse.additionalEnv` for all ClickHouse settings and avoid setting any values in the `clickhouse` section

Using both approaches simultaneously will cause the chart deployment to fail with validation errors or produce inconsistent results when connecting.

## PostgreSQL Deployment Error - Existing Secret

If you encounter an error in the PostgreSQL deployment when using an `existingSecret`, ensure that you are providing both `userPasswordKey` and `adminPasswordKey` in the `postgresql.auth.secretKeys` configuration.

When using the default `postgres` user, both keys are required by the underlying Bitnami PostgreSQL chart to correctly map the password from the secret.

```yaml
postgresql:
  deploy: true
  auth:
    existingSecret: my-secret
    secretKeys:
      adminPasswordKey: postgres-password
      userPasswordKey: postgres-password
```
