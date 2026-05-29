#!/usr/bin/env bash
set -euo pipefail

MIN_AGE_DAYS=2

usage() {
  cat <<'EOF'
Usage: update.copilot-api.sh [--min-age-days DAYS] [--help]

Update Formula/copilot-api.rb to the latest eligible GitHub release.

Options:
  --min-age-days DAYS  Minimum release age in days before it can be selected
  --help               Show this help message and exit
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --min-age-days)
      [ "$#" -ge 2 ] || {
        echo "Missing value for --min-age-days" >&2
        exit 1
      }
      MIN_AGE_DAYS="$2"
      shift 2
      ;;
    --min-age-days=*)
      MIN_AGE_DAYS="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

case "$MIN_AGE_DAYS" in
  ''|*[!0-9]*)
    echo "--min-age-days must be a non-negative integer" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
FORMULA="${ROOT}/Formula/copilot-api.rb"
REPO="caozhiyuan/copilot-api"

# Extract current version from the primary formula URL only.
CURRENT=$(ruby -e '
  content = File.read(ARGV[0])
  version = content[/^\s*url\s+"https:\/\/github\.com\/caozhiyuan\/copilot-api\/archive\/refs\/tags\/v([^\"]+)\.tar\.gz"/, 1]
  abort "Failed to extract current version from #{ARGV[0]}" unless version
  puts version
' "$FORMULA")

eval "$(ruby "$SCRIPT_DIR/select-release.rb" \
  --repo "$REPO" \
  --min-age-days "$MIN_AGE_DAYS")"

echo "Current version: v${CURRENT}"
if [ "$FOUND" != "true" ]; then
    echo "Skipping update: no release is at least ${MIN_AGE_DAYS} days old"
    exit 0
fi

echo "Latest eligible: v${LATEST}"
echo "Published at:    ${PUBLISHED_AT}"
echo "Age (days):      ${AGE_DAYS}"

# Idempotent guard — exit cleanly if already at latest
if [ "$LATEST" = "$CURRENT" ]; then
    echo "Already at latest eligible: v${CURRENT}"
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
