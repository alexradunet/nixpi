#!/usr/bin/env bash
set -euo pipefail

# nixpi-object — CRUD tool for flat-file objects with YAML frontmatter.
#
# Object files are Markdown with YAML frontmatter stored under NIXPI_OBJECTS_DIR.
# Each object type gets its own subdirectory (e.g. journal/, task/, note/).
#
# Requires: yq (yq-go), jq
#
# Usage:
#   nixpi-object create <type> <slug> [--field=value ...]
#   nixpi-object read <type> <slug>
#   nixpi-object list <type> [--status=X --project=Y --area=Z --tag=T]
#   nixpi-object list --all [--status=X --project=Y --area=Z --tag=T]
#   nixpi-object update <type> <slug> --field=value ...
#   nixpi-object search <pattern>
#   nixpi-object link <type/slug> <type/slug>

OBJECTS_DIR="${NIXPI_OBJECTS_DIR:-${HOME}/Nixpi/data/objects}"

die() {
  echo "Error: $*" >&2
  exit 1
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

object_path() {
  local type="$1" slug="$2"
  echo "${OBJECTS_DIR}/${type}/${slug}.md"
}

# Parse --key=value arguments into associative array.
parse_fields() {
  local -n _fields="$1"
  shift
  for arg in "$@"; do
    case "$arg" in
      --*=*)
        local key="${arg%%=*}"
        key="${key#--}"
        local value="${arg#*=}"
        # Reject keys that would create nested YAML (contain dots or invalid chars)
        if [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
          die "invalid field name: '$key' (must match [a-zA-Z_][a-zA-Z0-9_-]*)"
        fi
        _fields["$key"]="$value"
        ;;
      *)
        die "unexpected argument: $arg"
        ;;
    esac
  done
}

# Read a single frontmatter value from a file using yq.
read_frontmatter_value() {
  local filepath="$1" key="$2"
  yq --front-matter=extract ".$key" "$filepath" 2>/dev/null | grep -v '^null$'
}

# Read all links from frontmatter using yq.
read_frontmatter_links() {
  local filepath="$1"
  yq --front-matter=extract '.links[]' "$filepath" 2>/dev/null || true
}

