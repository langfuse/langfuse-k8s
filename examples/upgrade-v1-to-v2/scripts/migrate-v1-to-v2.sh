#!/usr/bin/env bash
# Langfuse Helm v1 → v2 migration.
# Mirrors examples/upgrade-v1-to-v2/README.md. Review that file before running.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
VALUES_MIGRATE="$SCRIPT_DIR/migrate-values.py"
CH_SYNC="$SCRIPT_DIR/ch-online-sync.sh"

YES=0
DRY_RUN=0
SKIP_PREREQS=0
FORCE=0
NAMESPACE="${NAMESPACE:-langfuse}"
SOURCE_RELEASE="${SOURCE_RELEASE:-}"
TARGET_RELEASE="${TARGET_RELEASE:-}"
VALUES_FILE=""
OUTPUT_VALUES=""
OUTPUT_CUTOVER_VALUES=""
EXTRA_VALUES=()
KCTX="${KCTX:-}"
CHART="${CHART:-}"
CHART_VERSION="${CHART_VERSION:-2.0.0}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.20.2}"
CLICKHOUSE_OPERATOR_VERSION="${CLICKHOUSE_OPERATOR_VERSION:-0.0.5}"
WORKER_DRAIN_SECONDS="${WORKER_DRAIN_SECONDS:-60}"
MC_IMAGE="${MC_IMAGE:-minio/mc:latest}"
IMAGE_TAG="${IMAGE_TAG:-}"
MC_POD=""
RESUME_TARGET=0

usage() {
  cat <<'EOF'
Usage: migrate-v1-to-v2.sh --values <v1-values.yaml> [options]

Migration from Langfuse Helm chart v1 (Bitnami) to v2 (OSS).

  • All stores external (*.deploy: false): helm-upgrade the original release
    in place. Service / Ingress names stay the same.
  • At least one bundled store: install a sibling v2 release, copy data, then
    shift traffic (delete v1 Ingress then create v2 Ingress, or confirm a
    manual Service cutover).

Options:
  -f, --values PATH         Current v1 values file (required)
  -n, --namespace NAME      Kubernetes namespace (default: langfuse)
      --source-release NAME v1 Helm release (default: auto-detect)
      --target-release NAME sibling v2 release (default: <source>-v2)
      --stores-release NAME alias for --target-release
  -o, --output-values PATH  Generated sibling or in-place overlay
      --output-cutover-values PATH  Sibling overlay with ingress enabled
      --output-app-values PATH      alias for --output-cutover-values
      --extra-values PATH   Extra Helm values (repeatable)
      --chart REF           Chart ref or path (default: local charts/langfuse or OCI)
      --chart-version VER   Chart version when using OCI (default: 2.0.0)
      --context NAME        kube-context passed to kubectl/helm
      --image-tag TAG       Pin langfuse.image.tag (default: v1 values or Helm appVersion)
  -y, --yes                 Do not prompt; run every remaining step
      --force               Continue after Postgres lag / readiness / queue-drain failures
      --dry-run             Preflight + plan + generate values; do not change the cluster
      --skip-prereqs        Do not install cert-manager / ClickHouse operator
      --worker-drain-seconds N  Max seconds to wait for v1 Redis queues after scaling web down (default: 60)
  -h, --help                Show this help

Environment: KUBECTL, HELM, KCTX, NAMESPACE, WORKER_DRAIN_SECONDS, MC_IMAGE, IMAGE_TAG
EOF
}

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

NEED_CMDS=()
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || NEED_CMDS+=("$1")
}

kx() { "$KUBECTL" ${KCTX:+--context "$KCTX"} "$@"; }
hx() { "$HELM" ${KCTX:+--kube-context "$KCTX"} "$@"; }

confirm() {
  local msg=$1
  if [ "$YES" -eq 1 ]; then
    log "$msg [yes]"
    return 0
  fi
  printf '%s\n' "$msg"
  printf 'Proceed? [y/N] '
  local ans
  read -r ans
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) die "aborted" ;;
  esac
}

yaml_to_json() {
  local file=$1
  if command -v yq >/dev/null 2>&1 && yq --version 2>&1 | grep -qi 'mikefarah'; then
    yq -o=json "$file"
    return
  fi
  if python3 -c "import yaml" >/dev/null 2>&1; then
    python3 -c "import json,sys,yaml; json.dump(yaml.safe_load(open(sys.argv[1])), sys.stdout)" "$file"
    return
  fi
  if command -v ruby >/dev/null 2>&1; then
    ruby -ryaml -rjson -e 'puts JSON.generate(YAML.load_file(ARGV[0]) || {})' "$file"
    return
  fi
  die "cannot parse YAML: install yq (mikefarah), PyYAML (pip install pyyaml), or Ruby"
}

json_to_yaml() {
  if python3 -c "import yaml" >/dev/null 2>&1; then
    python3 -c "import json,sys,yaml; yaml.safe_dump(json.load(sys.stdin), sys.stdout, sort_keys=False)"
    return
  fi
  if command -v yq >/dev/null 2>&1; then
    yq -P -o=yaml .
    return
  fi
  if command -v ruby >/dev/null 2>&1; then
    ruby -rjson -ryaml -e 'print YAML.dump(JSON.parse(STDIN.read))'
    return
  fi
  cat
}

# Helm fullname for a release, using optional values JSON on stdin-style global V1_JSON
# only for the *source* release (v1 name/fullname overrides).
src_fullname_of() {
  local release=$1
  local fo no
  fo=$(printf '%s' "$V1_JSON" | jq -r '.fullnameOverride // empty')
  no=$(printf '%s' "$V1_JSON" | jq -r '.nameOverride // empty')
  if [ -n "$fo" ]; then
    printf '%s\n' "$fo"
    return
  fi
  local name=${no:-langfuse}
  case "$release" in
    *"$name"*) printf '%s\n' "$release" ;;
    *) printf '%s-%s\n' "$release" "$name" ;;
  esac
}

# Sibling v2 chart has no fullnameOverride; default chart name is langfuse.
tgt_fullname_of() {
  local release=$1
  case "$release" in
    *langfuse*) printf '%s\n' "$release" ;;
    *) printf '%s-langfuse\n' "$release" ;;
  esac
}

