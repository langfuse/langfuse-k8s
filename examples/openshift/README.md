# Langfuse on OpenShift / OKD

This example deploys Langfuse on an OpenShift or OKD cluster using an
OpenShift **Route** for ingress and documents the Security Context Constraint
(SCC) adjustments required by the bundled Bitnami sub-charts.

## What is different from plain Kubernetes

| Area | Plain Kubernetes | OpenShift |
|---|---|---|
| Ingress | `Ingress` resource | `Route` resource (`route.openshift.io/v1`) |
| TLS | Cert-Manager or manual secret | Router handles TLS via cluster wildcard cert |
| Pod UIDs | Unrestricted | `restricted-v2` SCC: random UID from namespace range |
| Bitnami images | Work out of the box | Require `anyuid` SCC or external DB (see below) |

## Prerequisites

### 1. Create the OpenShift project

```bash
oc new-project langfuse
```

### 2. Find your cluster wildcard domain

```bash
oc get ingresses.config.openshift.io cluster \
  -o jsonpath='{.spec.domain}'
# e.g. apps.my-cluster.example.com
```

### 3. Create the secret

Edit `secret.yaml` — replace all `<CHANGE_ME>` placeholders — then apply:

```bash
# Generate values
SALT=$(openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -hex 32)
NEXTAUTH_SECRET=$(openssl rand -base64 32)
PG_PASSWORD=$(openssl rand -base64 24)

oc create secret generic langfuse \
  --from-literal=salt="$SALT" \
  --from-literal=encryption-key="$ENCRYPTION_KEY" \
  --from-literal=nextauth-secret="$NEXTAUTH_SECRET" \
  --from-literal=postgresql-password="$PG_PASSWORD" \
  --from-literal=redis-password="$PG_PASSWORD" \
  -n langfuse
```

### 4. Handle the Bitnami SCC requirement

The bundled **PostgreSQL** and **Valkey/Redis** images from Bitnami run as
UID `1001`. OpenShift's default `restricted-v2` SCC rejects fixed UIDs.

**Option A — Grant `anyuid` (simplest, suitable for dev clusters):**

```bash
oc adm policy add-scc-to-user anyuid \
  -z langfuse \
  -n langfuse
```

**Option B — Use an external PostgreSQL (recommended for production):**

Provision PostgreSQL via the [CrunchyData PGO operator][pgo] or any managed
service, then set in `values.yaml`:

```yaml
postgresql:
  deploy: false
  host: my-postgres-host
  auth:
    username: langfuse
    existingSecret: langfuse
    secretKeys:
      userPasswordKey: postgresql-password
```

This removes the Bitnami PostgreSQL dependency entirely and avoids the SCC
issue for the database pod.

[pgo]: https://access.crunchydata.com/documentation/postgres-operator/latest/

## Install

```bash
helm repo add langfuse https://langfuse.github.io/langfuse-k8s
helm repo update

helm install langfuse langfuse/langfuse \
  -n langfuse \
  -f values.yaml
```

## Verify

```bash
# Watch pods come up
oc get pods -n langfuse -w

# Get the auto-generated Route URL
oc get route langfuse -n langfuse -o jsonpath='{.spec.host}'
```

Open `https://<route-host>` in your browser, create an account, and generate
your API keys under **Settings → API Keys**.

## Update `NEXTAUTH_URL`

After the Route is created, update `langfuse.nextauth.url` in `values.yaml`
with the actual Route hostname and run `helm upgrade`:

```bash
helm upgrade langfuse langfuse/langfuse \
  -n langfuse \
  -f values.yaml \
  --set langfuse.nextauth.url=https://$(oc get route langfuse -n langfuse -o jsonpath='{.spec.host}')
```
