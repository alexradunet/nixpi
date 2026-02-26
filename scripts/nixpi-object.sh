#!/usr/bin/env bash
set -euo pipefail

# nixpi-object — CRUD tool for flat-file objects with YAML frontmatter.
#
# Object files are Markdown with YAML frontmatter stored under NIXPI_OBJECTS_DIR.
# Each object type gets its own subdirectory (e.g. journal/, task/, note/).
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
# Usage: parse_fields dest_array_name "$@"
parse_fields() {
  local -n _fields="$1"
  shift
  for arg in "$@"; do
    case "$arg" in
      --*=*)
        local key="${arg%%=*}"
        key="${key#--}"
        local value="${arg#*=}"
        _fields["$key"]="$value"
        ;;
      *)
        die "unexpected argument: $arg"
        ;;
    esac
  done
}

# Write YAML frontmatter + empty body to a file.
write_object() {
  local filepath="$1"
  shift
  # Remaining args are key=value pairs (already parsed).
  local -n _fm="$1"
  shift

  {
    echo "---"
    # Write fields in a stable order: type, slug, title first, then alphabetical.
    local -a priority_keys=(type slug title status priority project area)
    local -A written=()

    for key in "${priority_keys[@]}"; do
      if [[ -v "_fm[$key]" ]]; then
        local val="${_fm[$key]}"
        if [[ "$key" == "tags" ]]; then
          echo "tags:"
          IFS=',' read -ra tag_arr <<< "$val"
          for t in "${tag_arr[@]}"; do
            echo "  - ${t}"
          done
        elif [[ "$key" == "links" ]]; then
          echo "links:"
          IFS=',' read -ra link_arr <<< "$val"
          for l in "${link_arr[@]}"; do
            echo "  - ${l}"
          done
        else
          echo "${key}: ${val}"
        fi
        written["$key"]=1
      fi
    done

    # Write remaining keys alphabetically.
    local -a remaining_keys=()
    for key in "${!_fm[@]}"; do
      if [[ ! -v "written[$key]" ]]; then
        remaining_keys+=("$key")
      fi
    done
    IFS=$'\n' sorted=($(sort <<< "${remaining_keys[*]}")); unset IFS 2>/dev/null || true

    for key in "${sorted[@]}"; do
      [[ -z "$key" ]] && continue
      local val="${_fm[$key]}"
      if [[ "$key" == "tags" ]]; then
        echo "tags:"
        IFS=',' read -ra tag_arr <<< "$val"
        for t in "${tag_arr[@]}"; do
          echo "  - ${t}"
        done
      elif [[ "$key" == "links" ]]; then
        echo "links:"
        IFS=',' read -ra link_arr <<< "$val"
        for l in "${link_arr[@]}"; do
          echo "  - ${l}"
        done
      else
        echo "${key}: ${val}"
      fi
    done

    echo "---"
    echo ""
    # Title as markdown heading if present.
    if [[ -v "_fm[title]" ]]; then
      echo "# ${_fm[title]}"
      echo ""
    fi
  } > "$filepath"
}

# Read frontmatter value from a file.
read_frontmatter_value() {
  local filepath="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$filepath" | grep -E "^${key}:" | head -1 | sed "s/^${key}: *//"
}

# Read all links from frontmatter.
read_frontmatter_links() {
  local filepath="$1"
  sed -n '/^---$/,/^---$/{ /^links:/,/^[^ -]/{ /^  - /{ s/^  - //; p; } } }' "$filepath"
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

  # Set mandatory fields.
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

  # Parse arguments.
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
          # Check if tag is in the tags list.
          if ! sed -n '/^---$/,/^---$/p' "$filepath" | grep -qF -- "- ${fval}"; then
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

  # Always update modified timestamp.
  updates[modified]="$(now_iso)"

  # Read existing file, update frontmatter in-place.
  local in_frontmatter=0
  local frontmatter_started=0
  local -a body_lines=()
  local -a fm_lines=()
  local -A existing_keys=()

  while IFS= read -r line; do
    if [[ "$line" == "---" && "$frontmatter_started" -eq 0 ]]; then
      frontmatter_started=1
      in_frontmatter=1
      continue
    fi
    if [[ "$line" == "---" && "$in_frontmatter" -eq 1 ]]; then
      in_frontmatter=0
      continue
    fi
    if [[ "$in_frontmatter" -eq 1 ]]; then
      # Check if this is a list continuation (starts with "  - ").
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
        fm_lines+=("$line")
        continue
      fi
      local key="${line%%:*}"
      existing_keys["$key"]=1
      if [[ -v "updates[$key]" ]]; then
        local val="${updates[$key]}"
        if [[ "$key" == "tags" ]]; then
          fm_lines+=("tags:")
          IFS=',' read -ra tag_arr <<< "$val"
          for t in "${tag_arr[@]}"; do
            fm_lines+=("  - ${t}")
          done
        elif [[ "$key" == "links" ]]; then
          fm_lines+=("links:")
          IFS=',' read -ra link_arr <<< "$val"
          for l in "${link_arr[@]}"; do
            fm_lines+=("  - ${l}")
          done
        else
          fm_lines+=("${key}: ${val}")
        fi
        unset "updates[$key]"
      else
        fm_lines+=("$line")
      fi
    else
      body_lines+=("$line")
    fi
  done < "$filepath"

  # Append any new fields from updates.
  for key in "${!updates[@]}"; do
    local val="${updates[$key]}"
    if [[ "$key" == "tags" ]]; then
      fm_lines+=("tags:")
      IFS=',' read -ra tag_arr <<< "$val"
      for t in "${tag_arr[@]}"; do
        fm_lines+=("  - ${t}")
      done
    elif [[ "$key" == "links" ]]; then
      fm_lines+=("links:")
      IFS=',' read -ra link_arr <<< "$val"
      for l in "${link_arr[@]}"; do
        fm_lines+=("  - ${l}")
      done
    else
      fm_lines+=("${key}: ${val}")
    fi
  done

  # Write back.
  {
    echo "---"
    for line in "${fm_lines[@]}"; do
      echo "$line"
    done
    echo "---"
    for line in "${body_lines[@]}"; do
      echo "$line"
    done
  } > "$filepath"
}

