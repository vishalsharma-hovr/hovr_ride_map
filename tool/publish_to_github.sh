#!/usr/bin/env bash
# Publishes this package to https://github.com/vishalsharma-hovr/hovr_ride_map
#
# Prerequisites:
#   - GitHub CLI: brew install gh && gh auth login
#
# Protected main (recommended): pushes release/VERSION branch + tag, opens a PR.
# The host app can use the tag immediately (ref: v1.0.1) before the PR merges.
#
# After publishing, update the host app pubspec.yaml:
#   hovr_ride_map:
#     git:
#       url: https://github.com/vishalsharma-hovr/hovr_ride_map.git
#       ref: v1.0.1
#
# Solo owner — merge your own PR:
#   1. Repo → Settings → Rules → main → enable "Allow administrators to bypass"
#   2. Open PR → Review → Approve → Merge
#   Or: gh pr merge --admin --squash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"
GITHUB_OWNER="${GITHUB_OWNER:-vishalsharma-hovr}"
REPO_NAME="${REPO_NAME:-hovr_ride_map}"
REMOTE_URL="${REMOTE_URL:-https://github.com/${GITHUB_OWNER}/${REPO_NAME}.git}"
WORK_DIR="$(mktemp -d)"
RELEASE_BRANCH="release/${VERSION}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: ./tool/publish_to_github.sh v1.0.1"
  exit 1
fi

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must look like v1.0.1 (got: $VERSION)"
  exit 1
fi

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found. Install with: brew install gh && gh auth login"
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
fi

echo "Cloning ${REMOTE_URL} ..."
if gh repo view "${GITHUB_OWNER}/${REPO_NAME}" >/dev/null 2>&1; then
  git clone "$REMOTE_URL" "$WORK_DIR/repo"
  cd "$WORK_DIR/repo"
  git checkout -B "$RELEASE_BRANCH"
else
  echo "Creating GitHub repository ${GITHUB_OWNER}/${REPO_NAME} ..."
  mkdir -p "$WORK_DIR/repo"
  cd "$WORK_DIR/repo"
  git init -b main
  gh repo create "${GITHUB_OWNER}/${REPO_NAME}" --public --source=. --remote=origin
  git checkout -B "$RELEASE_BRANCH"
fi

echo "Syncing package files ..."
rsync -a --delete \
  --exclude '.dart_tool' \
  --exclude 'build' \
  --exclude 'example/build' \
  --exclude 'example/ios/Pods' \
  --exclude '.git' \
  "$ROOT/" ./

if git diff --quiet && git diff --cached --quiet; then
  echo "No changes to publish."
  exit 0
fi

git add -A
git commit -m "Release $VERSION"
git tag -f "$VERSION"

git push -u origin "$RELEASE_BRANCH" --force
git push origin "$VERSION" --force

PR_URL="$(gh pr create \
  --repo "${GITHUB_OWNER}/${REPO_NAME}" \
  --base main \
  --head "$RELEASE_BRANCH" \
  --title "Release $VERSION" \
  --body "Release $VERSION. Tag \`$VERSION\` is available for host \`pubspec.yaml\` git refs." \
  2>/dev/null || true)"

echo ""
echo "Published tag $VERSION to $REMOTE_URL"
echo "Release branch: $RELEASE_BRANCH"
if [[ -n "$PR_URL" ]]; then
  echo "Pull request: $PR_URL"
else
  echo "Pull request: https://github.com/${GITHUB_OWNER}/${REPO_NAME}/compare/main...${RELEASE_BRANCH}?expand=1"
fi
echo ""
echo "Host pubspec: ref: ${VERSION}"
echo "Owner merge:  gh pr merge --repo ${GITHUB_OWNER}/${REPO_NAME} --admin --squash"