# Write YAML frontmatter + body to a file using jq (build JSON) + yq (convert to YAML).
write_object() {
  local filepath="$1"
  local -n _fm="$2"

  # Collect keys: priority order first, then remaining alphabetically.
  local -a ordered_keys=()
  local -a priority_keys=(type slug title status priority project area)
  local -A seen=()

  for k in "${priority_keys[@]}"; do
    if [[ -v "_fm[$k]" ]]; then
      ordered_keys+=("$k")
      seen["$k"]=1
    fi
  done

  local -a rest=()
  for k in "${!_fm[@]}"; do
    [[ -v "seen[$k]" ]] || rest+=("$k")
  done
  if [[ ${#rest[@]} -gt 0 ]]; then
    IFS=$'\n' rest=($(sort <<<"${rest[*]}")); unset IFS 2>/dev/null || true
    for k in "${rest[@]}"; do
      [[ -n "$k" ]] && ordered_keys+=("$k")
    done
  fi

  # Build JSON via jq --arg per key (safe for tabs/newlines in values), convert to YAML via yq.
  local yaml
  local -a jq_args=()
  local jq_expr="."
  local i=0

  for k in "${ordered_keys[@]}"; do
    local v="${_fm[$k]}"
    jq_args+=(--arg "k_${i}" "$k" --arg "v_${i}" "$v")
    i=$((i + 1))
  done

  # Build the jq expression that constructs the ordered object
  local jq_build="null"
  for ((j=0; j<i; j++)); do
    local k="${ordered_keys[$j]}"
    if [[ "$k" == "tags" || "$k" == "links" ]]; then
      jq_build="${jq_build} | . + {(\$k_${j}): (\$v_${j} | split(\",\") | map(gsub(\"^\\\\s+|\\\\s+$\"; \"\")))}"
    else
      jq_build="${jq_build} | . + {(\$k_${j}): \$v_${j}}"
    fi
  done

  yaml=$(jq -n "${jq_args[@]}" "${jq_build} | del(.. | nulls)" | yq -P)

  {
    echo "---"
    printf '%s\n' "$yaml"
    echo "---"
    echo ""
    if [[ -v "_fm[title]" ]]; then
      echo "# ${_fm[title]}"
      echo ""
    fi
  } > "$filepath"
}

cmd_create() {
  local type="${1:-}"
  local slug="${2:-}"
  shift 2 2>/dev/null || true

  [[ -z "$type" ]] && die "usage: nixpi-object create <type> <slug> [--field=value ...]"
  [[ -z "$slug" ]] && die "usage: nixpi-object create <type> <slug> [--field=value ...]"

  local filepath
  filepath="$(object_path "$type" "$slug")"

  [[ -f "$filepath" ]] && die "object already exists: ${type}/${slug}"

  mkdir -p "$(dirname "$filepath")"

  local -A fields=()
  if [[ $# -gt 0 ]]; then
    parse_fields fields "$@"
  fi

  fields[type]="$type"
  fields[slug]="$slug"
  fields[created]="$(now_iso)"
  fields[modified]="$(now_iso)"

  write_object "$filepath" fields

  echo "created ${type}/${slug}"
}

cmd_read() {
  local type="${1:-}"
  local slug="${2:-}"

  [[ -z "$type" ]] && die "usage: nixpi-object read <type> <slug>"
  [[ -z "$slug" ]] && die "usage: nixpi-object read <type> <slug>"

  local filepath
  filepath="$(object_path "$type" "$slug")"

  [[ -f "$filepath" ]] || die "object not found: ${type}/${slug}"

  cat "$filepath"
}

cmd_list() {
  local type=""
  local list_all=0
  local -A filters=()

  local -a positional=()
  for arg in "$@"; do
    case "$arg" in
      --all)
        list_all=1
        ;;
      --status=*|--project=*|--area=*|--tag=*)
        local key="${arg%%=*}"
        key="${key#--}"
        filters["$key"]="${arg#*=}"
        ;;
      -*)
        die "unknown option: $arg"
        ;;
      *)
        positional+=("$arg")
        ;;
    esac
  done

  if [[ ${#positional[@]} -gt 0 ]]; then
    type="${positional[0]}"
  fi

  [[ -z "$type" && "$list_all" -eq 0 ]] && die "usage: nixpi-object list <type> [--status=X ...] or nixpi-object list --all"

  local -a search_dirs=()
  if [[ "$list_all" -eq 1 ]]; then
    for dir in "${OBJECTS_DIR}"/*/; do
      [[ -d "$dir" ]] && search_dirs+=("$dir")
    done
  else
    local dir="${OBJECTS_DIR}/${type}/"
    [[ -d "$dir" ]] && search_dirs+=("$dir")
  fi

  for dir in "${search_dirs[@]}"; do
    for filepath in "${dir}"*.md; do
      [[ -f "$filepath" ]] || continue

      local match=1
      for fkey in "${!filters[@]}"; do
        local fval="${filters[$fkey]}"
        if [[ "$fkey" == "tag" ]]; then
          if ! yq --front-matter=extract '.tags[]' "$filepath" 2>/dev/null | grep -qF -- "$fval"; then
            match=0
            break
          fi
        else
          local actual
          actual="$(read_frontmatter_value "$filepath" "$fkey")"
          if [[ "$actual" != "$fval" ]]; then
            match=0
            break
          fi
        fi
      done

      if [[ "$match" -eq 1 ]]; then
        local obj_slug obj_type obj_title
        obj_slug="$(read_frontmatter_value "$filepath" "slug")"
        obj_type="$(read_frontmatter_value "$filepath" "type")"
        obj_title="$(read_frontmatter_value "$filepath" "title")"
        if [[ -n "$obj_title" ]]; then
          echo "${obj_type}/${obj_slug}  ${obj_title}"
        else
          echo "${obj_type}/${obj_slug}"
        fi
      fi
    done
  done
}

cmd_update() {
  local type="${1:-}"
  local slug="${2:-}"
  shift 2 2>/dev/null || true

  [[ -z "$type" ]] && die "usage: nixpi-object update <type> <slug> --field=value ..."
  [[ -z "$slug" ]] && die "usage: nixpi-object update <type> <slug> --field=value ..."
  [[ $# -eq 0 ]] && die "usage: nixpi-object update <type> <slug> --field=value ..."

  local filepath
  filepath="$(object_path "$type" "$slug")"

  [[ -f "$filepath" ]] || die "object not found: ${type}/${slug}"

  local -A updates=()
  parse_fields updates "$@"
  updates[modified]="$(now_iso)"

  for key in "${!updates[@]}"; do
    local val="${updates[$key]}"
    if [[ "$key" == "tags" || "$key" == "links" ]]; then
      YQ_VAL="$val" yq --front-matter=process -i ".${key} = (env(YQ_VAL) | split(\",\") | map(sub(\"^\\s+\"; \"\") | sub(\"\\s+$\"; \"\")))" "$filepath"
    else
      YQ_VAL="$val" yq --front-matter=process -i ".${key} = env(YQ_VAL)" "$filepath"
    fi
  done
}

cmd_search() {
  local pattern="${1:-}"
  [[ -z "$pattern" ]] && die "usage: nixpi-object search <pattern>"

  local -A seen=()
  while IFS=: read -r filepath _; do
    [[ -f "$filepath" ]] || continue
    local obj_slug obj_type
    obj_slug="$(read_frontmatter_value "$filepath" "slug")"
    obj_type="$(read_frontmatter_value "$filepath" "type")"
    local key="${obj_type}/${obj_slug}"
    if [[ ! -v "seen[$key]" ]]; then
      seen["$key"]=1
      local obj_title
      obj_title="$(read_frontmatter_value "$filepath" "title")"
      if [[ -n "$obj_title" ]]; then
        echo "${key}  ${obj_title}"
      else
        echo "${key}"
      fi
    fi
  done < <(grep -rl "$pattern" "${OBJECTS_DIR}" 2>/dev/null || true)
}

cmd_link() {
  local ref_a="${1:-}"
  local ref_b="${2:-}"

  [[ -z "$ref_a" || -z "$ref_b" ]] && die "usage: nixpi-object link <type/slug> <type/slug>"

  [[ "$ref_a" == */* ]] || die "invalid reference format: '$ref_a' (expected type/slug)"
  [[ "$ref_b" == */* ]] || die "invalid reference format: '$ref_b' (expected type/slug)"

  local type_a="${ref_a%%/*}" slug_a="${ref_a#*/}"
  local type_b="${ref_b%%/*}" slug_b="${ref_b#*/}"

  local path_a path_b
  path_a="$(object_path "$type_a" "$slug_a")"
  path_b="$(object_path "$type_b" "$slug_b")"

  [[ -f "$path_a" ]] || die "object not found: ${ref_a}"
  [[ -f "$path_b" ]] || die "object not found: ${ref_b}"

  add_link_to_file() {
    local filepath="$1" link_ref="$2"
    if yq --front-matter=extract '.links[]' "$filepath" 2>/dev/null | grep -qF -- "$link_ref"; then
      return 0
    fi
    YQ_REF="$link_ref" yq --front-matter=process -i '.links = (.links // []) + [env(YQ_REF)]' "$filepath"
  }

  add_link_to_file "$path_a" "$ref_b"
  add_link_to_file "$path_b" "$ref_a"

  echo "linked ${ref_a} <-> ${ref_b}"
}

# Main dispatch.
cmd="${1:-}"
shift 2>/dev/null || true

case "$cmd" in
  create)  cmd_create "$@" ;;
  read)    cmd_read "$@" ;;
  list)    cmd_list "$@" ;;
  update)  cmd_update "$@" ;;
  search)  cmd_search "$@" ;;
  link)    cmd_link "$@" ;;
  "")      die "usage: nixpi-object <create|read|list|update|search|link> ..." ;;
  *)       die "unknown command: $cmd" ;;
esac