cmd_search() {
  local pattern="${1:-}"
  [[ -z "$pattern" ]] && die "usage: nixpi-object search <pattern>"

  # Use grep across all object files, output type/slug for matches.
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

  # Validate format: must contain exactly one slash.
  [[ "$ref_a" == */* ]] || die "invalid reference format: '$ref_a' (expected type/slug)"
  [[ "$ref_b" == */* ]] || die "invalid reference format: '$ref_b' (expected type/slug)"

  local type_a="${ref_a%%/*}" slug_a="${ref_a#*/}"
  local type_b="${ref_b%%/*}" slug_b="${ref_b#*/}"

  local path_a path_b
  path_a="$(object_path "$type_a" "$slug_a")"
  path_b="$(object_path "$type_b" "$slug_b")"

  [[ -f "$path_a" ]] || die "object not found: ${ref_a}"
  [[ -f "$path_b" ]] || die "object not found: ${ref_b}"

  # Add link from A -> B if not already present.
  add_link_to_file() {
    local filepath="$1" link_ref="$2"

    # Check if link already exists.
    if sed -n '/^---$/,/^---$/p' "$filepath" | grep -qF -- "- ${link_ref}"; then
      return 0
    fi

    # Check if links section exists.
    if sed -n '/^---$/,/^---$/p' "$filepath" | grep -q "^links:"; then
      # Insert new link after existing links entries.
      # Find the last "  - " line in the links section and add after it.
      local tmpfile
      tmpfile="$(mktemp)"
      local in_fm=0 fm_started=0 in_links=0 link_added=0
      while IFS= read -r line; do
        if [[ "$line" == "---" && "$fm_started" -eq 0 ]]; then
          fm_started=1
          in_fm=1
          echo "$line" >> "$tmpfile"
          continue
        fi
        if [[ "$line" == "---" && "$in_fm" -eq 1 ]]; then
          if [[ "$in_links" -eq 1 && "$link_added" -eq 0 ]]; then
            echo "  - ${link_ref}" >> "$tmpfile"
            link_added=1
          fi
          in_fm=0
          in_links=0
          echo "$line" >> "$tmpfile"
          continue
        fi
        if [[ "$in_fm" -eq 1 ]]; then
          if [[ "$line" == "links:" ]]; then
            in_links=1
            echo "$line" >> "$tmpfile"
            continue
          fi
          if [[ "$in_links" -eq 1 ]]; then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
              echo "$line" >> "$tmpfile"
              continue
            else
              # End of links section — add our link.
              if [[ "$link_added" -eq 0 ]]; then
                echo "  - ${link_ref}" >> "$tmpfile"
                link_added=1
              fi
              in_links=0
              echo "$line" >> "$tmpfile"
              continue
            fi
          fi
        fi
        echo "$line" >> "$tmpfile"
      done < "$filepath"
      mv "$tmpfile" "$filepath"
    else
      # No links section — add one before the closing ---.
      local tmpfile
      tmpfile="$(mktemp)"
      local in_fm=0 fm_started=0
      while IFS= read -r line; do
        if [[ "$line" == "---" && "$fm_started" -eq 0 ]]; then
          fm_started=1
          in_fm=1
          echo "$line" >> "$tmpfile"
          continue
        fi
        if [[ "$line" == "---" && "$in_fm" -eq 1 ]]; then
          echo "links:" >> "$tmpfile"
          echo "  - ${link_ref}" >> "$tmpfile"
          in_fm=0
          echo "$line" >> "$tmpfile"
          continue
        fi
        echo "$line" >> "$tmpfile"
      done < "$filepath"
      mv "$tmpfile" "$filepath"
    fi
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
