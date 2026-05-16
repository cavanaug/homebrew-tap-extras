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
FORMULA="${ROOT}/Formula/mermaid-ascii.rb"
REPO="AlexanderGrooff/mermaid-ascii"
API="https://api.github.com/repos/${REPO}/releases/latest"

current_version() {
  ruby -e 'puts File.read(ARGV[0])[/^\s*version\s+"([^"]+)"/, 1]' "$1"
}

release_data() {
  curl -fsSL "$API"
}

CURRENT="$(current_version "$FORMULA")"
RELEASE_JSON="$(release_data)"

eval "$({
  printf '%s' "$RELEASE_JSON" | ruby -rjson -rtime -e '
    release = JSON.parse(STDIN.read)
    version = release.fetch("tag_name").sub(/^v/, "")
    published_at = Time.iso8601(release.fetch("published_at"))
    min_age_days = Integer(ARGV.fetch(0))
    age_days = ((Time.now.utc - published_at) / 86_400).floor
    assets = release.fetch("assets").to_h do |asset|
      digest = asset["digest"].to_s.sub(/^sha256:/, "")
      [asset.fetch("name"), digest]
    end

    required = {
      darwin_arm64:  "mermaid-ascii_Darwin_arm64.tar.gz",
      darwin_x86_64: "mermaid-ascii_Darwin_x86_64.tar.gz",
      linux_arm64:   "mermaid-ascii_Linux_arm64.tar.gz",
      linux_x86_64:  "mermaid-ascii_Linux_x86_64.tar.gz",
    }

    missing = required.values.reject { |name| assets[name] && !assets[name].empty? }
    abort "Missing release assets: #{missing.join(", ")}" unless missing.empty?

    puts "LATEST=#{version.dump}"
    puts "PUBLISHED_AT=#{release.fetch("published_at").dump}"
    puts "AGE_DAYS=#{age_days}"
    puts "TOO_NEW=#{(age_days < min_age_days).to_s.dump}"
    required.each do |key, name|
      puts "#{key.to_s.upcase}=#{assets.fetch(name).dump}"
    end
  ' "$MIN_AGE_DAYS"
})"

echo "Current version: ${CURRENT}"
echo "Latest version:  ${LATEST}"
echo "Published at:    ${PUBLISHED_AT}"
echo "Age (days):      ${AGE_DAYS}"

if [ "$TOO_NEW" = "true" ]; then
  echo "Skipping update: release is newer than ${MIN_AGE_DAYS} days"
  exit 0
fi

if [ "$LATEST" = "$CURRENT" ]; then
  echo "Already at latest: ${CURRENT}"
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
