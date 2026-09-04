# Project Layout

- [1. Container Project](#1-container-project)
  - [1.1. Layout and Structure](#11-layout-and-structure)
  - [1.2. Files and Folders](#12-files-and-folders)
  - [1.3. Design Principles](#13-design-principles)
  - [1.4. Build Context](#14-build-context)
- [2. References](#2-references)

## 1. Container Project

A container project can manage multiple application and development images in a single repository while keeping each `Containerfile` focused on one operational responsibility. Application source, image definitions, automation, and tests are separated so that each concern can evolve independently without obscuring the relationship between an application and the image that packages it.

Each image is represented by a dedicated directory under `containers/`. The directory name identifies the image responsibility, while the repository root remains the shared build context when application source or other repository-level resources are required during the build.

### 1.1. Layout and Structure

1. Layout and Structure

    > [!NOTE]
    > Replace `<...>` brackets with project-specific information when extending the layout.

    ```markdown
    repo/
    │
    . `Hierarchical Structure`
    │
    ├── apps/
    │   ├── api/
    │   ├── worker/
    │   └── scheduler/
    │
    ├── containers/
    │   ├── api/
    │   │   └── Containerfile
    │   ├── worker/
    │   │   └── Containerfile
    │   ├── scheduler/
    │   │   └── Containerfile
    │   └── development/
    │       └── Containerfile
    │
    ├── scripts/
    ├── tests/
    │
    ├── .dockerignore
    ├── Makefile
    └── README.md
    ```

### 1.2. Files and Folders

1. Files and Folders

    - `apps/`
      > Application source code grouped by independently executable responsibility. Each sub-directory represents an application or process that can be packaged into a dedicated container image.

      - `api/`
        > Source code for the API application and its runtime entry point.

      - `worker/`
        > Source code for asynchronous or background worker processes.

      - `scheduler/`
        > Source code for scheduled jobs, task dispatching, or periodic workloads.

    - `containers/`
      > Container image definitions organized by image responsibility. Each sub-directory owns one `Containerfile` and may contain image-specific entrypoints, health checks, configuration fragments, or other files required only by that image.

      - `api/`
        > Image definition for packaging and running the API application.

        - `Containerfile`
          > Declarative build definition for the API image, including its base image, dependencies, filesystem contents, runtime user, metadata, and default process.

      - `worker/`
        > Image definition for packaging and running the worker application.

        - `Containerfile`
          > Declarative build definition for the worker image.

      - `scheduler/`
        > Image definition for packaging and running the scheduler application.

        - `Containerfile`
          > Declarative build definition for the scheduler image.

      - `development/`
        > Development-specific image definition containing tooling or dependencies that are intentionally excluded from production images.

        - `Containerfile`
          > Declarative build definition for the development image.

    - `scripts/`
      > Repository-level automation for building, testing, validating, publishing, or otherwise managing container images. Image-specific scripts should remain with their corresponding directory under `containers/` when they are not shared.

    - `tests/`
      > Cross-image, integration, security, smoke, or repository-level tests that validate container behavior independently from application unit tests.

    - `.dockerignore`
      > Build-context exclusion rules used to prevent unnecessary, sensitive, or generated repository content from being sent to the container builder.

    - `Makefile`
      > Common interface for local development and CI operations such as building, testing, scanning, and publishing individual or all container images.

    - `README.md`
      > Project overview, supported images, prerequisites, common commands, and repository usage instructions.

### 1.3. Design Principles

1. Single Responsibility

    Each `Containerfile` SHOULD define one operationally meaningful image responsibility. Separate image definitions are appropriate when workloads have different runtime dependencies, commands, security boundaries, exposed interfaces, or lifecycle requirements.

    ```markdown
    containers/
    ├── api/
    │   └── Containerfile
    ├── worker/
    │   └── Containerfile
    └── scheduler/
        └── Containerfile
    ```

    A single oversized image that changes only its runtime command SHOULD be avoided when the workloads require materially different dependencies or privileges.

2. Application and Image Colocation

    Application-specific `Containerfile` definitions SHOULD remain in the same repository as the source they package. This keeps source changes and image-definition changes versioned together and avoids an additional cross-repository versioning contract.

    Shared base images, CI runners, organization-wide development images, or hardened runtime foundations MAY be maintained in a separate image repository when they have an independent lifecycle and are consumed by multiple projects.

3. Image-specific Supporting Files

    Files used exclusively by one image SHOULD be placed beside its `Containerfile`.

    ```markdown
    containers/
    └── api/
        ├── Containerfile
        ├── entrypoint.sh
        └── healthcheck.sh
    ```

    Shared automation SHOULD remain under `scripts/` rather than being duplicated across image directories.

4. Environment Configuration

    Environment-specific configuration SHOULD generally be supplied at deployment or runtime rather than represented by separate production `Containerfile` variants.

    ```markdown
    containers/api/Containerfile
    ```

    is preferred over:

    ```markdown
    containers/api/Containerfile.dev
    containers/api/Containerfile.staging
    containers/api/Containerfile.prod
    ```

    when all environments execute the same application artifact. A separate development image is appropriate when it intentionally contains compilers, debuggers, hot-reload tooling, or other development-only dependencies.

5. Multi-stage Builds

    Multi-stage builds SHOULD be used for construction stages of the same image, while multiple `Containerfile` definitions SHOULD be used for distinct operational image responsibilities.

    For example, a compile stage and runtime stage belong in one `Containerfile` when both stages produce the same deployable image.

### 1.4. Build Context

The location of a `Containerfile` and the container build context are independent concepts. For application images that consume source from `apps/`, the repository root SHOULD normally be used as the build context.

For Docker:

```shell
docker build \
  --file containers/api/Containerfile \
  --tag <registry>/<project>/api:<tag> \
  .
```

For Podman:

```shell
podman build \
  --file containers/api/Containerfile \
  --tag <registry>/<project>/api:<tag> \
  .
```

The final `.` selects the repository root as the build context. The `--file` option selects the image definition independently of that context.

This permits repository-relative copy operations such as:

```dockerfile
COPY apps/api/ /opt/app/
```

Building with `containers/api/` as the context would prevent the build from accessing `apps/api/`, because container builders do not permit `COPY` to read files outside the selected build context.

The `.dockerignore` file SHOULD therefore be maintained carefully to keep the root build context small and deterministic while preserving every file required by any image build.

A `Makefile` can provide a stable build interface for developers and CI systems:

```makefile
REGISTRY ?= example
TAG ?= dev

.PHONY: build build-api build-worker build-scheduler

build: build-api build-worker build-scheduler

build-api:
	docker build \
		--file containers/api/Containerfile \
		--tag $(REGISTRY)/api:$(TAG) \
		.

build-worker:
	docker build \
		--file containers/worker/Containerfile \
		--tag $(REGISTRY)/worker:$(TAG) \
		.

build-scheduler:
	docker build \
		--file containers/scheduler/Containerfile \
		--tag $(REGISTRY)/scheduler:$(TAG) \
		.
```

This keeps build invocation consistent and avoids duplicating container build commands across developer documentation and CI workflows.

## 2. References

- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Docker build context](https://docs.docker.com/build/building/context/)
- [Docker build best practices](https://docs.docker.com/build/building/best-practices/)
- [Podman build](https://docs.podman.io/en/latest/markdown/podman-build.1.html)
- [OCI Image Format Specification](https://github.com/opencontainers/image-spec)
