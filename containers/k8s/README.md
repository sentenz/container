# Kubernetes toolchain

The `k8s` image provides a pinned command-line environment containing:

- `kubectl` and Kustomize from `alpine/k8s`;
- Helm from `alpine/helm`;
- Kind, downloaded for the target architecture and verified against its
  upstream SHA-256 checksum manifest;
- the Docker CLI for managing a host daemon through a mounted socket.

The runtime defaults to UID and GID `10001` and uses `/workspace` as its working
directory.

## Build

Run the build from the repository root:

```bash
make build-k8s
```

To select a Kind release:

```bash
docker build \
  --build-arg KIND_VERSION=v0.32.0 \
  --file containers/k8s/Containerfile \
  --tag ghcr.io/sentenz/k8s:dev \
  .
```

## Run

```bash
docker run --rm ghcr.io/sentenz/k8s:<version> kubectl version --client
```

For Kind, mount the Docker socket and grant the permissions required by the
host daemon:

```bash
docker run --rm \
  --user root \
  --network host \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume "$PWD:/workspace" \
  ghcr.io/sentenz/k8s:<version> \
  kind get clusters
```
