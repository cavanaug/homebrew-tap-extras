#!/usr/bin/env bash
set -euo pipefail

MIN_AGE_DAYS=2

usage() {
  cat <<'EOF'
Usage: update.mermaid-ascii.sh [--min-age-days DAYS] [--help]

Update Formula/mermaid-ascii.rb to the latest eligible GitHub release.

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
FORMULA="${ROOT}/Formula/mermaid-ascii.rb"
REPO="AlexanderGrooff/mermaid-ascii"

current_version() {
  ruby -e 'puts File.read(ARGV[0])[/^\s*version\s+"([^"]+)"/, 1]' "$1"
}

CURRENT="$(current_version "$FORMULA")"
eval "$(ruby "$SCRIPT_DIR/select-release.rb" \
  --repo "$REPO" \
  --min-age-days "$MIN_AGE_DAYS" \
  --asset DARWIN_ARM64=mermaid-ascii_Darwin_arm64.tar.gz \
  --asset DARWIN_X86_64=mermaid-ascii_Darwin_x86_64.tar.gz \
  --asset LINUX_ARM64=mermaid-ascii_Linux_arm64.tar.gz \
  --asset LINUX_X86_64=mermaid-ascii_Linux_x86_64.tar.gz)"

echo "Current version: ${CURRENT}"
if [ "$FOUND" != "true" ]; then
  echo "Skipping update: no release is at least ${MIN_AGE_DAYS} days old"
  exit 0
fi

echo "Latest eligible: ${LATEST}"
echo "Published at:    ${PUBLISHED_AT}"
echo "Age (days):      ${AGE_DAYS}"

if [ "$LATEST" = "$CURRENT" ]; then
  echo "Already at latest eligible: ${CURRENT}"
  exit 0
fi

ruby - "$FORMULA" "$LATEST" "$DARWIN_ARM64" "$DARWIN_X86_64" "$LINUX_ARM64" "$LINUX_X86_64" <<'RUBY'
formula, version, darwin_arm64, darwin_x86_64, linux_arm64, linux_x86_64 = ARGV

content = File.read(formula)
content.sub!(/^\s*version\s+"[^"]+"/, %(  version "#{version}"))

replacements = {
  /mermaid-ascii_Darwin_arm64\.tar\.gz"\n\s+sha256 "[a-f0-9]{64}"/ => %(mermaid-ascii_Darwin_arm64.tar.gz"\n      sha256 "#{darwin_arm64}"),
  /mermaid-ascii_Darwin_x86_64\.tar\.gz"\n\s+sha256 "[a-f0-9]{64}"/ => %(mermaid-ascii_Darwin_x86_64.tar.gz"\n      sha256 "#{darwin_x86_64}"),
  /mermaid-ascii_Linux_arm64\.tar\.gz"\n\s+sha256 "[a-f0-9]{64}"/ => %(mermaid-ascii_Linux_arm64.tar.gz"\n      sha256 "#{linux_arm64}"),
  /mermaid-ascii_Linux_x86_64\.tar\.gz"\n\s+sha256 "[a-f0-9]{64}"/ => %(mermaid-ascii_Linux_x86_64.tar.gz"\n      sha256 "#{linux_x86_64}"),
}

replacements.each do |pattern, replacement|
  content.sub!(pattern, replacement) or abort "Failed to update #{pattern}"
end

File.write(formula, content)
RUBY

echo "Updated ${FORMULA} to ${LATEST}"
echo "  Darwin arm64:  ${DARWIN_ARM64}"
echo "  Darwin x86_64: ${DARWIN_X86_64}"
echo "  Linux arm64:   ${LINUX_ARM64}"
echo "  Linux x86_64:  ${LINUX_X86_64}"
