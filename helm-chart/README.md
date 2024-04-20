# langfuse helm chart

This is a community-maintained Helm Chart for Langfuse. Please feel free to contribute any improvements or suggestions.

Langfuse deployment docs: https://langfuse.com/docs/deployment/self-host

Please set image tag to set a version.

# Chart Detailed Configuration

There are required values that you may need set explicitly when deploying Langfuse. You can change it in values.yaml when you need.

| Parameter | Description | Example |
| --------- | ----------- | ------- |
| `image.tag` | langfuse version, please set this to set a version | `2.8.0`, etc |
| `configMap.langfuseNodeEnv` | run environment | `development`, `test`, `production` |
| `configMap.langfuseDbUrl.username` | database username | `postgres` |
| `configMap.langfuseDbUrl.password` | database pasword | `postgres` |
| `configMap.langfuseDbUrl.address` | database address | `localhost`, etc |
| `configMap.langfuseDbUrl.port` | database port | `5432` |
| `configMap.langfuseDbUrl.name` | database name | `postgres` |
| `configMap.langfuseNextauthUrl` | redirect url when new user signed up, need to change to your langfuse url or what you need | `http://localhost:3000` |
| `configMap.langfuseNextauthSecret` | nextauth secret | `mysecret` |
| `configMap.langfuseSalt` | salt for API key hashing | `mysalt` |
| `configMap.langfuseTelemetryEnabled` | telemetry service for Docker deployments | `true`, `false` |
| `configMap.langfuseNextPublicSignUpDisabled` | if new user can sign up by themself | `true`, `false` |
| `configMap.langfuseEnableExperimentalFeatures` | if enable experimentail features | `true`, `false` |
| `ingress.enable` | set this to true if you need to setup ingress rule for langfuse | `true`, `false` |
| `ingress.hosts.host` | change this value when you set ingress.enable to true | `langfuse.example.com`, etc |