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
it is often due to a ClickHouse password that contains special characters.

Known bad characters include (but are not limited to): `%, @, :`

## Data randomly disappears within the Langfuse UI

If you observe inconsistent reads, e.g. seeing different values within a table on each reload, or receiving 404 errors when opening a trace from a table,
this is often due to a misconfigured ClickHouse replication setup.

This can happen in two cases:
- **Multi-shard setup**: You've configure more than one ClickHouse shard. Langfuse only supports single-shard setups. Recreate your cluster with a single shard to resolve this.
- **Moving from single-replica to multi-replica**: If you previously had a single-replica setup and then added a second replica, the tables are not configured for replication. Recreate your cluster with a multi-replica setup to resolve this.