secret_data() {
  local ns=$1 name=$2 key=$3
  kx -n "$ns" get secret "$name" -o "jsonpath={.data.$key}" | base64 -d
}

wait_sts() {
  local name=$1
  log "waiting for StatefulSet/$name"
  kx -n "$NAMESPACE" rollout status "sts/$name" --timeout=600s
}

wait_deploy() {
  local name=$1
  log "waiting for Deployment/$name"
  kx -n "$NAMESPACE" rollout status "deploy/$name" --timeout=600s
}

semver_ge() {
  python3 - "$1" "$2" <<'PY'
import sys
def parse(v):
    v = v.split("-")[0].split("+")[0]
    parts = []
    for p in v.split("."):
        try:
            parts.append(int(p))
        except ValueError:
            parts.append(0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])
sys.exit(0 if parse(sys.argv[1]) >= parse(sys.argv[2]) else 1)
PY
}

normalize_tag() {
  local t=$1
  t=${t#v}
  printf '%s\n' "$t"
}

fail_or_force() {
  if [ "$FORCE" -eq 1 ]; then
    warn "$* (--force: continuing)"
    return 0
  fi
  die "$* (pass --force to continue)"
}

cleanup() {
  if [ -n "$MC_POD" ] && [ "$DRY_RUN" -eq 0 ]; then
    kx -n "$NAMESPACE" delete pod "$MC_POD" --wait=false >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

helm_apply() {
  local release=$1
  shift
  if [ -d "$CHART" ]; then
    hx dependency update "$CHART" >/dev/null
    hx upgrade --install "$release" "$CHART" -n "$NAMESPACE" "$@"
  else
    hx upgrade --install "$release" "$CHART" --version "$CHART_VERSION" -n "$NAMESPACE" "$@"
  fi
}

# --- args -------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    -f|--values) VALUES_FILE=$2; shift 2 ;;
    -n|--namespace) NAMESPACE=$2; shift 2 ;;
    --source-release) SOURCE_RELEASE=$2; shift 2 ;;
    --target-release|--stores-release) TARGET_RELEASE=$2; shift 2 ;;
    -o|--output-values) OUTPUT_VALUES=$2; shift 2 ;;
    --output-cutover-values|--output-app-values) OUTPUT_CUTOVER_VALUES=$2; shift 2 ;;
    --extra-values) EXTRA_VALUES+=("$2"); shift 2 ;;
    --chart) CHART=$2; shift 2 ;;
    --chart-version) CHART_VERSION=$2; shift 2 ;;
    --context) KCTX=$2; shift 2 ;;
    -y|--yes) YES=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --skip-prereqs) SKIP_PREREQS=1; shift ;;
    --worker-drain-seconds) WORKER_DRAIN_SECONDS=$2; shift 2 ;;
    --image-tag) IMAGE_TAG=$2; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[ -n "$VALUES_FILE" ] || { usage >&2; die "--values is required"; }
[ -f "$VALUES_FILE" ] || die "values file not found: $VALUES_FILE"
OUTPUT_VALUES=${OUTPUT_VALUES:-$PWD/v2-values.generated.yaml}
OUTPUT_CUTOVER_VALUES=${OUTPUT_CUTOVER_VALUES:-$PWD/v2-cutover-values.generated.yaml}

KUBECTL=${KUBECTL:-kubectl}
HELM=${HELM:-helm}

