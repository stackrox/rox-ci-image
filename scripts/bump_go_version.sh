#!/usr/bin/env bash

# Script to automate bumping the Go version across all Docker images
# Usage: ./scripts/bump_go_version.sh <target_go_version>
# Example: ./scripts/bump_go_version.sh 1.24.6

set -euo pipefail

function info() {
    echo "[INFO] $1"
}

function error() {
    echo "[ERROR] $1" >&2
}

function warning() {
    echo "[WARNING] $1"
}

function update_dockerfiles() {
    # Fetch the Go download page
    info "Fetching Go download information from https://go.dev/dl/..."
    GO_DL_PAGE=$(curl -sSL "https://go.dev/dl/")

    # Extract SHA256 for linux-amd64
    # The HTML structure looks like: <tr>...<td>go1.24.6.linux-amd64.tar.gz</td>...<tt>SHA256_HASH</tt>...</tr>
    SHA256_AMD64=$(echo "$GO_DL_PAGE" | grep -A 50 "go${TARGET_VERSION}.linux-amd64.tar.gz" | sed -n 's/.*<tt>\([a-f0-9]\{64\}\)<\/tt>.*/\1/p' | head -1)

    # Extract SHA256 for linux-arm64
    SHA256_ARM64=$(echo "$GO_DL_PAGE" | grep -A 50 "go${TARGET_VERSION}.linux-arm64.tar.gz" | sed -n 's/.*<tt>\([a-f0-9]\{64\}\)<\/tt>.*/\1/p' | head -1)

    if [ -z "$SHA256_AMD64" ]; then
        error "Failed to retrieve SHA256 checksum for Go version $TARGET_VERSION (amd64)"
        error "Please verify the version exists at https://go.dev/dl/"
        error "Note: Archived versions may be further down the page"
        exit 1
    fi

    if [ -z "$SHA256_ARM64" ]; then
        error "Failed to retrieve SHA256 checksum for Go version $TARGET_VERSION (arm64)"
        error "Please verify the version exists at https://go.dev/dl/"
        error "Note: Archived versions may be further down the page"
        exit 1
    fi

    info "Found SHA256 (amd64): $SHA256_AMD64"
    info "Found SHA256 (arm64): $SHA256_ARM64"

    # For backwards compatibility, keep SHA256 as the amd64 value
    SHA256="$SHA256_AMD64"

    # Find all Dockerfiles that contain GOLANG_VERSION
    info "Finding Dockerfiles with GOLANG_VERSION..."
    mapfile -t DOCKERFILES < <(grep -rl "ARG GOLANG_VERSION=" images/ 2>/dev/null | sort)

    if [ ${#DOCKERFILES[@]} -eq 0 ]; then
        error "No Dockerfiles found with GOLANG_VERSION argument"
        exit 1
    fi

    info "Found ${#DOCKERFILES[@]} Dockerfile(s) to update:"
    for dockerfile in "${DOCKERFILES[@]}"; do
        info "  - $dockerfile"
    done

    # Update each Dockerfile
    info "Updating Dockerfiles..."
    for dockerfile in "${DOCKERFILES[@]}"; do
        if [ ! -f "$dockerfile" ]; then
            warning "File not found: $dockerfile (skipping)"
            continue
        fi

        info "  - Updating $dockerfile"

        # Update GOLANG_VERSION
        if grep -q "ARG GOLANG_VERSION=" "$dockerfile"; then
            sed -i.bak "s/ARG GOLANG_VERSION=.*/ARG GOLANG_VERSION=${TARGET_VERSION}/" "$dockerfile"
        else
            warning "    GOLANG_VERSION not found in $dockerfile"
        fi

        # Update GOLANG_SHA256_AMD64
        if grep -q "ARG GOLANG_SHA256_AMD64=" "$dockerfile"; then
            sed -i.bak "s/ARG GOLANG_SHA256_AMD64=.*/ARG GOLANG_SHA256_AMD64=${SHA256_AMD64}/" "$dockerfile"
            info "    Updated GOLANG_SHA256_AMD64"
        fi

        # Update GOLANG_SHA256_ARM64 (if present)
        if grep -q "ARG GOLANG_SHA256_ARM64=" "$dockerfile"; then
            sed -i.bak "s/ARG GOLANG_SHA256_ARM64=.*/ARG GOLANG_SHA256_ARM64=${SHA256_ARM64}/" "$dockerfile"
            info "    Updated GOLANG_SHA256_ARM64"
        fi

        # Remove backup files
        rm -f "${dockerfile}.bak"
    done

    info "All files updated successfully!"
}

function create_pr() {
    # Create a new branch
    BRANCH_NAME="bump-go-${TARGET_VERSION}"
    info "Creating branch: $BRANCH_NAME"
    git checkout -b "$BRANCH_NAME"

    # Stage the changes
    info "Staging changes..."
    for dockerfile in "${DOCKERFILES[@]}"; do
        if [ -f "$dockerfile" ]; then
            git add "$dockerfile"
        fi
    done

    # Commit the changes
    COMMIT_MSG="Bump Go version to ${TARGET_VERSION}

Updates GOLANG_VERSION and SHA256 values across all Docker images.

- GOLANG_VERSION: ${TARGET_VERSION}
- GOLANG_SHA256_AMD64: ${SHA256_AMD64}
- GOLANG_SHA256_ARM64: ${SHA256_ARM64}

Archives: go${TARGET_VERSION}.linux-{amd64,arm64}.tar.gz"

    info "Committing changes..."
    git commit -m "$COMMIT_MSG"

    # Push the branch
    info "Pushing branch to origin..."
    if ! git push -u origin "$BRANCH_NAME"; then
        error "Failed to push branch. You may need to push manually:"
        error "  git push -u origin $BRANCH_NAME"
        exit 1
    fi

    # Create a pull request using GitHub CLI
    info "Creating pull request..."
    PR_TITLE="chore(go): Bump Go version to ${TARGET_VERSION}"
    PR_BODY="This PR updates the Go version to ${TARGET_VERSION} across all Docker images.

## Changes
- Updated \`GOLANG_VERSION\` to ${TARGET_VERSION}
- Updated \`GOLANG_SHA256_AMD64\` to ${SHA256_AMD64}
- Updated \`GOLANG_SHA256_ARM64\` to ${SHA256_ARM64} (where applicable)

## Verification
- Archives: \`go${TARGET_VERSION}.linux-{amd64,arm64}.tar.gz\`
- SHA256 (amd64): \`${SHA256_AMD64}\`
- SHA256 (arm64): \`${SHA256_ARM64}\`
- Source: https://go.dev/dl/

## Affected Files
$(printf '%s\n' "${DOCKERFILES[@]}" | sed 's/^/- `/' | sed 's/$/`/')"

    PR_URL=$(gh pr create --title "$PR_TITLE" --body "$PR_BODY" --draft)

    if [ -n "$PR_URL" ]; then
        info "Pull request created successfully!"
        info "PR URL: $PR_URL"
    else
        error "Failed to create pull request"
        exit 1
    fi
    }

function main() {
    update_dockerfiles
    create_pr
    info "Done! 🎉"
}

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) is required but not installed."
    error "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if target version is provided
if [ $# -ne 1 ]; then
    error "Usage: $0 <target_go_version>"
    error "Example: $0 1.24.6"
    exit 1
fi

TARGET_VERSION="$1"

# Validate version format (should be like 1.24.6)
if ! [[ "$TARGET_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error "Invalid version format: $TARGET_VERSION"
    error "Expected format: X.Y.Z (e.g., 1.24.6)"
    exit 1
fi

info "Target Go version: $TARGET_VERSION"

# Get the repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Ensure we're on a clean working tree
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    error "Working tree is not clean. Please commit or stash your changes first."
    exit 1
fi

main "$@"
