# Contributing

Contributions should preserve the repository's image-per-responsibility model,
root build context, immutable dependency pins, and least-privilege CI settings.

Before opening a pull request:

```bash
make validate
make policy
make build
```

Use [Conventional Commits](https://www.conventionalcommits.org/) for commit
messages. Prefer the image name as the scope for image-specific changes:

```text
feat(k8s): add a Kubernetes utility
fix(k8s): verify downloaded checksum metadata
ci: harden release publishing permissions
docs: explain the image catalog
```

Pull requests should explain any new runtime privilege, network download, or
package-registry permission introduced by the change.
