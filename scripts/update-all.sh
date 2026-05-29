#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MIN_AGE_DAYS=2

usage() {
  cat <<'EOF'
Usage: update-all.sh [--min-age-days DAYS] [--help]

Run all updater scripts in the scripts directory.

Options:
  --min-age-days DAYS  Minimum release age in days passed to each updater
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

mapfile -t UPDATE_SCRIPTS < <(
  for script in "$SCRIPT_DIR"/update.*.sh; do
    [ -f "$script" ] || continue
    printf '%s\n' "$script"
  done | sort
)

if [ "${#UPDATE_SCRIPTS[@]}" -eq 0 ]; then
  echo "No updater scripts found in $SCRIPT_DIR"
  exit 0
fi

declare -a PASSED=()
declare -a FAILED=()

for script in "${UPDATE_SCRIPTS[@]}"; do
  name="$(basename "$script")"
  echo "==> Running ${name} (--min-age-days=${MIN_AGE_DAYS})"

  if output="$($script --min-age-days="$MIN_AGE_DAYS" 2>&1)"; then
    PASSED+=("$name")
    if [ -n "$output" ]; then
      printf '%s\n' "$output"
    fi
    echo "==> ${name}: OK"
  else
    FAILED+=("$name")
    if [ -n "$output" ]; then
      printf '%s\n' "$output"
    fi
    echo "==> ${name}: FAILED"
  fi

  echo
done

echo "Summary: ${#PASSED[@]} succeeded, ${#FAILED[@]} failed"

if [ "${#PASSED[@]}" -gt 0 ]; then
  printf 'Succeeded: %s\n' "$(IFS=', '; echo "${PASSED[*]}")"
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
  printf 'Failed: %s\n' "$(IFS=', '; echo "${FAILED[*]}")"
  exit 1
fi
