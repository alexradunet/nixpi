#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_DIR="$REPO_ROOT/docs/agents/handoffs"
HANDOFF_DIR="$DEFAULT_DIR"
TYPE_FILTER=""
DATE_FILTER=""

usage() {
  cat <<'EOF'
Usage:
  scripts/list-handoffs.sh [--dir <path>] [--type <handoff-type>] [--date <YYYYMMDD>]

Options:
  --dir <path>     Directory containing handoff files (default: docs/agents/handoffs)
  --type <type>    Filter by handoff type (e.g. evolution-request)
  --date <date>    Filter by date prefix YYYYMMDD
  -h, --help       Show this help
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dir)
      [ "$#" -ge 2 ] || fail "missing value for --dir"
      HANDOFF_DIR="$2"
      shift 2
      ;;
    --type)
      [ "$#" -ge 2 ] || fail "missing value for --type"
      TYPE_FILTER="$2"
      shift 2
      ;;
    --date)
      [ "$#" -ge 2 ] || fail "missing value for --date"
      DATE_FILTER="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option '$1'"
      ;;
  esac
done

[ -d "$HANDOFF_DIR" ] || exit 0

mapfile -t files < <(find "$HANDOFF_DIR" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sort -r)

if [ -n "$DATE_FILTER" ]; then
  mapfile -t files < <(printf '%s\n' "${files[@]}" | grep -E "^${DATE_FILTER}-" || true)
fi

if [ -n "$TYPE_FILTER" ]; then
  mapfile -t files < <(printf '%s\n' "${files[@]}" | grep -F -- "-$TYPE_FILTER-" || true)
fi

printf '%s\n' "${files[@]}" | sed '/^$/d'
