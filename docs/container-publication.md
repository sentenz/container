# Container publication and SBOMs

## SBOM decision

Keep `.github/workflows/sbom.yml` as the only SBOM implementation. It is called
by `publish-image.yml` after a successful image build and publication, once per
catalog image, and expands into one job per supported architecture.

| Previous location | Decision |
| --- | --- |
| `semantic-release.yml` inline filesystem SBOM steps | Remove; the release workflow calls the container pipeline explicitly. |
| `trivy.yml` filesystem SBOM generation, upload, and rescan jobs | Remove; retain filesystem vulnerability, configuration, and license scans in CI. |
| `sbom.yml` reusable workflow | Keep, replacing source scans with inventories of the published image digests. |
| BuildKit SBOM generation | Do not add a second generator. Keep the existing BuildKit provenance and use Trivy for both SBOM formats. |

A filesystem scan of this repository does not inventory the OS packages and
copied executables inside a built image. Trivy now scans the exact runtime
manifest pulled from the digest returned by the build. Each architecture has
its own SBOM; an AMD64 inventory must not stand in for the ARM64 image.

GitHub's [artifact attestation guidance](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)
provides the model: identify a container by its full name and SHA-256 digest,
then sign an SPDX or CycloneDX SBOM with `actions/attest`. This pipeline signs
SPDX SBOMs, pushes those attestations to GHCR, and also preserves CycloneDX as a
release asset for tools such as Dependency-Track. Build provenance is signed
separately for the multi-platform image index. All external actions use full
commit pins. Write permissions are confined to the jobs that publish releases,
packages, or attestations; pull requests only validate and build.

Docker's [BuildKit SBOM support](https://docs.docker.com/build/ci/github-actions/attestations/)
is a valid alternative for registry-attached build-time inventories. Keeping
Trivy here preserves the existing CycloneDX/SPDX outputs and vulnerability
scanner while eliminating competing SBOM pipelines. BuildKit provenance and
GitHub's signed provenance serve different verification mechanisms.

The image and SBOM pipeline is invoked directly by Semantic-Release because
[events produced by `GITHUB_TOKEN`](https://docs.github.com/en/actions/concepts/security/github_token)
do not normally start another workflow. The `release: published` entry point
also supports releases published independently. Trivy no longer publishes
SBOMs on a separate `release: created` event.

SBOM vulnerability scanning runs after uploading the reports and attestations,
so a HIGH/CRITICAL finding fails the run without losing its evidence. Images
have already been pushed at this point; this is a release audit, not a
pre-publication vulnerability gate. Existing filesystem CI scans remain active.

## Verification

For the multi-platform build provenance, use the digest in the publication job
summary:

```bash
gh attestation verify oci://ghcr.io/sentenz/k8s@sha256:<index-digest> \
  --repo sentenz/container
```

For an architecture's signed SPDX inventory, use the `digest` field in its
release asset, for example `k8s-linux-arm64.image.json`:

```bash
gh attestation verify oci://ghcr.io/sentenz/k8s@sha256:<platform-digest> \
  --repo sentenz/container \
  --predicate-type https://spdx.dev/Document/v2.3
```

The metadata asset records the image name, index digest, platform digest,
platform, and release version. The index binds each platform manifest to the
published build. SPDX verification uses the platform digest, not the index.

## Handover from template-k8s

The workflow and pinned action were checked on 2026-09-11:

| Publication setting | `template-k8s` | `container` |
| --- | --- | --- |
| Image definition | `container/k8s/Dockerfile` | `containers/k8s/Containerfile` |
| Build context | Repository root | Repository root |
| Package name | `ghcr.io/sentenz/k8s` | `ghcr.io/sentenz/k8s` |
| Platforms | `linux/amd64`, `linux/arm64` | `linux/amd64`, `linux/arm64` |
| Tags from the pinned shared action | Release version and `latest` | Release version and `latest` |
| OCI source label | `sentenz/template-k8s` | `sentenz/container` |

Both pinned shared Docker actions already resolve the requested flat package
path. No package rename or `ghcr.io/sentenz/container/k8s` alias is needed.

The old container README describes smoke-test gates, immutable version tags,
and prerelease protection for `latest`. Those safeguards are absent from its
actual workflow and pinned Docker action. Both current action revisions publish
`latest` unconditionally and do not prevent an existing version tag being
replaced. Select an unused release version during the handover.

1. Grant `sentenz/container` write access to the existing `k8s` package under
   **Package settings → Manage Actions access** and connect the package to the
   new source repository. Preserve its intended visibility. GitHub documents
   [package access separately from repository permissions](https://docs.github.com/en/packages/learn-github-packages/about-permissions-for-github-packages);
   `packages: write` in YAML alone cannot grant access to a package owned by a
   different repository's workflow.
2. Pause the old publisher while publishing and verifying the first release
   from `container`, so two repositories cannot race to replace `latest`.
   Verify both architectures and their SBOM attestations before removing the
   old image definition.
3. Update `template-k8s`'s `K8S_KIND_IMAGE` in its Makefile to the chosen new
   release and digest. It currently pins `ghcr.io/sentenz/k8s:2.1.12` by digest,
   so moving `latest` will not migrate that consumer.
4. Remove the old `.github/workflows/docker.yml` together with its `trigger`
   caller in `semantic-release.yml`. Retire the old image directory and update
   the Makefile's `CONTAINER_DOCKER_FILE` build target and related documentation.
   Preserve bootstrap commands used by other K8s workflows.

At review time, `container` still pins `alpine/k8s:1.36.2` while `template-k8s`
has moved to `1.37.0`. The existing container dependency PR #7 addresses that
image update; resolve the intended tool versions before switching consumers.

The GHCR package permissions and the first publication require verification in
the live release environment. Source labels are already set to
`https://github.com/sentenz/container` in the new Containerfile.
