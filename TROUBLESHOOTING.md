# Troubleshooting Guide

In this guide, we collect common issues and solution approaches to address problems you might encounter while the Langfuse Helm chart.

## Invalid Clickhouse Password - Avoid special characters

If you encounter an error like
```
clickhouse 18:12:26.18 INFO  ==> ** Starting ClickHouse **
Processing configuration file '/opt/bitnami/clickhouse/etc/config.xml'.
Merging configuration file '/opt/bitnami/clickhouse/etc/conf.d/00_default_overrides.xml'.
Poco::Exception. Code: 1000, e.code() = 0, Exception: Failed to preprocess config '/opt/bitnami/clickhouse/etc/config.xml': SAXParseException: Invalid token in line 1 column 18, Stack trace (when copying this message, always include the lines below):
```
it is often due to a ClickHouse password that contains special characters.

Known bad characters include (but are not limited to): `%, @`
