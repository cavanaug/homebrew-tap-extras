#!/usr/bin/env bash
set -euo pipefail

FORMULA="Formula/copilot-api.rb"
REPO="caozhiyuan/copilot-api"
API="https://api.github.com/repos/${REPO}/releases/latest"

# Extract current version from the formula URL line
CURRENT=$(grep '^\s*url ' "$FORMULA" | sed 's|.*/tags/v\([^/]*\)\.tar\.gz.*|\1|')

# Fetch latest release tag from GitHub API (no jq dependency)
TAG=$(curl -fsSL "$API" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
LATEST="${TAG#v}" # strip leading 'v' prefix

echo "Current version: v${CURRENT}"
echo "Latest version:  v${LATEST}"

# Idempotent guard — exit cleanly if already at latest
if [ "$LATEST" = "$CURRENT" ]; then
    echo "Already at latest: v${CURRENT}"
    exit 0
fi

# Build tarball URL and compute SHA256 (shasum -a 256 available on macOS and Homebrew Linux)
TARBALL="https://github.com/${REPO}/archive/refs/tags/v${LATEST}.tar.gz"
echo "Computing sha256 for ${TARBALL} ..."
SHA256=$(curl -fsSL "$TARBALL" | shasum -a 256 | awk '{print $1}')

# Update url line — cross-platform sed with .bak idiom (works on BSD and GNU sed)
sed -i.bak "s|/tags/v[0-9][0-9.]*\.tar\.gz|/tags/v${LATEST}.tar.gz|" "$FORMULA"
rm -f "${FORMULA}.bak"

# Update sha256 line — POSIX BRE quantifier \{64\} for the hex digest
sed -i.bak "s|sha256 \"[a-f0-9]\{64\}\"|sha256 \"${SHA256}\"|" "$FORMULA"
rm -f "${FORMULA}.bak"

echo "Bumped v${CURRENT} → v${LATEST} (sha256: ${SHA256})"
