# shellcheck shell=bash
# nixpi CLI body — sourced by the Nix-generated wrapper which sets:
#   PI_BIN, PI_DIR, REPO_ROOT, EXTENSIONS_MANIFEST
# Dependencies (jq, nodejs, pi) are provided via runtimeInputs.

is_pinned_npm_source() {
  local source="$1"
  [[ "$source" =~ ^npm:(@[^/]+/[^@]+|[^@/][^@]*)@[0-9]+\.[0-9]+\.[0-9]+([-.+][0-9A-Za-z.-]+)*$ ]]
}

normalize_npm_source() {
  local pkg="$1"
  case "$pkg" in
    npm:*) printf '%s\n' "$pkg" ;;
    *) printf 'npm:%s\n' "$pkg" ;;
  esac
}

require_pinned_source() {
  local source="$1"
  if ! is_pinned_npm_source "$source"; then
    echo "nixpi npm install requires pinned npm package versions." >&2
    echo "Use pinned npm sources (exact versions), e.g. npm:@scope/extension@1.2.3." >&2
    exit 2
  fi
}

ensure_manifest_exists() {
  mkdir -p "$(dirname "$EXTENSIONS_MANIFEST")"
  if [ ! -f "$EXTENSIONS_MANIFEST" ]; then
    cat > "$EXTENSIONS_MANIFEST" <<'JSONEOF'
{
  "packages": []
}
JSONEOF
  fi
}

validate_manifest_sources() {
  local source
  while IFS= read -r source; do
    [ -n "$source" ] || continue
    if ! is_pinned_npm_source "$source"; then
      echo "nixpi extension manifest contains unpinned source: $source" >&2
      echo "Use pinned npm sources (exact versions), e.g. npm:@scope/extension@1.2.3." >&2
      exit 2
    fi
  done < <(jq -r '.packages[]?' "$EXTENSIONS_MANIFEST")
}

