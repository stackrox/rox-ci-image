#!/usr/bin/env bash

# Script to automate bumping the Go version across all Docker images
# Usage: ./scripts/bump_go_version.sh <target_go_version>
# Example: ./scripts/bump_go_version.sh 1.24.6

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

function warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

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

# Fetch the Go download page
info "Fetching Go download information from https://go.dev/dl/..."
GO_DL_PAGE=$(curl -sSL "https://go.dev/dl/")

# Extract SHA256 for linux-amd64
# The HTML structure looks like: <tr>...<td>go1.24.6.linux-amd64.tar.gz</td>...<tt>SHA256_HASH</tt>...</tr>
SHA256=$(echo "$GO_DL_PAGE" | grep -A 50 "go${TARGET_VERSION}.linux-amd64.tar.gz" | sed -n 's/.*<tt>\([a-f0-9]\{64\}\)<\/tt>.*/\1/p' | head -1)

if [ -z "$SHA256" ]; then
    error "Failed to retrieve SHA256 checksum for Go version $TARGET_VERSION"
    error "Please verify the version exists at https://go.dev/dl/"
    error "Note: Archived versions may be further down the page"
    exit 1
fi

info "Found SHA256: $SHA256"

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

    # Update GOLANG_SHA256
    if grep -q "ARG GOLANG_SHA256=" "$dockerfile"; then
        sed -i.bak "s/ARG GOLANG_SHA256=.*/ARG GOLANG_SHA256=${SHA256}/" "$dockerfile"
    else
        warning "    GOLANG_SHA256 not found in $dockerfile"
    fi

    # Remove backup files
    rm -f "${dockerfile}.bak"
done

info "All files updated successfully!"

# Show the changes
info "Changes made:"
git diff

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

Updates GOLANG_VERSION and GOLANG_SHA256 across all Docker images.

- GOLANG_VERSION: ${TARGET_VERSION}
- GOLANG_SHA256: ${SHA256}
- Archive: go${TARGET_VERSION}.linux-amd64.tar.gz"

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
PR_TITLE="Bump Go version to ${TARGET_VERSION}"
PR_BODY="This PR updates the Go version to ${TARGET_VERSION} across all Docker images.

## Changes
- Updated \`GOLANG_VERSION\` to ${TARGET_VERSION}
- Updated \`GOLANG_SHA256\` to ${SHA256}

## Verification
- Archive: \`go${TARGET_VERSION}.linux-amd64.tar.gz\`
- SHA256: \`${SHA256}\`
- Source: https://go.dev/dl/

## Affected Files
$(printf '%s\n' "${DOCKERFILES[@]}" | sed 's/^/- `/' | sed 's/$/`/')"

if command -v gh &> /dev/null; then
    PR_URL=$(gh pr create --title "$PR_TITLE" --body "$PR_BODY" --web 2>&1 | tee /dev/tty | grep -o 'https://github.com/[^[:space:]]*' || true)

    if [ -n "$PR_URL" ]; then
        info "Pull request created successfully!"
        info "PR URL: $PR_URL"
    else
        warning "GitHub CLI installed but PR creation may have failed."
        warning "Please check the output above or create the PR manually at:"
        warning "  https://github.com/stackrox/rox-ci-image/compare/$BRANCH_NAME"
    fi
else
    warning "GitHub CLI (gh) is not installed."
    warning "Please create a pull request manually at:"
    warning "  https://github.com/stackrox/rox-ci-image/compare/$BRANCH_NAME"
    warning ""
    warning "Or install GitHub CLI: https://cli.github.com/"
fi

info "Done! 🎉"
