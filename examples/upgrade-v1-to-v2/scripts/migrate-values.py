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

Postgres data movement (sibling/cutover only, when postgresql.deploy is true):

  logical        Default. Empty sibling Postgres; copy with logical replication.
  reuse-volume   Point the sibling at the Bitnami PVC (data-<src>-postgresql-0)
                 after v1 Postgres is scaled to 0. Same major version, auth, and
                 on-disk layout (settings.pgDir=data). No online copy.
"""
from __future__ import annotations

import argparse
import json
import os
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
BUNDLED_S3_KEEP = tuple(k for k in S3_KEEP if k not in ("deploy", "endpoint"))
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


def bundled_s3_buckets(s3: dict[str, Any]) -> set[str]:
    """Effective bucket per upload type, mirroring the chart's coalesce."""
    default = s3.get("bucket") or s3.get("defaultBuckets") or "langfuse"
    buckets: set[str] = set()
    for upload_type in ("eventUpload", "batchExport", "mediaUpload"):
        cfg = s3.get(upload_type)
        cfg = cfg if isinstance(cfg, dict) else {}
        buckets.add(cfg.get("bucket") or default)
    return buckets


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
    if not isinstance(ch_src, dict):
        ch_src = {}
    if deploy_enabled(v1, "clickhouse"):
        # v1 defaulted to 3 ClickHouse replicas, v2 defaults to 1 — always pin
        # the replica count so defaults-relying installs keep their topology.
        replicas = ch_src.get("replicaCount")
        cluster: dict[str, Any] = {"replicas": replicas if replicas is not None else 3}
        if "clusterEnabled" in ch_src:
            cluster["enabled"] = bool(ch_src["clusterEnabled"])
        v2["clickhouse"] = {"deploy": True, "cluster": cluster}
    else:
        v2["clickhouse"] = pick(ch_src, CH_KEEP)
        v2["clickhouse"]["deploy"] = False
        # v1's flat clusterEnabled key moved to cluster.enabled in v2.
        if "clusterEnabled" in ch_src:
            v2["clickhouse"]["cluster"] = {"enabled": bool(ch_src["clusterEnabled"])}

    if deploy_enabled(v1, "redis"):
        v2["redis"] = {"deploy": True}
    else:
        v2["redis"] = pick(v1.get("redis"), REDIS_KEEP)
        v2["redis"]["deploy"] = False

    if deploy_enabled(v1, "s3"):
        # Keep the Langfuse-facing S3 settings (bucket, region, prefixes,
        # credentials) — dropping them pointed the migrated release at the
        # default 'langfuse' bucket while the mirrored data lives under the
        # v1 bucket name. Only `endpoint` is dropped: v2 auto-discovers the
        # bundled SeaweedFS, and a copied v1 MinIO endpoint would dangle.
        v2["s3"] = pick(v1.get("s3"), BUNDLED_S3_KEEP)
        v2["s3"]["deploy"] = True
        buckets = bundled_s3_buckets(v2["s3"])
        if buckets and buckets != {"langfuse"}:
            v2["s3"].setdefault("allInOne", {}).setdefault("s3", {})[
                "createBuckets"
            ] = [{"name": name} for name in sorted(buckets)]
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


def scale_app_to_zero(v2: dict[str, Any]) -> None:
    """Keep sibling web/worker off until the reused Postgres volume is attached."""
    lf = v2.setdefault("langfuse", {})
    if not isinstance(lf, dict):
        return
    lf["replicas"] = 0
    for comp in ("web", "worker"):
        block = lf.get(comp)
        block = dict(block) if isinstance(block, dict) else {}
        block["replicas"] = 0
        lf[comp] = block


