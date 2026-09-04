# Container

[![Container](https://github.com/sentenz/container/actions/workflows/container.yml/badge.svg)](https://github.com/sentenz/container/actions/workflows/container.yml)

Centralized, reproducible OCI image definitions for the `sentenz` projects.

Each image owns one operational responsibility and lives below
`containers/<image>/`. Builds always use the repository root as their context, so
an image can consume repository-level sources without weakening Docker's build
context boundary.

## Details

- `containers/images.json`
  > The repository’s source of truth for image names, Containerfile paths, and supported platforms. Both local tooling and CI derive their build matrix from it.

- `containers/images.schema.json`
  > A repository-specific JSON Schema validating that catalog, including the `containers/<name>/Containerfile` convention.

## Images

| Image | Purpose | Platforms | Package |
| --- | --- | --- | --- |
| `k8s` | Pinned Kubernetes CLI toolchain with kubectl, Kustomize, Kind, and Helm | `linux/amd64`, `linux/arm64` | `ghcr.io/sentenz/k8s` |

The machine-readable catalog is [`containers/images.json`](containers/images.json).
It is the source of truth for local builds and the GitHub Actions matrix.

## Layout

```text
.
├── .github/workflows/container.yml
├── containers/
│   ├── images.json
│   ├── images.schema.json
│   └── k8s/
│       ├── Containerfile
│       ├── README.md
│       └── install-kind.sh
├── scripts/container
├── .dockerignore
├── Makefile
└── renovate.json
```

The Containerfile path and build context are deliberately distinct:

```bash
docker build --file containers/k8s/Containerfile --tag ghcr.io/sentenz/k8s:dev .
```

The final `.` keeps the repository root as the build context.

## Local workflow

Docker is the default engine. Podman or another compatible CLI can be selected
with `CONTAINER_ENGINE`.

```bash
make list
make validate
make build
make build-k8s

CONTAINER_ENGINE=podman CONTAINER_TAG=test make build-k8s
```

The equivalent script interface is:

```bash
./scripts/container list
./scripts/container validate
./scripts/container build [image ...]
./scripts/container matrix
```

## Adding an image

1. Create `containers/<name>/Containerfile` and keep image-specific support files
   in the same directory.
2. Add the image metadata to `containers/images.json`.
3. Run `make validate` and `make build-<name>`.
4. Commit the change with a Conventional Commit, for example
   `feat(terraform): add Terraform toolchain image`.

Avoid environment-specific Containerfiles when runtime configuration is the
only difference. A separate Containerfile is appropriate when the resulting
artifact has materially different dependencies, tools, or security boundaries.

## Continuous integration

The `Container` workflow uses immutable revisions of actions from
[`sentenz/actions`](https://github.com/sentenz/actions):

- pull requests and changes to `main` validate the catalog, scan the image
  definitions with Trivy, and build every catalog image without publishing;
- published GitHub Releases rebuild the catalog at the release tag and publish
  versioned and `latest` multi-platform images to GHCR;
- workflow permissions are read-only by default, with `packages: write` granted
  only to the release publishing job.

Release tags must also be valid OCI tags, such as `1.2.3` or `v1.2.3`.

## Supply-chain policy

- Base images and GitHub Actions are pinned to immutable digests or commit SHAs.
- Downloaded tools are verified against upstream SHA-256 checksum manifests.
- Runtime images use an unprivileged user.
- Renovate keeps pinned dependencies current without replacing immutable pins
  with mutable tags.

## License

Licensed under the [Apache License 2.0](LICENSE).