sync_manifest_to_profile() {
  if [ ! -f "$EXTENSIONS_MANIFEST" ]; then
    echo "nixpi npm sync requires infra/pi/extensions/packages.json." >&2
    exit 2
  fi

  validate_manifest_sources

  manifest_json="$(jq -c '{ packages: (.packages // []) }' "$EXTENSIONS_MANIFEST")"
  mkdir -p "$PI_DIR"

  tmp_settings="$(mktemp)"
  if [ -f "$PI_DIR/settings.json" ]; then
    jq --argjson manifest "$manifest_json" '
      .packages = ($manifest.packages // [])
    ' "$PI_DIR/settings.json" > "$tmp_settings"
  else
    jq --argjson manifest "$manifest_json" --arg skillsPath "$REPO_ROOT/infra/pi/skills" -n '
      {
        skills: [$skillsPath],
        packages: ($manifest.packages // [])
      }
    ' > "$tmp_settings"
  fi
  mv "$tmp_settings" "$PI_DIR/settings.json"

  export PI_CODING_AGENT_DIR="$PI_DIR"
  mapfile -t manifest_packages < <(jq -r '.packages[]?' "$EXTENSIONS_MANIFEST")
  for source in "${manifest_packages[@]}"; do
    "$PI_BIN" install "$source"
  done

  echo "Synced extension sources from $EXTENSIONS_MANIFEST"
}

confirm_action() {
  local token="$1"
  local prompt="$2"
  local reply

  echo "$prompt" >&2
  printf "Type %s to continue: " "$token" >&2
  IFS= read -r reply
  if [ "$reply" != "$token" ]; then
    echo "Cancelled." >&2
    exit 2
  fi
}

run_evolve() {
  local assume_yes="$1"
  local verify_script_relative="./scripts/verify-nixpi.sh"
  local verify_script="$REPO_ROOT/scripts/verify-nixpi.sh"

  if [ "$assume_yes" -ne 1 ]; then
    echo "nixpi evolve requires explicit confirmation." >&2
    echo "About to run: sudo nixos-rebuild switch --flake ." >&2
    confirm_action "EVOLVE" "This applies system-level NixOS changes from $REPO_ROOT."
  fi

  (
    cd "$REPO_ROOT" || exit
    sudo nixos-rebuild switch --flake .
  )

  if [ -x "$verify_script" ]; then
    echo "Running $verify_script_relative"
    if ! "$verify_script"; then
      echo "Rebuild validation failed; rolling back..." >&2
      (
        cd "$REPO_ROOT" || exit
        sudo nixos-rebuild switch --rollback
      )
      exit 1
    fi
  else
    echo "Warning: missing executable $verify_script_relative; skipping post-apply validation." >&2
  fi

  echo "nixpi evolve completed successfully."
}

run_rollback() {
  local assume_yes="$1"

  if [ "$assume_yes" -ne 1 ]; then
    echo "nixpi rollback requires explicit confirmation." >&2
    echo "About to run: sudo nixos-rebuild switch --rollback" >&2
    confirm_action "ROLLBACK" "This activates the previous NixOS generation."
  fi

  (
    cd "$REPO_ROOT" || exit
    sudo nixos-rebuild switch --rollback
  )

  echo "nixpi rollback completed successfully."
}

case "${1-}" in
  --help|-h|help)
    cat <<'EOF'
nixpi - primary CLI for the Nixpi assistant

Usage:
  nixpi [args...]                            Run Nixpi (single instance)
  nixpi evolve [--yes]                       Apply NixOS config with validation + auto-rollback on failed checks
  nixpi rollback [--yes]                     Roll back to the previous NixOS generation
  nixpi npm install <package@x.y.z...>       Install pinned extension(s) and track them in-repo
  nixpi npm sync                             Rebuild profile extension state from manifest
  nixpi setup                                 Run conversational setup (first-time or reconfigure)
  nixpi help                                 Show this help

Notes:
  - `nixpi` uses PI_CODING_AGENT_DIR from nixpi.piDir.
  - `nixpi evolve` runs `sudo nixos-rebuild switch --flake .` from nixpi.repoRoot.
  - `nixpi rollback` runs `sudo nixos-rebuild switch --rollback` from nixpi.repoRoot.
  - `nixpi npm install` stores package sources in infra/pi/extensions/packages.json.
  - Extension sources must be pinned (exact versions), e.g. npm:@scope/extension@1.2.3.
EOF
    ;;
  evolve)
    shift || true
    assume_yes=0
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --yes) assume_yes=1 ;;
        *)
          echo "Unknown nixpi evolve option: $1" >&2
          echo "Usage: nixpi evolve [--yes]" >&2
          exit 2
          ;;
      esac
      shift
    done
    run_evolve "$assume_yes"
    ;;
  rollback)
    shift || true
    assume_yes=0
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --yes) assume_yes=1 ;;
        *)
          echo "Unknown nixpi rollback option: $1" >&2
          echo "Usage: nixpi rollback [--yes]" >&2
          exit 2
          ;;
      esac
      shift
    done
    run_rollback "$assume_yes"
    ;;
  npm)
    shift || true

    case "${1-}" in
      install)
        shift || true

        if [ "$#" -eq 0 ]; then
          echo "nixpi npm install requires at least one package name." >&2
          echo "Usage: nixpi npm install <package@x.y.z...>" >&2
          exit 2
        fi

        ensure_manifest_exists
        validate_manifest_sources
        export PI_CODING_AGENT_DIR="$PI_DIR"

        for pkg in "$@"; do
          source="$(normalize_npm_source "$pkg")"
          require_pinned_source "$source"

          "$PI_BIN" install "$source"

          tmp_manifest="$(mktemp)"
          jq --arg pkg "$source" '
            .packages = ((.packages // []) + [$pkg] | unique)
          ' "$EXTENSIONS_MANIFEST" > "$tmp_manifest"
          mv "$tmp_manifest" "$EXTENSIONS_MANIFEST"
        done

        echo "Saved extension sources to $EXTENSIONS_MANIFEST"
        ;;
      sync)
        sync_manifest_to_profile
        ;;
      *)
        echo "Unknown nixpi npm subcommand: ${1-}" >&2
        echo "Usage: nixpi npm <install|sync> ..." >&2
        exit 2
        ;;
    esac
    ;;
  setup)
    shift || true
    export PI_CODING_AGENT_DIR="$PI_DIR"
    exec "$PI_BIN" --skill "$REPO_ROOT/infra/pi/skills/install-nixpi/SKILL.md" "$@"
    ;;
  *)
    export PI_CODING_AGENT_DIR="$PI_DIR"
    exec "$PI_BIN" "$@"
    ;;
esac
