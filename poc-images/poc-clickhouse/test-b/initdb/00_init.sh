#!/bin/bash
clickhouse-client --user default --password "$CLICKHOUSE_ADMIN_PASSWORD" --query "CREATE TABLE initdb_marker (x UInt8) ENGINE = TinyLog"
clickhouse-client --user default --password "$CLICKHOUSE_ADMIN_PASSWORD" --query "INSERT INTO initdb_marker VALUES (7)"