# --- 0. CLI preflight -------------------------------------------------------
log "checking required CLI tools"
need_cmd "$KUBECTL"
need_cmd "$HELM"
need_cmd jq
need_cmd python3
need_cmd base64
if [ ${#NEED_CMDS[@]} -gt 0 ]; then
  die "missing required tools: ${NEED_CMDS[*]}"
fi
"$KUBECTL" version --client >/dev/null
"$HELM" version >/dev/null
jq --version >/dev/null
python3 --version >/dev/null
HELM_VER=$("$HELM" version --template '{{.Version}}' 2>/dev/null || true)
HELM_VER=${HELM_VER#v}
[ -n "$HELM_VER" ] || die "could not read helm version (need Helm >= 3.17)"
semver_ge "$HELM_VER" "3.17.0" || die "Helm $HELM_VER is too old; the v2 chart requires Helm >= 3.17.0"
yaml_to_json "$VALUES_FILE" >/dev/null
[ -x "$VALUES_MIGRATE" ] || chmod +x "$VALUES_MIGRATE"
[ -x "$CH_SYNC" ] || chmod +x "$CH_SYNC"
[ -f "$VALUES_MIGRATE" ] || die "missing $VALUES_MIGRATE"
[ -f "$CH_SYNC" ] || die "missing $CH_SYNC"

if [ -z "$CHART" ]; then
  if [ -f "$REPO_ROOT/charts/langfuse/Chart.yaml" ]; then
    CHART="$REPO_ROOT/charts/langfuse"
  else
    CHART="oci://ghcr.io/langfuse/langfuse-k8s/charts/langfuse"
  fi
fi

V1_JSON=$(yaml_to_json "$VALUES_FILE")
PLAN_JSON=$(printf '%s' "$V1_JSON" | python3 "$VALUES_MIGRATE" --plan --input -)
PG_ON=0; CH_ON=0; REDIS_ON=0; S3_ON=0; INGRESS_VALUES=0
printf '%s' "$PLAN_JSON" | jq -e '.postgresql == true' >/dev/null && PG_ON=1
printf '%s' "$PLAN_JSON" | jq -e '.clickhouse == true' >/dev/null && CH_ON=1
printf '%s' "$PLAN_JSON" | jq -e '.redis == true' >/dev/null && REDIS_ON=1
printf '%s' "$PLAN_JSON" | jq -e '.s3 == true' >/dev/null && S3_ON=1
printf '%s' "$PLAN_JSON" | jq -e '.ingress == true' >/dev/null && INGRESS_VALUES=1

NEED_STORES=0
[ "$PG_ON" -eq 1 ] || [ "$CH_ON" -eq 1 ] || [ "$S3_ON" -eq 1 ] || [ "$REDIS_ON" -eq 1 ] && NEED_STORES=1

# --- 1. Cluster / release detection -----------------------------------------
log "checking kube-context and Langfuse v1 release"
CTX_NAME=$(kx config current-context)
log "kube-context: $CTX_NAME"
kx get ns "$NAMESPACE" >/dev/null || die "namespace '$NAMESPACE' not found in context $CTX_NAME"

RELEASES_JSON=$(hx list -n "$NAMESPACE" -o json)
if [ -z "$SOURCE_RELEASE" ]; then
  SOURCE_RELEASE=$(printf '%s' "$RELEASES_JSON" | jq -r '
    [.[] | select((.chart | test("langfuse")) and (.chart | test("langfuse-2") | not))]
    | if length == 1 then .[0].name
      elif length == 0 then empty
      else empty end')
  if [ -z "$SOURCE_RELEASE" ]; then
    CANDIDATES=$(printf '%s' "$RELEASES_JSON" | jq -r '.[] | select(.chart | test("langfuse")) | "\(.name)\t\(.chart)\t\(.app_version)"')
    [ -n "$CANDIDATES" ] || die "no Langfuse Helm release found in namespace $NAMESPACE (context $CTX_NAME). Pass --source-release."
    die "could not uniquely identify the v1 release. Candidates:\n$CANDIDATES\nPass --source-release."
  fi
fi
hx status "$SOURCE_RELEASE" -n "$NAMESPACE" >/dev/null \
  || die "Helm release '$SOURCE_RELEASE' not found in $NAMESPACE"

SRC_META=$(hx list -n "$NAMESPACE" -o json | jq -r --arg n "$SOURCE_RELEASE" '.[] | select(.name==$n)')
SRC_CHART=$(printf '%s' "$SRC_META" | jq -r '.chart')
SRC_APP=$(printf '%s' "$SRC_META" | jq -r '.app_version')
log "source release: $SOURCE_RELEASE  chart=$SRC_CHART  appVersion=$SRC_APP"

case "$SRC_CHART" in
  langfuse-2*|langfuse-2.*) die "release $SOURCE_RELEASE already looks like chart v2 ($SRC_CHART)" ;;
esac

if [ -n "$SRC_APP" ] && [ "$SRC_APP" != "null" ]; then
  semver_ge "$SRC_APP" "3.224.1" || die "source appVersion $SRC_APP is below the minimum supported v3.224.1"
fi

VALUES_TAG=$(printf '%s' "$V1_JSON" | jq -r '.langfuse.web.image.tag // .langfuse.image.tag // empty')
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG=${VALUES_TAG:-$SRC_APP}
fi
[ -n "$IMAGE_TAG" ] && [ "$IMAGE_TAG" != "null" ] || die "could not determine Langfuse image tag. Set langfuse.image.tag in the values file or pass --image-tag (must match the running v1 app)."
if [ -n "$VALUES_TAG" ] && [ "$(normalize_tag "$VALUES_TAG")" != "$(normalize_tag "$IMAGE_TAG")" ]; then
  die "values langfuse.image.tag ($VALUES_TAG) does not match --image-tag ($IMAGE_TAG)"
fi
if [ -n "$SRC_APP" ] && [ "$SRC_APP" != "null" ] && [ "$(normalize_tag "$SRC_APP")" != "$(normalize_tag "$IMAGE_TAG")" ]; then
  # Expected whenever v1 pinned an image tag newer than its chart appVersion;
  # the VALUES_TAG consistency check above already guards real mismatches.
  warn "Helm appVersion $SRC_APP differs from image tag $IMAGE_TAG; continuing with $IMAGE_TAG (the running v1 version wins)"
fi
log "pinning langfuse.image.tag=$IMAGE_TAG so v1 and v2 stay on the same application version"

TARGET_RELEASE=${TARGET_RELEASE:-${SOURCE_RELEASE}-v2}
SRC_FULLNAME=$(src_fullname_of "$SOURCE_RELEASE")
TGT_FULLNAME=$(tgt_fullname_of "$TARGET_RELEASE")
V2_WEB="${TGT_FULLNAME}-web"
V2_WORKER="${TGT_FULLNAME}-worker"
V1_INGRESS="$SRC_FULLNAME"

V1_PG_DB=$(printf '%s' "$V1_JSON" | jq -r '.postgresql.auth.database // "postgres_langfuse"')
V1_PG_SECRET=$(printf '%s' "$V1_JSON" | jq -r '.postgresql.auth.existingSecret // empty')
V1_PG_SECRET=${V1_PG_SECRET:-${SRC_FULLNAME}-postgresql}
V1_PG_PW_KEY=$(printf '%s' "$V1_JSON" | jq -r '.postgresql.auth.secretKeys.adminPasswordKey // .postgresql.auth.secretKeys.userPasswordKey // "postgres-password"')
V1_CH_SECRET=$(printf '%s' "$V1_JSON" | jq -r '.clickhouse.auth.existingSecret // empty')
V1_CH_SECRET=${V1_CH_SECRET:-${SRC_FULLNAME}-clickhouse}
V1_CH_PW_KEY=$(printf '%s' "$V1_JSON" | jq -r '.clickhouse.auth.existingSecretKey // "admin-password"')
V1_S3_SECRET=$(printf '%s' "$V1_JSON" | jq -r '.s3.auth.existingSecret // empty')
V1_S3_SECRET=${V1_S3_SECRET:-${SRC_FULLNAME}-s3}
V1_S3_USER_KEY=$(printf '%s' "$V1_JSON" | jq -r '.s3.auth.rootUserSecretKey // "root-user"')
V1_S3_PW_KEY=$(printf '%s' "$V1_JSON" | jq -r '.s3.auth.rootPasswordSecretKey // "root-password"')
V1_REDIS_SECRET=$(printf '%s' "$V1_JSON" | jq -r '.redis.auth.existingSecret // empty')
V1_REDIS_SECRET=${V1_REDIS_SECRET:-${SRC_FULLNAME}-redis}
V1_REDIS_PW_KEY=$(printf '%s' "$V1_JSON" | jq -r '.redis.auth.existingSecretPasswordKey // "redis-password"')
V2_PG_SECRET="${TGT_FULLNAME}-postgresql-auth"
V2_CH_SECRET="${TGT_FULLNAME}-clickhouse-auth"
V2_S3_SECRET="${TGT_FULLNAME}-s3-auth"

v1_pg_super() {
  local pw
  pw=$(secret_data "$NAMESPACE" "$V1_PG_SECRET" "$V1_PG_PW_KEY")
  kx -n "$NAMESPACE" exec "${SRC_FULLNAME}-postgresql-0" -- env PGPASSWORD="$pw" psql -U postgres "$@"
}

# Chart Ingress is swapped automatically when values enable it, or when the
# existing Ingress is owned by the v1 Helm release. Anything else is treated
# as externally managed — the script asks you to retarget it.
INGRESS_ON=$INGRESS_VALUES
if kx -n "$NAMESPACE" get ingress "$V1_INGRESS" >/dev/null 2>&1; then
  ING_OWNER=$(kx -n "$NAMESPACE" get ingress "$V1_INGRESS" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' 2>/dev/null || true)
  if [ "$ING_OWNER" = "$SOURCE_RELEASE" ]; then
    INGRESS_ON=1
  elif [ "$INGRESS_ON" -eq 0 ]; then
    warn "Ingress/$V1_INGRESS exists but is not owned by release $SOURCE_RELEASE — treating it as externally managed; you will need to retarget it at $V2_WEB"
  fi
fi

V1_MARKERS=0
EXPECTED_MARKERS=0
if [ "$CH_ON" -eq 1 ]; then
  EXPECTED_MARKERS=$((EXPECTED_MARKERS + 1))
  if kx -n "$NAMESPACE" get sts "${SRC_FULLNAME}-clickhouse-shard0" >/dev/null 2>&1; then
    V1_MARKERS=$((V1_MARKERS + 1))
  else
    warn "clickhouse.deploy is true but StatefulSet ${SRC_FULLNAME}-clickhouse-shard0 was not found"
  fi
fi
if [ "$PG_ON" -eq 1 ]; then
  EXPECTED_MARKERS=$((EXPECTED_MARKERS + 1))
  if kx -n "$NAMESPACE" get pvc "data-${SRC_FULLNAME}-postgresql-0" >/dev/null 2>&1; then
    V1_MARKERS=$((V1_MARKERS + 1))
  else
    warn "postgresql.deploy is true but PVC data-${SRC_FULLNAME}-postgresql-0 was not found"
  fi
fi
if [ "$S3_ON" -eq 1 ]; then
  EXPECTED_MARKERS=$((EXPECTED_MARKERS + 1))
  if kx -n "$NAMESPACE" get deploy "${SRC_FULLNAME}-s3" >/dev/null 2>&1; then
    V1_MARKERS=$((V1_MARKERS + 1))
  else
    warn "s3.deploy is true but Deployment ${SRC_FULLNAME}-s3 was not found"
  fi
fi
if [ "$EXPECTED_MARKERS" -eq 0 ]; then
  log "all data stores are external (deploy: false) — will helm-upgrade $SOURCE_RELEASE in place"
elif [ "$V1_MARKERS" -eq 0 ]; then
  die "no v1 Bitnami resources found for bundled stores on release $SOURCE_RELEASE (looked for ClickHouse STS ${SRC_FULLNAME}-clickhouse-shard0, PVC data-${SRC_FULLNAME}-postgresql-0, and/or Deployment ${SRC_FULLNAME}-s3). Wrong context or already migrated?"
fi

if [ "$NEED_STORES" -eq 1 ] && hx status "$TARGET_RELEASE" -n "$NAMESPACE" >/dev/null 2>&1; then
  warn "target release $TARGET_RELEASE already exists — later steps will reuse it"
fi

# --- 2. Generate v2 values --------------------------------------------------
write_values() {
  local mode=$1 dest=$2 header=$3
  local extra=()
  if [ "$mode" != "inplace" ]; then
    extra+=(--target-fullname "$TGT_FULLNAME")
  fi
  # Feed the JSON converted by yaml_to_json (like the --plan call) so the
  # yq/PyYAML/Ruby fallback chain holds — migrate-values.py itself can only
  # parse YAML when PyYAML is installed.
  printf '%s' "$V1_JSON" | python3 "$VALUES_MIGRATE" --mode "$mode" --input - --output "$dest.tmp" --image-tag "$IMAGE_TAG" "${extra[@]+"${extra[@]}"}"
  if [ "$(head -c 1 "$dest.tmp")" = "{" ]; then
    json_to_yaml < "$dest.tmp" > "$dest.body"
    rm -f "$dest.tmp"
  else
    mv "$dest.tmp" "$dest.body"
  fi
  {
    printf '%s\n' "$header"
    cat "$dest.body"
  } > "$dest"
  rm -f "$dest.body"
  log "wrote $dest"
}

if [ "$NEED_STORES" -eq 1 ]; then
  log "generating sibling v2 values from $VALUES_FILE"
  write_values sibling "$OUTPUT_VALUES" "$(cat <<EOF
# Generated by migrate-v1-to-v2.sh (sibling) from $VALUES_FILE
# New v2 release next to v1. Ingress is off so v1 keeps the domain.
#   helm install $TARGET_RELEASE ... -n $NAMESPACE -f $OUTPUT_VALUES

EOF
)"
  if [ "$INGRESS_ON" -eq 1 ]; then
    write_values cutover "$OUTPUT_CUTOVER_VALUES" "$(cat <<EOF
# Generated by migrate-v1-to-v2.sh (cutover) from $VALUES_FILE
# Enable after deleting Ingress/$V1_INGRESS so the same hosts land on $V2_WEB.
#   helm upgrade $TARGET_RELEASE ... -n $NAMESPACE -f $OUTPUT_CUTOVER_VALUES

EOF
)"
  fi
else
  log "generating in-place v2 values from $VALUES_FILE"
  write_values inplace "$OUTPUT_VALUES" "$(cat <<EOF
# Generated by migrate-v1-to-v2.sh (inplace) from $VALUES_FILE
# All stores are external — helm-upgrade the original release.
#   helm upgrade $SOURCE_RELEASE ... -n $NAMESPACE -f $OUTPUT_VALUES

EOF
)"
fi

helm_extra=()
for extra in "${EXTRA_VALUES[@]+"${EXTRA_VALUES[@]}"}"; do
  helm_extra+=(-f "$extra")
done

cat <<EOF

Migration plan (from values; deploy defaults to true when unset)
  namespace:        $NAMESPACE
  context:          $CTX_NAME
  source release:   $SOURCE_RELEASE  (fullname $SRC_FULLNAME)
  target release:   $([ "$NEED_STORES" -eq 1 ] && echo "$TARGET_RELEASE  (fullname $TGT_FULLNAME)" || echo "(in-place upgrade of $SOURCE_RELEASE)")
  postgresql:       $([ "$PG_ON" -eq 1 ] && echo "migrate (logical replication)" || echo "skip (external / deploy=false)")
  clickhouse:       $([ "$CH_ON" -eq 1 ] && echo "migrate (remote() watermark sync)" || echo "skip (external / deploy=false)")
  object storage:   $([ "$S3_ON" -eq 1 ] && echo "migrate (mc mirror MinIO → SeaweedFS)" || echo "skip (external / deploy=false)")
  redis/valkey:     $([ "$REDIS_ON" -eq 1 ] && echo "redeploy empty (ephemeral; no data copy)" || echo "skip (external / deploy=false)")
  traffic:          $([ "$NEED_STORES" -eq 0 ] && echo "in-place (Service / Ingress unchanged)" || { [ "$INGRESS_ON" -eq 1 ] && echo "Ingress swap (delete $V1_INGRESS, then create $TGT_FULLNAME)" || echo "manual (point traffic at Service/$V2_WEB)"; })
  image tag:        $IMAGE_TAG
  values:           $OUTPUT_VALUES
$([ "$NEED_STORES" -eq 1 ] && [ "$INGRESS_ON" -eq 1 ] && echo "  cutover values:   $OUTPUT_CUTOVER_VALUES")

EOF

if [ "$DRY_RUN" -eq 1 ]; then
  log "dry-run: stopping before any cluster changes"
  exit 0
fi

if [ "$NEED_STORES" -eq 0 ]; then
  confirm "Review $OUTPUT_VALUES, then helm-upgrade $SOURCE_RELEASE in place to chart v2?"
else
  confirm "Review generated values, then start the cluster migration (prereqs + sibling v2 + data copy + traffic shift)?"
fi

# --- 3. Cluster prereqs -----------------------------------------------------
ensure_crds() {
  local crd=$1
  kx get crd "$crd" >/dev/null 2>&1
}

if [ "$SKIP_PREREQS" -eq 0 ] && [ "$NEED_STORES" -eq 1 ]; then
  if ! ensure_crds certificates.cert-manager.io; then
    confirm "Install cert-manager $CERT_MANAGER_VERSION into namespace cert-manager?"
    hx install cert-manager oci://quay.io/jetstack/charts/cert-manager \
      --version "$CERT_MANAGER_VERSION" \
      --namespace cert-manager --create-namespace \
      --set crds.enabled=true
    kx wait --for=condition=Established crd/certificates.cert-manager.io crd/issuers.cert-manager.io --timeout=180s
  else
    log "cert-manager CRDs already present"
  fi

  if [ "$CH_ON" -eq 1 ] && ! ensure_crds clickhouseclusters.clickhouse.com; then
    confirm "Install ClickHouse operator $CLICKHOUSE_OPERATOR_VERSION?"
    hx install clickhouse-operator oci://ghcr.io/clickhouse/clickhouse-operator-helm \
      --version "$CLICKHOUSE_OPERATOR_VERSION" \
      --namespace clickhouse-operator --create-namespace
    kx wait --for=condition=Established \
      crd/clickhouseclusters.clickhouse.com \
      crd/keeperclusters.clickhouse.com --timeout=180s
  elif [ "$CH_ON" -eq 1 ]; then
    log "ClickHouse operator CRDs already present"
  fi
elif [ "$SKIP_PREREQS" -eq 0 ]; then
  log "all stores are external — skipping cert-manager / ClickHouse operator install"
fi

# Protect the shared app Secret if Helm still owns it
APP_SECRET=$(printf '%s' "$V1_JSON" | jq -r '.langfuse.salt.secretKeyRef.name // .langfuse.encryptionKey.secretKeyRef.name // empty')
if [ -n "$APP_SECRET" ]; then
  if kx -n "$NAMESPACE" get secret "$APP_SECRET" >/dev/null 2>&1; then
    log "annotating Secret/$APP_SECRET with helm.sh/resource-policy=keep"
    kx -n "$NAMESPACE" annotate secret "$APP_SECRET" helm.sh/resource-policy=keep --overwrite
  fi
fi

# --- 4a. In-place path (all stores external) --------------------------------
if [ "$NEED_STORES" -eq 0 ]; then
  helm_apply "$SOURCE_RELEASE" -f "$OUTPUT_VALUES" "${helm_extra[@]+"${helm_extra[@]}"}"
  wait_deploy "${SRC_FULLNAME}-web"
  READY=$(kx -n "$NAMESPACE" run "${SRC_FULLNAME}-ready-check" --rm -i --restart=Never --image=curlimages/curl:8.11.1 -- \
    curl -sf "http://${SRC_FULLNAME}-web.${NAMESPACE}.svc.cluster.local:3000/api/public/ready" || true)
  log "v2 readiness: ${READY:-<empty>}"
  [ -n "$READY" ] || fail_or_force "in-place upgrade readiness check failed"
  cat <<EOF

In-place upgrade finished. Release $SOURCE_RELEASE is chart v2.
Service ${SRC_FULLNAME}-web and Ingress/$V1_INGRESS (if any) are unchanged.

Generated values: $OUTPUT_VALUES
EOF
  exit 0
fi

# --- 4b. Enable logical replication on v1 Postgres --------------------------
if [ "$PG_ON" -eq 1 ]; then
  WAL=$(v1_pg_super -d postgres -tAc "SHOW wal_level;" | tr -d '[:space:]' || true)
  if [ "$WAL" != "logical" ]; then
    confirm "Enable wal_level=logical on v1 Postgres (ALTER SYSTEM + StatefulSet restart)?"
    v1_pg_super -d postgres -c "ALTER SYSTEM SET wal_level = 'logical'; ALTER SYSTEM SET max_wal_senders = 10; ALTER SYSTEM SET max_replication_slots = 10;"
    kx -n "$NAMESPACE" rollout restart "sts/${SRC_FULLNAME}-postgresql"
    wait_sts "${SRC_FULLNAME}-postgresql"
    WAL=$(v1_pg_super -d postgres -tAc "SHOW wal_level;" | tr -d '[:space:]')
    [ "$WAL" = "logical" ] || die "wal_level is '$WAL', expected logical"
  else
    log "v1 Postgres already has wal_level=logical"
  fi
fi

# --- 5. Stand up sibling v2 -------------------------------------------------
require_sibling_store() {
  local kind=$1 name=$2
  kx -n "$NAMESPACE" get "$kind" "$name" >/dev/null 2>&1 \
    || die "resume failed: $kind/$name is missing on $TARGET_RELEASE. helm uninstall $TARGET_RELEASE -n $NAMESPACE and re-run."
}

if ! hx status "$TARGET_RELEASE" -n "$NAMESPACE" >/dev/null 2>&1; then
  confirm "Install v2 release $TARGET_RELEASE alongside $SOURCE_RELEASE (no downtime; ingress stays on v1)?"
  helm_apply "$TARGET_RELEASE" -f "$OUTPUT_VALUES" "${helm_extra[@]+"${helm_extra[@]}"}"
else
  RESUME_TARGET=1
  confirm "Resume against existing release $TARGET_RELEASE? Stores must already match the generated overlay."
  [ "$PG_ON" -eq 1 ] && require_sibling_store sts "${TGT_FULLNAME}-postgresql"
  [ "$S3_ON" -eq 1 ] && require_sibling_store deploy "${TGT_FULLNAME}-s3-all-in-one"
  [ "$CH_ON" -eq 1 ] && require_sibling_store pod "${TGT_FULLNAME}-clickhouse-0-0-0"
  require_sibling_store deploy "$V2_WEB"
fi

[ "$PG_ON" -eq 1 ] && wait_sts "${TGT_FULLNAME}-postgresql"
[ "$REDIS_ON" -eq 1 ] && {
  if kx -n "$NAMESPACE" get sts "${TGT_FULLNAME}-redis" >/dev/null 2>&1; then
    wait_sts "${TGT_FULLNAME}-redis"
  elif kx -n "$NAMESPACE" get deploy "${TGT_FULLNAME}-redis" >/dev/null 2>&1; then
    wait_deploy "${TGT_FULLNAME}-redis"
  fi
}
[ "$S3_ON" -eq 1 ] && wait_deploy "${TGT_FULLNAME}-s3-all-in-one"
if [ "$CH_ON" -eq 1 ]; then
  log "waiting for ClickHouse pod ${TGT_FULLNAME}-clickhouse-0-0-0"
  # The operator only creates the server pod after the Keeper quorum is up;
  # `kubectl wait` fails immediately on a not-yet-created pod, so poll for
  # existence first (up to 5 minutes).
  for _ in $(seq 1 60); do kx -n "$NAMESPACE" get pod "${TGT_FULLNAME}-clickhouse-0-0-0" >/dev/null 2>&1 && break; sleep 5; done
  kx -n "$NAMESPACE" wait pod "${TGT_FULLNAME}-clickhouse-0-0-0" --for=condition=Ready --timeout=600s
fi
V2_WEB_REPLICAS=$(kx -n "$NAMESPACE" get deploy "$V2_WEB" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
if [ "${V2_WEB_REPLICAS:-0}" != "0" ]; then
  wait_deploy "$V2_WEB"
  log "scaling $V2_WEB / $V2_WORKER to 0 after schema init (v1 stays the writer)"
  kx -n "$NAMESPACE" scale deploy/"$V2_WEB" --replicas=0
  kx -n "$NAMESPACE" scale deploy/"$V2_WORKER" --replicas=0 >/dev/null 2>&1 || true
else
  log "$V2_WEB is already at 0 replicas — assuming schema init completed on a previous run"
fi

# --- 6. Online sync ---------------------------------------------------------
V1_S3_SVC="${SRC_FULLNAME}-s3.${NAMESPACE}.svc.cluster.local:9000"
V2_S3_SVC="${TGT_FULLNAME}-s3-all-in-one.${NAMESPACE}.svc.cluster.local:8333"
S3_BUCKET=$(printf '%s' "$V1_JSON" | jq -r '(.s3.bucket | select(type=="string" and length>0)) // "langfuse"')
MC_POD="${TGT_FULLNAME}-migrate-mc"

pg_exec_v1() {
  v1_pg_super -d "$V1_PG_DB" "$@"
}
V2_PG_DB=langfuse
if [ "$PG_ON" -eq 1 ]; then
  V2_PG_DB=$(secret_data "$NAMESPACE" "$V2_PG_SECRET" POSTGRES_DB 2>/dev/null || true)
  V2_PG_DB=${V2_PG_DB:-langfuse}
fi

pg_exec_v2() {
  local su_pw=$1; shift
  kx -n "$NAMESPACE" exec -i "${TGT_FULLNAME}-postgresql-0" -- env PGPASSWORD="$su_pw" psql -U postgres -d "$V2_PG_DB" "$@"
}

if [ "$PG_ON" -eq 1 ]; then
  confirm "Start PostgreSQL logical replication (publication on v1, subscription on v2)?"
  SU_PW=$(secret_data "$NAMESPACE" "$V2_PG_SECRET" POSTGRES_PASSWORD)
  V1_PW=$(secret_data "$NAMESPACE" "$V1_PG_SECRET" "$V1_PG_PW_KEY")
  if [ "$(pg_exec_v1 -tAc "SELECT 1 FROM pg_publication WHERE pubname='lf_pub';" | tr -d '[:space:]')" = "1" ]; then
    log "publication lf_pub already exists"
  else
    pg_exec_v1 -c "CREATE PUBLICATION lf_pub FOR ALL TABLES;"
  fi
  if [ "$(pg_exec_v2 "$SU_PW" -tAc "SELECT 1 FROM pg_subscription WHERE subname='lf_sub';" | tr -d '[:space:]')" = "1" ]; then
    log "subscription lf_sub already exists"
  else
    TRUNCATE_SQL=$(pg_exec_v2 "$SU_PW" -tAc \
      "SELECT 'TRUNCATE TABLE '||string_agg(format('%I.%I',schemaname,tablename),', ')||' CASCADE;' FROM pg_tables WHERE schemaname='public';")
    if [ -n "$TRUNCATE_SQL" ]; then
      pg_exec_v2 "$SU_PW" -c "$TRUNCATE_SQL"
    fi
    # Password goes on stdin so it is not in the kubectl/psql argv.
    printf '%s\n' \
      "CREATE SUBSCRIPTION lf_sub CONNECTION 'host=${SRC_FULLNAME}-postgresql port=5432 dbname=${V1_PG_DB} user=postgres password=${V1_PW}' PUBLICATION lf_pub;" \
      | pg_exec_v2 "$SU_PW"
  fi
  log "watching replication lag (Ctrl-C only stops the watch; re-run the script to continue)"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    pg_exec_v1 -c "SELECT application_name, state, pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes FROM pg_stat_replication;" || true
    sleep 3
  done
fi

ensure_mc_pod() {
  if kx -n "$NAMESPACE" get pod "$MC_POD" >/dev/null 2>&1; then
    return
  fi
  kx -n "$NAMESPACE" run "$MC_POD" --restart=Never --image="$MC_IMAGE" --command -- sleep 86400
  kx -n "$NAMESPACE" wait pod "$MC_POD" --for=condition=Ready --timeout=180s
}

mc_mirror() {
  local watch=$1
  local v1_key v1_secret v2_key v2_secret extra
  v1_key=$(secret_data "$NAMESPACE" "$V1_S3_SECRET" "$V1_S3_USER_KEY")
  v1_secret=$(secret_data "$NAMESPACE" "$V1_S3_SECRET" "$V1_S3_PW_KEY")
  v2_key=$(secret_data "$NAMESPACE" "$V2_S3_SECRET" accessKey)
  v2_secret=$(secret_data "$NAMESPACE" "$V2_S3_SECRET" secretKey)
  extra=""
  [ "$watch" = "watch" ] && extra="--watch"
  ensure_mc_pod
  kx -n "$NAMESPACE" exec "$MC_POD" -- mc alias set v1 "http://${V1_S3_SVC}" "$v1_key" "$v1_secret"
  kx -n "$NAMESPACE" exec "$MC_POD" -- mc alias set v2 "http://${V2_S3_SVC}" "$v2_key" "$v2_secret"
  kx -n "$NAMESPACE" exec "$MC_POD" -- mc mb --ignore-existing "v2/${S3_BUCKET}"
  log "mc mirror v1/${S3_BUCKET} → v2/${S3_BUCKET} ${extra}"
  kx -n "$NAMESPACE" exec "$MC_POD" -- mc mirror --overwrite $extra "v1/${S3_BUCKET}" "v2/${S3_BUCKET}"
}

if [ "$S3_ON" -eq 1 ]; then
  confirm "Mirror object storage MinIO → SeaweedFS (online pass)?"
  mc_mirror ""
fi

run_ch_sync() {
  local extra=${1:-}
  TARGET_NS="$NAMESPACE" SOURCE_NS="$NAMESPACE" \
    TARGET_POD="${TGT_FULLNAME}-clickhouse-0-0-0" TARGET_SECRET="$V2_CH_SECRET" \
    SOURCE_HOST="${SRC_FULLNAME}-clickhouse.${NAMESPACE}.svc.cluster.local:9000" \
    SOURCE_SECRET="$V1_CH_SECRET" SOURCE_SECRET_KEY="$V1_CH_PW_KEY" \
    KUBECTL="$KUBECTL" KCTX="$KCTX" \
    "$CH_SYNC" $extra
}

if [ "$CH_ON" -eq 1 ]; then
  confirm "Run ClickHouse incremental sync (remote() watermark pass)?"
  run_ch_sync
fi

if [ "$YES" -eq 0 ] && { [ "$CH_ON" -eq 1 ] || [ "$S3_ON" -eq 1 ]; }; then
  while true; do
    printf 'Run another online sync pass (ClickHouse / object storage) before freeze? [y/N] '
    read -r again
    case "$again" in
      y|Y|yes|YES)
        [ "$S3_ON" -eq 1 ] && mc_mirror ""
        [ "$CH_ON" -eq 1 ] && run_ch_sync
        ;;
      *) break ;;
    esac
  done