def apply_postgres_volume_reuse(
    v2: dict[str, Any],
    *,
    pvc: str,
    image_tag: str,
    username: str,
    database: str,
    password: str | None,
    run_as_user: int,
    pg_dir: str,
) -> None:
    """Mount the Bitnami PVC on groundhog2k/postgres instead of creating a new volume.

    Bitnami stores PGDATA in a `data/` subdirectory of the volume and runs as UID
    1001. Official postgres (groundhog2k) defaults to `/var/lib/postgresql/data/pg`
    and UID 999 — both must be overridden or the existing files are invisible /
    unreadable. The sibling overlay keeps replicaCount at the sub-chart default
    (1); the migration script leaves v1 Postgres running until freeze so the v2
    pod stays Pending on the RWO volume, then scales v1 to 0.
    """
    uid = int(run_as_user)
    # The chart blocks a helm upgrade that still deploys Postgres when the
    # Bitnami PVC data-<release>-postgresql-0 is present (v2 would otherwise
    # create empty postgres-data-<release>-postgresql-0). reuse-volume keeps
    # that PVC on purpose, so the guard must be lifted.
    lf = v2.setdefault("langfuse", {})
    if isinstance(lf, dict):
        lf["allowV1Upgrade"] = True
    pg = v2.setdefault("postgresql", {})
    pg["deploy"] = True
    auth = pg.setdefault("auth", {})
    auth["username"] = username
    auth["database"] = database
    if password:
        auth["password"] = password
    settings = pg.setdefault("settings", {})
    settings["pgDir"] = pg_dir
    # Bitnami 1.5.x ships Debian 12 (glibc 2.36). Current docker.io/postgres:<major>
    # is Debian 13 and prints a collation version mismatch; pin bookworm to stay
    # on glibc 2.36. Bare majors from SHOW server_version get this suffix.
    tag = str(image_tag)
    if tag.isdigit():
        tag = f"{tag}-bookworm"
    image = pg.setdefault("image", {})
    image["tag"] = tag
    storage = pg.setdefault("storage", {})
    storage["persistentVolumeClaimName"] = pvc
    pg["podSecurityContext"] = {"fsGroup": uid}
    pg["securityContext"] = {
        "runAsUser": uid,
        "runAsGroup": uid,
        "runAsNonRoot": True,
    }
    data_dir = f"/var/lib/postgresql/data/{pg_dir}".replace("//", "/")
    pg["extraInitContainers"] = [
        {
            "name": "bitnami-pgconf",
            "image": f"docker.io/postgres:{tag}",
            "imagePullPolicy": "IfNotPresent",
            "securityContext": {
                "runAsUser": uid,
                "runAsGroup": uid,
                "runAsNonRoot": True,
                "allowPrivilegeEscalation": False,
            },
            "command": [
                "sh",
                "-c",
                (
                    "set -e\n"
                    f'DATA="{data_dir}"\n'
                    'if [ ! -f "$DATA/PG_VERSION" ]; then echo "bitnami-pgconf: no PG_VERSION in $DATA"; exit 0; fi\n'
                    'if [ ! -f "$DATA/postgresql.conf" ]; then\n'
                    '  printf "%s\\n" "listen_addresses = \'*\'" "port = 5432" '
                    '"unix_socket_directories = \'/tmp\'" "password_encryption = scram-sha-256" '
                    '> "$DATA/postgresql.conf"\n'
                    '  echo "bitnami-pgconf: wrote $DATA/postgresql.conf"\n'
                    "fi\n"
                    'if [ ! -f "$DATA/pg_hba.conf" ]; then\n'
                    '  printf "%s\\n" "local   all  all                trust" '
                    '"host    all  all  127.0.0.1/32  trust" '
                    '"host    all  all  ::1/128       trust" '
                    '"host    all  all  0.0.0.0/0     scram-sha-256" '
                    '"host    all  all  ::/0          scram-sha-256" '
                    '> "$DATA/pg_hba.conf"\n'
                    '  echo "bitnami-pgconf: wrote $DATA/pg_hba.conf"\n'
                    "fi\n"
                ),
            ],
            "volumeMounts": [
                {"name": "postgres-data", "mountPath": "/var/lib/postgresql/data"},
            ],
        }
    ]
    # Official image has no passwd entry for Bitnami UID 1001, so the default
    # `pg_isready -h localhost` returns "no attempt". Probe as the postgres role.
    probe_exec = {
        "exec": {"command": ["pg_isready", "-h", "127.0.0.1", "-U", "postgres"]},
        "initialDelaySeconds": 10,
        "timeoutSeconds": 5,
        "periodSeconds": 10,
        "successThreshold": 1,
    }
    pg["customStartupProbe"] = {**probe_exec, "failureThreshold": 30}
    pg["customLivenessProbe"] = {**probe_exec, "failureThreshold": 3}
    pg["customReadinessProbe"] = {**probe_exec, "failureThreshold": 3}


