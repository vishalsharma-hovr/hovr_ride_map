#!/usr/bin/env bash
# Publishes this package to https://github.com/vishalsharma-hovr/hovr_ride_map
#
# Prerequisites:
#   - GitHub CLI: brew install gh && gh auth login
#
# After publishing, update the host app pubspec.yaml:
#   hovr_ride_map:
#     git:
#       url: https://github.com/vishalsharma-hovr/hovr_ride_map.git
#       ref: v1.0.0

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-v1.0.0}"
GITHUB_OWNER="${GITHUB_OWNER:-vishalsharma-hovr}"
REPO_NAME="${REPO_NAME:-hovr_ride_map}"
REMOTE_URL="${REMOTE_URL:-https://github.com/${GITHUB_OWNER}/${REPO_NAME}.git}"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "Copying package to $WORK_DIR ..."
rsync -a \
  --exclude '.dart_tool' \
  --exclude 'build' \
  --exclude 'example/build' \
  --exclude 'example/ios/Pods' \
  --exclude '.git' \
  "$ROOT/" "$WORK_DIR/"

cd "$WORK_DIR"
git init -b main
git add -A
git commit -m "Release $VERSION"
git tag "$VERSION"

if command -v gh >/dev/null 2>&1; then
  if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Run: gh auth login"
    exit 1
  fi
  if ! gh repo view "${GITHUB_OWNER}/${REPO_NAME}" >/dev/null 2>&1; then
    echo "Creating GitHub repository ${GITHUB_OWNER}/${REPO_NAME} ..."
    gh repo create "${GITHUB_OWNER}/${REPO_NAME}" --public --source=. --remote=origin --push
  else
    git remote add origin "$REMOTE_URL" 2>/dev/null || git remote set-url origin "$REMOTE_URL"
    git push -u origin main
    git push origin "$VERSION"
  fi
  echo "Published $VERSION to $REMOTE_URL"
else
  echo "gh CLI not found. Install with: brew install gh && gh auth login"
  exit 1
fi
