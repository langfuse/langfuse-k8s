# macOS local values

Use [`values.yaml`](./values.yaml) to evaluate Langfuse on Apple silicon with Apple's `container` runtime. These values were tested with chart **2.2.3**, Apple `container` **1.7.1**, and Kubernetes **1.35.5**.

Follow the [macOS deployment guide](https://langfuse.com/self-hosting/deployment/macos) to create the cluster, install Local Path Provisioner, cert-manager, and the ClickHouse operator, and start the port-forwards.

After completing the cluster prerequisites, run this command from the repository root:

```bash
helm --kubeconfig "$HOME/.kube/langfuse-local" --kube-context langfuse-local \
  upgrade --install langfuse \
  oci://ghcr.io/langfuse/langfuse-k8s/charts/langfuse \
  --version 2.2.3 \
  --namespace langfuse --create-namespace \
  -f examples/macos-local/values.yaml --wait --timeout 20m
```

The values use one replica per service, keep ClickHouse Keeper enabled, and request five `local-path` volumes. Ingress and the AI Gateway are disabled. Keep the release name `langfuse`, which the storage endpoints reference.

Port-forward `langfuse-web` to `localhost:3000` and `langfuse-s3-all-in-one` to `localhost:8333` as shown in the guide. Browsers use the localhost S3 endpoint; server-side requests use the internal SeaweedFS service.

This setup is for local evaluation. Data is stored inside the cluster VM and is lost when the cluster is deleted. Restarting the runtime or Mac may require recreating the cluster; see the [cluster lifecycle limitations](https://github.com/apple/container/issues/2440).