def migrate_sibling(
    v1: dict[str, Any],
    target_fullname: str,
    *,
    ingress: bool,
    postgres_reuse: dict[str, Any] | None = None,
) -> dict[str, Any]:
    lf = copy_langfuse(v1)
    lf.setdefault("ingress", {})
    if isinstance(lf["ingress"], dict):
        lf["ingress"] = dict(lf["ingress"])
        lf["ingress"]["enabled"] = bool(ingress and ingress_enabled(v1))
    v2: dict[str, Any] = {"langfuse": lf}
    v2.update(store_blocks(v1))
    apply_auth_secrets(v2, target_fullname)
    if postgres_reuse:
        apply_postgres_volume_reuse(v2, **postgres_reuse)
        if not ingress:
            scale_app_to_zero(v2)
    return v2


def migrate_inplace(v1: dict[str, Any]) -> dict[str, Any]:
    v2: dict[str, Any] = {}
    for k in ROOT_KEEP:
        if k in v1:
            v2[k] = v1[k]
    if lf := copy_langfuse(v1):
        v2["langfuse"] = lf
    v2.update(store_blocks(v1))
    return v2


def plan(v1: dict[str, Any], postgres_mode: str = "logical") -> dict[str, Any]:
    pg = deploy_enabled(v1, "postgresql")
    return {
        "postgresql": pg,
        "clickhouse": deploy_enabled(v1, "clickhouse"),
        "redis": deploy_enabled(v1, "redis"),
        "s3": deploy_enabled(v1, "s3"),
        "ingress": ingress_enabled(v1),
        "postgresMode": postgres_mode if pg else "skip",
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
    p.add_argument(
        "--postgres-mode",
        choices=("logical", "reuse-volume"),
        default="logical",
        help="logical (default): replicate into a new volume. reuse-volume: mount the Bitnami PVC on the sibling",
    )
    p.add_argument("--postgres-pvc", help="Bitnami PVC name (required for reuse-volume)")
    p.add_argument("--postgres-image-tag", help="Postgres major/image tag matching v1 (required for reuse-volume)")
    p.add_argument("--postgres-username", help="Override postgresql.auth.username for reuse-volume")
    p.add_argument("--postgres-database", help="Override postgresql.auth.database for reuse-volume")
    p.add_argument(
        "--postgres-password",
        help="v1 superuser password (or set POSTGRES_REUSE_PASSWORD). Written into the generated overlay",
    )
    p.add_argument("--postgres-run-as-user", type=int, default=1001, help="UID/GID of the Bitnami data files (default 1001)")
    p.add_argument("--postgres-pg-dir", default="data", help="PGDATA directory on the Bitnami volume (default data)")
    args = p.parse_args()

    v1 = load(None if args.input == "-" else args.input)
    if args.plan:
        json.dump(plan(v1, args.postgres_mode), sys.stdout)
        sys.stdout.write("\n")
        return 0

    mode = args.mode
    if mode in ("final", "app"):
        mode = "inplace"
    elif mode == "stores":
        mode = "sibling"

    postgres_reuse = None
    if args.postgres_mode == "reuse-volume":
        if mode == "inplace":
            sys.stderr.write("error: --postgres-mode reuse-volume is only valid for sibling/cutover (bundled Postgres)\n")
            return 2
        if not deploy_enabled(v1, "postgresql"):
            sys.stderr.write("error: --postgres-mode reuse-volume requires postgresql.deploy=true\n")
            return 2
        if not args.postgres_pvc or not args.postgres_image_tag:
            sys.stderr.write("error: --postgres-pvc and --postgres-image-tag are required for reuse-volume\n")
            return 2
        pg_src = v1.get("postgresql") or {}
        auth_src = pg_src.get("auth") if isinstance(pg_src, dict) else {}
        if not isinstance(auth_src, dict):
            auth_src = {}
        password = (
            os.environ.get("POSTGRES_REUSE_PASSWORD")
            or args.postgres_password
            or auth_src.get("password")
            or None
        )
        postgres_reuse = {
            "pvc": args.postgres_pvc,
            "image_tag": args.postgres_image_tag,
            "username": args.postgres_username or auth_src.get("username") or "postgres",
            "database": args.postgres_database or auth_src.get("database") or "postgres_langfuse",
            "password": password,
            "run_as_user": args.postgres_run_as_user,
            "pg_dir": args.postgres_pg_dir,
        }

    if mode in ("sibling", "cutover"):
        if not args.target_fullname:
            sys.stderr.write("error: --target-fullname is required for sibling/cutover\n")
            return 2
        data = migrate_sibling(
            v1,
            args.target_fullname,
            ingress=(mode == "cutover"),
            postgres_reuse=postgres_reuse,
        )
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
