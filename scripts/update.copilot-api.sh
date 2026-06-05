#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: update.copilot-api.sh [--min-age-days DAYS] [--help]

Update Formula/copilot-api.rb to the latest eligible GitHub release (npm tarball).

Options:
  --min-age-days DAYS  Minimum release age in days before it can be selected
  --help               Show this help message and exit
EOF
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/args.sh
source "$SCRIPT_DIR/lib/args.sh"
parse_min_age_days "$@"

ROOT="$(git rev-parse --show-toplevel)"
FORMULA="${ROOT}/Formula/copilot-api.rb"
REPO="caozhiyuan/copilot-api"

CURRENT=$(python3 -c '
import re, sys
content = open(sys.argv[1], encoding="utf-8").read()
match = re.search(
    r"registry\.npmjs\.org/@jeffreycao/copilot-api/-/copilot-api-([0-9][0-9.]*)\.tgz",
    content,
)
if not match:
    raise SystemExit(f"Failed to extract current version from {sys.argv[1]}")
print(match.group(1))
' "$FORMULA")

eval "$(python3 "$SCRIPT_DIR/select-release.py" \
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

if [ "$LATEST" = "$CURRENT" ]; then
    echo "Already at latest eligible: v${CURRENT}"
    exit 0
fi

TARBALL="https://registry.npmjs.org/@jeffreycao/copilot-api/-/copilot-api-${LATEST}.tgz"
echo "Computing sha256 for ${TARBALL} ..."
SHA256=$(curl -fsSL "$TARBALL" | shasum -a 256 | awk '{print $1}')

sed -i.bak \
  -e "s|/copilot-api-[0-9][0-9.]*\.tgz|/copilot-api-${LATEST}.tgz|" \
  -e "s|sha256 \"[a-f0-9]\{64\}\"|sha256 \"${SHA256}\"|" \
  "$FORMULA"
rm -f "${FORMULA}.bak"

echo "Bumped v${CURRENT} → v${LATEST} (sha256: ${SHA256})"
