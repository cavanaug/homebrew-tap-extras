# Shared --min-age-days / --help parsing for update scripts.
# Usage: source "$SCRIPT_DIR/lib/args.sh" && parse_min_age_days "$@"

parse_min_age_days() {
  MIN_AGE_DAYS=2

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
}
