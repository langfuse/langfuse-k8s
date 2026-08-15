#!/usr/bin/env python3
"""Transform Langfuse Helm v1 values into a v2 overlay for blue/green install.

Reads YAML (or JSON) on stdin / --input and writes v2 values YAML to stdout.
Keeps Langfuse app settings and external-store connection fields; drops Bitnami
sub-chart keys. Components with deploy: false are passed through as external.
"""
from __future__ import annotations

import argparse
import json
import sys
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None


PG_KEEP = (
    "deploy",
    "host",
    "port",
    "args",
    "directUrl",
    "shadowDatabaseUrl",
    "auth",
    "migration",
)
CH_KEEP = (
    "deploy",
    "host",
    "httpPort",
    "nativePort",
    "database",
    "auth",
    "migration",
    "crdCheck",
)
REDIS_KEEP = (
    "deploy",
    "host",
    "port",
    "auth",
    "tls",
    "cluster",
    "sentinel",
)
S3_KEEP = (
    "deploy",
    "storageProvider",
    "bucket",
    "region",
    "endpoint",
    "forcePathStyle",
    "prefix",
    "accessKeyId",
    "secretAccessKey",
    "auth",
    "gcs",
    "concurrency",
    "eventUpload",
    "batchExport",
    "mediaUpload",
    "defaultBuckets",
)
ROOT_KEEP = ("nameOverride", "fullnameOverride")


def load(path: str | None) -> dict[str, Any]:
    raw = sys.stdin.read() if path in (None, "-") else open(path, encoding="utf-8").read()
    stripped = raw.lstrip()
    if stripped.startswith("{") or stripped.startswith("["):
        data = json.loads(raw)
    else:
        if yaml is None:
            sys.stderr.write("error: PyYAML is required to read YAML values (pip install pyyaml), or pass JSON\n")
            sys.exit(2)
        data = yaml.safe_load(raw)
    if not isinstance(data, dict):
        sys.stderr.write("error: values file must be a mapping\n")
        sys.exit(2)
    return data


def dump_yaml(data: dict[str, Any]) -> str:
    if yaml is None:
        return json.dumps(data, indent=2) + "\n"
    return yaml.safe_dump(data, sort_keys=False, default_flow_style=False)


def deploy_enabled(values: dict[str, Any], key: str) -> bool:
    block = values.get(key) or {}
    if not isinstance(block, dict) or "deploy" not in block:
        return True
    return bool(block["deploy"])


def pick(src: dict[str, Any] | None, keys: tuple[str, ...]) -> dict[str, Any]:
    if not src:
        return {}
    return {k: src[k] for k in keys if k in src}


def apply_target_secrets(v2: dict[str, Any], fullname: str) -> dict[str, Any]:
    """Point sub-charts at the release-prefixed auth Secrets this chart creates."""
    pg = v2.setdefault("postgresql", {})
    if pg.get("deploy", True):
        pg.setdefault("settings", {})["existingSecret"] = f"{fullname}-postgresql-auth"
        pg.setdefault("userDatabase", {})["existingSecret"] = f"{fullname}-postgresql-auth"
    redis = v2.setdefault("redis", {})
    if redis.get("deploy", True):
        redis.setdefault("auth", {})["usersExistingSecret"] = f"{fullname}-redis-auth"
    s3 = v2.setdefault("s3", {})
    if s3.get("deploy", True):
        s3.setdefault("allInOne", {}).setdefault("s3", {})["existingConfigSecret"] = f"{fullname}-s3-auth"
    return v2


def migrate(v1: dict[str, Any], target_fullname: str | None = None) -> dict[str, Any]:
    v2: dict[str, Any] = {}
    for k in ROOT_KEEP:
        if k in v1:
            v2[k] = v1[k]

    if isinstance(v1.get("langfuse"), dict):
        lf = dict(v1["langfuse"])
        lf.pop("allowV1Upgrade", None)
        v2["langfuse"] = lf

    pg_on = deploy_enabled(v1, "postgresql")
    if pg_on:
        v2["postgresql"] = {"deploy": True}
    else:
        v2["postgresql"] = pick(v1.get("postgresql"), PG_KEEP)
        v2["postgresql"]["deploy"] = False

    ch_on = deploy_enabled(v1, "clickhouse")
    ch_src = v1.get("clickhouse") or {}
    if ch_on:
        cluster: dict[str, Any] = {}
        if isinstance(ch_src, dict) and ch_src.get("replicaCount") is not None:
            cluster["replicas"] = ch_src["replicaCount"]
        v2["clickhouse"] = {"deploy": True}
        if cluster:
            v2["clickhouse"]["cluster"] = cluster
    else:
        v2["clickhouse"] = pick(ch_src if isinstance(ch_src, dict) else {}, CH_KEEP)
        v2["clickhouse"]["deploy"] = False
        if isinstance(ch_src, dict) and isinstance(ch_src.get("cluster"), dict):
            v2["clickhouse"]["cluster"] = pick(ch_src["cluster"], ("enabled",))

    redis_on = deploy_enabled(v1, "redis")
    if redis_on:
        v2["redis"] = {"deploy": True}
    else:
        v2["redis"] = pick(v1.get("redis"), REDIS_KEEP)
        v2["redis"]["deploy"] = False

    s3_on = deploy_enabled(v1, "s3")
    if s3_on:
        v2["s3"] = {"deploy": True}
    else:
        v2["s3"] = pick(v1.get("s3"), S3_KEEP)
        v2["s3"]["deploy"] = False

    if target_fullname:
        apply_target_secrets(v2, target_fullname)
    return v2


def plan(v1: dict[str, Any]) -> dict[str, bool]:
    return {
        "postgresql": deploy_enabled(v1, "postgresql"),
        "clickhouse": deploy_enabled(v1, "clickhouse"),
        "redis": deploy_enabled(v1, "redis"),
        "s3": deploy_enabled(v1, "s3"),
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input", "-i", default="-", help="v1 values YAML/JSON (default: stdin)")
    p.add_argument("--output", "-o", default="-", help="v2 values YAML (default: stdout)")
    p.add_argument("--target-fullname", help="v2 release fullname; wires sub-chart auth Secret names")
    p.add_argument("--plan", action="store_true", help="print enabled-component JSON and exit")
    args = p.parse_args()

    v1 = load(None if args.input == "-" else args.input)
    if args.plan:
        json.dump(plan(v1), sys.stdout)
        sys.stdout.write("\n")
        return 0

    text = dump_yaml(migrate(v1, target_fullname=args.target_fullname))
    if args.output == "-":
        sys.stdout.write(text)
    else:
        with open(args.output, "w", encoding="utf-8") as fh:
            fh.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
