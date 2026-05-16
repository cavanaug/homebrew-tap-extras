#!/usr/bin/env bash
set -euo pipefail

MIN_AGE_DAYS=2

while [ "$#" -gt 0 ]; do
  case "$1" in
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

ROOT="$(git rev-parse --show-toplevel)"
FORMULA="${ROOT}/Formula/copilot-api.rb"
REPO="caozhiyuan/copilot-api"
API="https://api.github.com/repos/${REPO}/releases/latest"

# Extract current version from the primary formula URL only.
CURRENT=$(ruby -e '
  content = File.read(ARGV[0])
  version = content[/^\s*url\s+"https:\/\/github\.com\/caozhiyuan\/copilot-api\/archive\/refs\/tags\/v([^\"]+)\.tar\.gz"/, 1]
  abort "Failed to extract current version from #{ARGV[0]}" unless version
  puts version
' "$FORMULA")

eval "$({
  curl -fsSL "$API" | ruby -rjson -rtime -e '
    release = JSON.parse(STDIN.read)
    latest = release.fetch("tag_name").sub(/^v/, "")
    published_at = Time.iso8601(release.fetch("published_at"))
    min_age_days = Integer(ARGV.fetch(0))
    age_days = ((Time.now.utc - published_at) / 86_400).floor

    puts "LATEST=#{latest.dump}"
    puts "PUBLISHED_AT=#{release.fetch("published_at").dump}"
    puts "AGE_DAYS=#{age_days}"
    puts "TOO_NEW=#{(age_days < min_age_days).to_s.dump}"
  ' "$MIN_AGE_DAYS"
})"

echo "Current version: v${CURRENT}"
echo "Latest version:  v${LATEST}"
echo "Published at:    ${PUBLISHED_AT}"
echo "Age (days):      ${AGE_DAYS}"

if [ "$TOO_NEW" = "true" ]; then
    echo "Skipping update: release is newer than ${MIN_AGE_DAYS} days"
    exit 0
fi

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
