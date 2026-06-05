#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: update.mermaid-ascii.sh [--min-age-days DAYS] [--help]

Update Formula/mermaid-ascii.rb to the latest eligible GitHub release.

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
FORMULA="${ROOT}/Formula/mermaid-ascii.rb"
REPO="AlexanderGrooff/mermaid-ascii"

MERMAID_ASSETS=(
  "DARWIN_ARM64=mermaid-ascii_Darwin_arm64.tar.gz"
  "DARWIN_X86_64=mermaid-ascii_Darwin_x86_64.tar.gz"
  "LINUX_ARM64=mermaid-ascii_Linux_arm64.tar.gz"
  "LINUX_X86_64=mermaid-ascii_Linux_x86_64.tar.gz"
)

CURRENT=$(python3 -c '
import re, sys
match = re.search(r"^\s*version\s+\"([^\"]+)\"", open(sys.argv[1], encoding="utf-8").read(), re.M)
if not match:
    raise SystemExit(f"Failed to extract version from {sys.argv[1]}")
print(match.group(1))
' "$FORMULA")

SELECT_ARGS=(python3 "$SCRIPT_DIR/select-release.py" --repo "$REPO" --min-age-days "$MIN_AGE_DAYS")
for asset in "${MERMAID_ASSETS[@]}"; do
  SELECT_ARGS+=(--asset "$asset")
done
eval "$("${SELECT_ARGS[@]}")"

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

python3 - "$FORMULA" "$LATEST" "$DARWIN_ARM64" "$DARWIN_X86_64" "$LINUX_ARM64" "$LINUX_X86_64" <<'PY'
import re
import sys

formula, version, darwin_arm64, darwin_x86_64, linux_arm64, linux_x86_64 = sys.argv[1:7]
content = open(formula, encoding="utf-8").read()

updated, count = re.subn(
    r'^\s*version\s+"[^"]+"',
    f'  version "{version}"',
    content,
    count=1,
    flags=re.MULTILINE,
)
if count != 1:
    raise SystemExit("Failed to update version line")

for suffix, digest in (
    ("Darwin_arm64", darwin_arm64),
    ("Darwin_x86_64", darwin_x86_64),
    ("Linux_arm64", linux_arm64),
    ("Linux_x86_64", linux_x86_64),
):
    pattern = rf'mermaid-ascii_{re.escape(suffix)}\.tar\.gz"\n\s+sha256 "[a-f0-9]{{64}}"'
    replacement = f'mermaid-ascii_{suffix}.tar.gz"\n      sha256 "{digest}"'
    updated, count = re.subn(pattern, replacement, updated, count=1)
    if count != 1:
        raise SystemExit(f"Failed to update sha256 for mermaid-ascii_{suffix}.tar.gz")

with open(formula, "w", encoding="utf-8") as handle:
    handle.write(updated)
PY

echo "Updated ${FORMULA} to ${LATEST}"
echo "  Darwin arm64:  ${DARWIN_ARM64}"
echo "  Darwin x86_64: ${DARWIN_X86_64}"
echo "  Linux arm64:   ${LINUX_ARM64}"
echo "  Linux x86_64:  ${LINUX_X86_64}"
