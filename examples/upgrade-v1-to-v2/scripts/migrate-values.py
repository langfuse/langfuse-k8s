#!/usr/bin/env python3
"""Transform Langfuse Helm v1 values into v2 overlays.

Modes:

  sibling   Full v2 chart for a *new* Helm release next to live v1. Bundled
            stores keep deploy: true; external stores keep host/auth.
            Ingress is forced off so v1 keeps the domain until cutover.

  cutover   Same as sibling, but ingress.enabled is restored from v1 so the
            configured hosts move onto the v2 Service after v1's Ingress is
            deleted.

  inplace   Overlay for `helm upgrade` of the original release. Used when
            every store is already external (*.deploy: false). Ingress and
            Service names stay on that release.

Reads YAML (or JSON) on stdin / --input and writes v2 values YAML to stdout.
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

# v1 keys that do not copy into a bundled-store overlay. Pass --extra-values
# if the sibling needs matching size / storage.
DROPPED_HINTS = (
    "postgresql.primary.resources",
    "postgresql.primary.persistence",
    "postgresql.resources",
    "clickhouse.resources",
    "clickhouse.persistence",
    "clickhouse.zookeeper.replicaCount",
    "s3.persistence",
    "s3.resources",
    "redis.master.resources",
    "redis.primary.resources",
    "redis.resources",
)


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


def ingress_enabled(values: dict[str, Any]) -> bool:
    lf = values.get("langfuse") or {}
    ing = lf.get("ingress") if isinstance(lf, dict) else None
    return bool(isinstance(ing, dict) and ing.get("enabled"))


def pick(src: dict[str, Any] | None, keys: tuple[str, ...]) -> dict[str, Any]:
    if not src:
        return {}
    return {k: src[k] for k in keys if k in src}


def nested_get(data: dict[str, Any], path: str) -> Any:
    cur: Any = data
    for part in path.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def warn_dropped(v1: dict[str, Any]) -> None:
    for path in DROPPED_HINTS:
        root = path.split(".", 1)[0]
        if not deploy_enabled(v1, root):
            continue
        if nested_get(v1, path) is None:
            continue
        sys.stderr.write(
            f"warning: {path} is set in v1 values but is not copied into the generated overlay; "
            "pass --extra-values if the sibling needs matching size / storage\n"
        )


def pin_image_tag(v2: dict[str, Any], tag: str | None) -> dict[str, Any]:
    if not tag:
        return v2
    lf = v2.setdefault("langfuse", {})
    if not isinstance(lf, dict):
        return v2
    image = lf.get("image")
    image = dict(image) if isinstance(image, dict) else {}
    image["tag"] = tag
    lf["image"] = image
    return v2


def copy_langfuse(v1: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(v1.get("langfuse"), dict):
        return {}
    lf = dict(v1["langfuse"])
    lf.pop("allowV1Upgrade", None)
    return lf


def store_blocks(v1: dict[str, Any]) -> dict[str, Any]:
    v2: dict[str, Any] = {}
    if deploy_enabled(v1, "postgresql"):
        v2["postgresql"] = {"deploy": True}
    else:
        v2["postgresql"] = pick(v1.get("postgresql"), PG_KEEP)
        v2["postgresql"]["deploy"] = False

    ch_src = v1.get("clickhouse") or {}
    if deploy_enabled(v1, "clickhouse"):
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

    if deploy_enabled(v1, "redis"):
        v2["redis"] = {"deploy": True}
    else:
        v2["redis"] = pick(v1.get("redis"), REDIS_KEEP)
        v2["redis"]["deploy"] = False

    if deploy_enabled(v1, "s3"):
        v2["s3"] = {"deploy": True}
    else:
        v2["s3"] = pick(v1.get("s3"), S3_KEEP)
        v2["s3"]["deploy"] = False
    return v2


def apply_auth_secrets(v2: dict[str, Any], fullname: str) -> dict[str, Any]:
    """Point bundled-store sub-charts at <fullname>-*-auth (chart defaults assume 'langfuse')."""
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


def migrate_sibling(v1: dict[str, Any], target_fullname: str, *, ingress: bool) -> dict[str, Any]:
    lf = copy_langfuse(v1)
    lf.setdefault("ingress", {})
    if isinstance(lf["ingress"], dict):
        lf["ingress"] = dict(lf["ingress"])
        lf["ingress"]["enabled"] = bool(ingress and ingress_enabled(v1))
    v2: dict[str, Any] = {"langfuse": lf}
    v2.update(store_blocks(v1))
    return apply_auth_secrets(v2, target_fullname)


def migrate_inplace(v1: dict[str, Any]) -> dict[str, Any]:
    v2: dict[str, Any] = {}
    for k in ROOT_KEEP:
        if k in v1:
            v2[k] = v1[k]
    if lf := copy_langfuse(v1):
        v2["langfuse"] = lf
    v2.update(store_blocks(v1))
    return v2


def plan(v1: dict[str, Any]) -> dict[str, bool]:
    return {
        "postgresql": deploy_enabled(v1, "postgresql"),
        "clickhouse": deploy_enabled(v1, "clickhouse"),
        "redis": deploy_enabled(v1, "redis"),
        "s3": deploy_enabled(v1, "s3"),
        "ingress": ingress_enabled(v1),
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input", "-i", default="-", help="v1 values YAML/JSON (default: stdin)")
    p.add_argument("--output", "-o", default="-", help="v2 values YAML (default: stdout)")
    p.add_argument(
        "--mode",
        choices=("sibling", "cutover", "inplace", "stores", "final", "app"),
        default="sibling",
        help="sibling/stores: new v2 release, ingress off. cutover: same with ingress restored. inplace/final/app: in-place overlay for all-external stores",
    )
    p.add_argument(
        "--target-fullname",
        "--source-fullname",
        "--stores-fullname",
        dest="target_fullname",
        help="v2 sibling fullname (auth Secret names). Required for sibling/cutover",
    )
    p.add_argument("--plan", action="store_true", help="print enabled-component JSON and exit")
    p.add_argument(
        "--image-tag",
        dest="image_tag",
        help="Pin langfuse.image.tag so the sibling / in-place upgrade matches v1",
    )
    args = p.parse_args()

    v1 = load(None if args.input == "-" else args.input)
    if args.plan:
        json.dump(plan(v1), sys.stdout)
        sys.stdout.write("\n")
        return 0

    mode = args.mode
    if mode in ("final", "app"):
        mode = "inplace"
    elif mode == "stores":
        mode = "sibling"

    if mode in ("sibling", "cutover"):
        if not args.target_fullname:
            sys.stderr.write("error: --target-fullname is required for sibling/cutover\n")
            return 2
        data = migrate_sibling(v1, args.target_fullname, ingress=(mode == "cutover"))
        warn_dropped(v1)
    else:
        data = migrate_inplace(v1)

    pin_image_tag(data, args.image_tag)

    text = dump_yaml(data)
    if args.output == "-":
        sys.stdout.write(text)
    else:
        with open(args.output, "w", encoding="utf-8") as fh:
            fh.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
