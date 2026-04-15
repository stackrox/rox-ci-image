[![GitHub Action][gha-badge]][gha-link]

# StackRox CI & Build Images

This repository holds the Dockerfiles for images used in StackRox CI & builds.

[gha-badge]: https://github.com/stackrox/rox-ci-image/actions/workflows/build.yaml/badge.svg
[gha-link]:  https://github.com/stackrox/rox-ci-image/actions/workflows/build.yaml

## Image Tags and Release Process

Each image flavor (e.g. `stackrox-test`, `scanner-test`) is pushed to
`quay.io/stackrox-io/apollo-ci` with three types of tags:

| Tag | Example | Updated when | Use in |
|-----|---------|-------------|--------|
| **versioned** | `stackrox-test-0.5.7` | Every merge to main (auto-tagged) | Release branch prow configs, pinned references |
| **latest** | `stackrox-test-latest` | Every new version tag on main | Testing rox-ci-image version in openshift/release PRs with `/pj-rehearse` before promoting to stable. |
| **stable** | `stackrox-test-stable` | Manual promotion via workflow | Master/nightly prow configs in openshift/release |

### How it works

1. **Merge to main** -- `tag.yaml` auto-creates a semver tag (e.g. `0.5.8`)
2. **Tag push** -- `build.yaml` builds all images, pushes versioned tags, and
   updates `latest` (only if the tag is the highest version on main)
3. **Promote to stable** -- run manually when ready:
   ```bash
   gh workflow run promote-stable.yaml
   # or with a specific version:
   gh workflow run promote-stable.yaml -f version=0.5.8
   ```
   This does a server-side retag (no rebuild) of all image flavors from the
   specified version (default: `latest`) to `stable`.

### Updating prow jobs in openshift/release

Prow job configs in `openshift/release` reference these images via
`build_root.image_stream_tag`. The tags must first be mirrored in
`core-services/image-mirroring/_config.yaml`.

- **Master/nightly configs**: use `stable` tag -- periodically, automatically picks up
  promoted versions without config changes.
- **Release branch configs**: pin to a specific version (e.g. `scanner-test-0.5.7`)
  for reproducibility.
- **`latest` tag**: use only for testing PRs against openshift/release.
  `latest` is a moving target and should not be used for required jobs --
  it is intended only for validation before promoting to `stable`.

### Mirroring new versions to openshift CI

To mirror a new versioned tag for release branch use:

1. Add an entry to `core-services/image-mirroring/_config.yaml` in openshift/release
2. PR requires testplatform team review

The `latest` and `stable` floating tags are mirrored once and do not need
updates per version.

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
