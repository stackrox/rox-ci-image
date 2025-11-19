[![GitHub Action][gha-badge]][gha-link]

# StackRox CI & Build Images

This repository holds the Dockerfiles for images used in StackRox CI & builds.

[gha-badge]: https://github.com/stackrox/rox-ci-image/actions/workflows/build.yaml/badge.svg
[gha-link]:  https://github.com/stackrox/rox-ci-image/actions/workflows/build.yaml

## Updating the Go Version

To bump the Go version across all Docker images in this repository, use the automated script:

```bash
./scripts/bump_go_version.sh <target_version>
```

### Example

```bash
./scripts/bump_go_version.sh 1.24.6
```

### What the script does

1. Validates the target Go version format
2. Fetches the SHA256 checksum for `go<version>.linux-amd64.tar.gz` from https://go.dev/dl/
3. Automatically finds all Dockerfiles containing `GOLANG_VERSION` argument
4. Updates `GOLANG_VERSION` and `GOLANG_SHA256` in all found Dockerfiles
5. Creates a new branch named `bump-go-<version>`
6. Commits the changes with a descriptive message
7. Pushes the branch to origin
8. Creates a pull request (requires [GitHub CLI](https://cli.github.com/))

### Requirements

- Clean git working tree (no uncommitted changes)
- Push access to the repository
- [GitHub CLI](https://cli.github.com/) installed and authenticated
