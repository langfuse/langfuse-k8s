# AI Gateway Example

This example deploys the Langfuse AI gateway next to Langfuse, on top of [`minimal-installation`](../minimal-installation/). The gateway gets its own Deployment, Service, Ingress, HPA, and PodDisruptionBudget, and calls web through web's in-cluster Service.

Requires a Langfuse release that contains the AI gateway. See the [AI gateway section](../../README.md#ai-gateway) of the chart README for the release requirements and all settings.

## Files

- `secret.yaml`: the pinned gateway keys. The HMAC service key is shared by web and the gateway. The ES256 JWT private key is used only by web, which derives the public key and key id from it.
- `values.yaml`: enables the gateway, references the keys in `secret.yaml`, and sets resources, autoscaling, and two web replicas.
- `with-nginx.yaml`: Ingresses for web and the gateway on ingress-nginx, with cert-manager certificates, streaming timeouts, and buffering turned off.
- `with-alb.yaml`: the same Ingresses on the AWS Load Balancer Controller. TLS terminates at the ALB with ACM certificates, and the gateway gets its own load balancer group for its longer idle timeout.

## Installation

1. Follow the [minimal installation](../minimal-installation/) prerequisites and apply its `secret.yaml`.

2. Generate the gateway keys, put them in `secret.yaml`, and apply it:

```bash
openssl rand -hex 32                                               # service-key
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256     # jwt-private-key
kubectl apply -f secret.yaml -n langfuse
```

   To have the chart generate the keys into `<release>-app` instead, remove `serviceKey` and `jwt` from `values.yaml`. Don't do that with `helm template`-based GitOps such as ArgoCD: the generated keys would rotate on every sync.

3. Replace the hostnames (and, for ALB, the certificate ARNs), then install with one of the ingress files:

```bash
helm install langfuse oci://ghcr.io/langfuse/langfuse-k8s/charts/langfuse \
  --namespace langfuse \
  -f ../minimal-installation/values.yaml \
  -f values.yaml \
  -f with-nginx.yaml   # or: -f with-alb.yaml
```

4. Add a DNS record for the gateway host, `gateway.langfuse.example.com` here, that points at your load balancer.

## What users see

Web shows the gateway URL in the UI and in setup snippets. The chart sets it from the first gateway ingress host, here `https://gateway.langfuse.example.com`. It uses `https` because the gateway ingress terminates TLS (nginx) or because `nextauth.url` is `https` (ALB). To expose the gateway some other way, set `langfuse.gateway.publicUrl`.