fi

v1_redis_pod() {
  local cand
  for cand in \
    "${SRC_FULLNAME}-redis-primary-0" \
    "${SRC_FULLNAME}-valkey-primary-0" \
    "${SRC_FULLNAME}-redis-master-0" \
    "${SRC_FULLNAME}-redis-0"
  do
    if kx -n "$NAMESPACE" get pod "$cand" >/dev/null 2>&1; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

v1_queue_depth() {
  local pod=$1 pw=$2
  kx -n "$NAMESPACE" exec "$pod" -- sh -c "
    export REDISCLI_AUTH=$(printf '%q' "$pw")
    depth=0
    for k in \$(redis-cli --no-auth-warning --scan --pattern 'bull:*:wait' ; redis-cli --no-auth-warning --scan --pattern 'bull:*:active'); do
      n=\$(redis-cli --no-auth-warning LLEN \"\$k\" 2>/dev/null || echo 0)
      depth=\$((depth + \${n:-0}))
    done
    for k in \$(redis-cli --no-auth-warning --scan --pattern 'bull:*:delayed'); do
      n=\$(redis-cli --no-auth-warning ZCARD \"\$k\" 2>/dev/null || echo 0)
      depth=\$((depth + \${n:-0}))
    done
    echo \$depth
  " | tr -d '[:space:]'
}

drain_v1_queues() {
  local pod pw depth i
  if [ "$REDIS_ON" -ne 1 ]; then
    if [ "$YES" -eq 1 ]; then
      log "v1 Redis is external — waiting ${WORKER_DRAIN_SECONDS}s for the worker to drain"
      sleep "$WORKER_DRAIN_SECONDS"
    else
      printf 'Scale-down of %s-web is done. Wait until the v1 worker is idle, then press Enter.\n' "$SRC_FULLNAME"
      read -r _
    fi
    return 0
  fi
  pod=$(v1_redis_pod) || {
    warn "could not find a v1 Redis pod; falling back to a ${WORKER_DRAIN_SECONDS}s wait"
    sleep "$WORKER_DRAIN_SECONDS"
    return 0
  }
  pw=$(secret_data "$NAMESPACE" "$V1_REDIS_SECRET" "$V1_REDIS_PW_KEY" 2>/dev/null || true)
  # Bitnami valkey (the v1 redis alias) stores the password under valkey-password
  [ -n "$pw" ] || pw=$(secret_data "$NAMESPACE" "$V1_REDIS_SECRET" valkey-password 2>/dev/null || true)
  [ -n "$pw" ] || pw=$(secret_data "$NAMESPACE" "$V1_REDIS_SECRET" password 2>/dev/null || true)
  if [ -z "$pw" ]; then
    warn "could not read v1 Redis password; falling back to a ${WORKER_DRAIN_SECONDS}s wait"
    sleep "$WORKER_DRAIN_SECONDS"
    return 0
  fi
  log "waiting up to ${WORKER_DRAIN_SECONDS}s for v1 Redis BullMQ queues on $pod to drain"
  for i in $(seq 1 "$WORKER_DRAIN_SECONDS"); do
    depth=$(v1_queue_depth "$pod" "$pw" || echo 999)
    [ "${depth:-999}" = "0" ] && { log "v1 Redis queues are empty"; return 0; }
    sleep 1
  done
  fail_or_force "v1 Redis queue depth is still ${depth:-unknown} after ${WORKER_DRAIN_SECONDS}s"
}

# --- 7. Freeze & final delta ------------------------------------------------
confirm "FREEZE window: scale down v1 web (then worker) and run final deltas? This starts application downtime."

kx -n "$NAMESPACE" scale deploy/"${SRC_FULLNAME}-web" --replicas=0
drain_v1_queues
kx -n "$NAMESPACE" scale deploy/"${SRC_FULLNAME}-worker" --replicas=0

if [ "$PG_ON" -eq 1 ]; then
  log "waiting for Postgres lag_bytes=0"
  SU_PW=$(secret_data "$NAMESPACE" "$V2_PG_SECRET" POSTGRES_PASSWORD)
  for i in $(seq 1 60); do
    # Scope to the lf_sub walsender (logical replication uses the subscription
  # name as application_name) and SUM: an unscoped query returns one row per
  # walsender, and squashed multi-row output like '00' never equals '0'.
  LAG=$(pg_exec_v1 -tAc "SELECT COALESCE(SUM(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)),0) FROM pg_stat_replication WHERE application_name = 'lf_sub';" | tr -d '[:space:]' || echo 999)
    [ "${LAG:-999}" = "0" ] && break
    sleep 2
  done
  [ "${LAG:-999}" = "0" ] || fail_or_force "Postgres lag_bytes=$LAG; refusing to drop the subscription"
  pg_exec_v2 "$SU_PW" -c "DROP SUBSCRIPTION IF EXISTS lf_sub;"
fi

if [ "$S3_ON" -eq 1 ]; then
  log "final object-storage mirror"
  mc_mirror ""
fi

if [ "$CH_ON" -eq 1 ]; then
  log "final ClickHouse watermark pass"
  run_ch_sync --final
fi

# --- 8. Bring v2 writers up, then shift traffic -----------------------------
log "scaling $V2_WEB / $V2_WORKER up"
kx -n "$NAMESPACE" scale deploy/"$V2_WEB" --replicas=1
kx -n "$NAMESPACE" scale deploy/"$V2_WORKER" --replicas=1 >/dev/null 2>&1 || true
wait_deploy "$V2_WEB"

if [ "$INGRESS_ON" -eq 1 ]; then
  confirm "Shift traffic: delete Ingress/$V1_INGRESS, then create the v2 Ingress on $TARGET_RELEASE (same hosts)?"
  if kx -n "$NAMESPACE" get ingress "$V1_INGRESS" >/dev/null 2>&1; then
    kx -n "$NAMESPACE" delete ingress "$V1_INGRESS" --wait=true
  else
    warn "Ingress/$V1_INGRESS already gone"
  fi
  helm_apply "$TARGET_RELEASE" -f "$OUTPUT_CUTOVER_VALUES" "${helm_extra[@]+"${helm_extra[@]}"}"
else
  cat <<EOF

v1 did not use the chart Ingress. Point traffic at the new Service before continuing:

  Service:  $V2_WEB.$NAMESPACE.svc.cluster.local:3000
  Selector: app.kubernetes.io/instance=$TARGET_RELEASE, app.kubernetes.io/name=langfuse
  kubectl -n $NAMESPACE get svc,deploy -l app.kubernetes.io/instance=$TARGET_RELEASE

If you expose Langfuse via a LoadBalancer, NodePort, or an Ingress/HTTPRoute
managed outside this chart, retarget that at $V2_WEB now.

EOF
  confirm "Traffic is pointed at Service/$V2_WEB (or you accept downtime until it is)?"
fi

READY=$(kx -n "$NAMESPACE" run "${TGT_FULLNAME}-ready-check" --rm -i --restart=Never --image=curlimages/curl:8.11.1 -- \
  curl -sf "http://${V2_WEB}.${NAMESPACE}.svc.cluster.local:3000/api/public/ready" || true)
log "v2 readiness: ${READY:-<empty>}"
[ -n "$READY" ] || fail_or_force "v2 readiness check failed for Service/$V2_WEB"

cat <<EOF

Migration steps finished.

v2 is release $TARGET_RELEASE (Service $V2_WEB). v1 ($SOURCE_RELEASE) is scaled to 0.

Next (manual):
  1. Keep $SOURCE_RELEASE until you are confident
  2. helm uninstall $SOURCE_RELEASE -n $NAMESPACE
  3. Delete retained v1 Bitnami PVCs (data-${SRC_FULLNAME}-postgresql-0, …)

Rollback before uninstalling v1: scale v1 writers back up
  kubectl -n $NAMESPACE scale deploy/${SRC_FULLNAME}-web deploy/${SRC_FULLNAME}-worker --replicas=1
$([ "$INGRESS_ON" -eq 1 ] && echo "  (re-create Ingress/$V1_INGRESS from the v1 release if you already deleted it)")

Generated values:
  sibling: $OUTPUT_VALUES
$([ "$INGRESS_ON" -eq 1 ] && echo "  cutover: $OUTPUT_CUTOVER_VALUES")
EOF
