# Container

[![Container](https://github.com/sentenz/container/actions/workflows/docker.yml/badge.svg)](https://github.com/sentenz/container/actions/workflows/docker.yml)

Centralized, reproducible OCI image definitions for the `sentenz` projects.

Each image owns one operational responsibility and lives below
`containers/<image>/`. Builds always use the repository root as their context, so
an image can consume repository-level sources without weakening Docker's build
context boundary.

## Details

1. Catalog-driven

    - [containers/images.json](containers/images.json)
      > The repository’s source of truth for image names, Containerfile paths, and supported platforms for local builds and the GitHub Actions matrix.

    - [containers/images.schema.json](containers/images.schema.json)
      > A repository-specific JSON Schema validating that catalog, including the `containers/<name>/Containerfile` convention.

## Images

| Image | Purpose | Platforms | Package |
| --- | --- | --- | --- |
| `k8s` | Pinned Kubernetes CLI toolchain with kubectl, Kustomize, Kind, and Helm | `linux/amd64`, `linux/arm64` | `ghcr.io/sentenz/k8s` |

## Layout

```text
.
├── .github/workflows/
│   ├── conftest.yml
│   ├── docker.yml
│   ├── regal.yml
│   ├── renovate.yml
│   ├── semgrep.yml
│   └── trivy.yml
├── containers/
│   ├── images.json
│   ├── images.schema.json
│   └── k8s/
│       ├── Containerfile
│       ├── README.md
│       └── install-kind.sh
├── scripts/
│   ├── container
│   └── policy-inputs
├── tests/policy/
│   ├── containerfile.rego
│   ├── downloads.rego
│   ├── github_actions.rego
│   ├── policy_test.rego
│   └── renovate.rego
├── .dockerignore
├── .regal/config.yaml
├── conftest.toml
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
make policy
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

Repository checks and maintenance use pinned composite actions from the same
repository:

| Workflow | Checks | Triggers |
| --- | --- | --- |
| `Conftest` | Supply-chain policy enforcement | Relevant pull requests, changes to `main`, manual runs |
| `Regal` | Rego policy and unit-test linting | Policy, Regal configuration, or workflow changes; manual runs |
| `Semgrep` | GitHub Actions security rules | Workflow or ignore-file changes; manual runs |
| `Trivy` | Repository dependency vulnerabilities and secrets at HIGH or CRITICAL severity | Pull requests, changes to `main`, Mondays at 04:23 UTC, manual runs |
| `Renovate` | Updates to pinned dependencies, scoped to this repository | Mondays at 04:41 UTC or manual runs, when enabled |

Semgrep uses the `p/github-actions` registry rule set with metrics disabled.
Findings, scan errors, and scans with no targets fail the job. Semgrep JSON/SARIF
reports and the Trivy JSON report are retained as workflow artifacts for 14 days,
including when findings fail a scan. These checks require only `contents: read`
and run without repository secrets. The filesystem scan complements the
Container workflow's image-definition checks; it does not scan built images.

Regal uses [`.regal/config.yaml`](.regal/config.yaml). The configuration retains
Conftest's shared test namespace and permits Containerfile helpers to access the
shared parsed input; other default lint rules remain enabled.

### Self-hosted Renovate

The Renovate workflow is opt-in to avoid duplicate runs alongside an installed
Renovate GitHub App. To use it:

1. Add a repository secret named `RENOVATE_TOKEN` containing a dedicated personal
   access token scoped to this repository. Use the permissions listed in the
   [Renovate authentication guidance](https://docs.renovatebot.com/modules/platform/github/),
   including Workflows read/write access for GitHub Actions updates. The built-in
   `GITHUB_TOKEN` is not supported by the composite action.
2. Set the repository Actions variable `RENOVATE_ENABLED` to `true`.
3. Run the `Renovate` workflow on the default branch or wait for its weekly run.

The workflow reads [`renovate.json`](renovate.json), disables repository
autodiscovery, and skips execution on a manually selected feature branch.
Leaving `RENOVATE_ENABLED` unset skips the maintenance job.

## Supply-chain policy

- Base images and GitHub Actions are pinned to immutable digests or commit SHAs.
- Downloaded tools are verified against upstream SHA-256 checksum manifests.
- Runtime images use an unprivileged user.
- Renovate keeps pinned dependencies current without replacing immutable pins
  with mutable tags.

[Conftest](https://www.conftest.dev/) enforces these controls for Containerfiles,
download scripts, GitHub Actions workflows, and Renovate configuration. The Rego
policies live in [`tests/policy`](tests/policy) and use
[`conftest.toml`](conftest.toml). `make policy` first runs the Rego unit tests,
then evaluates the repository inputs and writes the JSON report to
`logs/policy/conftest-report.json`.

## License

Licensed under the [Apache License 2.0](LICENSE).
