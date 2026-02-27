#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="scripts/bootstrap-fresh-nixos.sh"
DOC="docs/runtime/REINSTALL.md"
README="README.md"
DOCS_HOME="docs/README.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"
SKILL="infra/pi/skills/install-nixpi/SKILL.md"
BASE="infra/nixos/base.nix"
SCRIPT_CONTENT="$(cat "$SCRIPT" 2>/dev/null || true)"
DOC_CONTENT="$(<"$DOC")"
README_CONTENT="$(<"$README")"
DOCS_HOME_CONTENT="$(<"$DOCS_HOME")"
OPERATING_CONTENT="$(<"$OPERATING")"
BASE_CONTENT="$(<"$BASE")"

# Happy path: bootstrap clones, refreshes hardware, and defaults to guided Pi install.
assert_executable "$SCRIPT"
assert_file_contains "$SCRIPT" 'nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git'
assert_file_contains "$SCRIPT" './scripts/add-host.sh --force "$(hostname)"'
assert_file_contains "$SCRIPT" 'INSTALL_SKILL="$TARGET_DIR/infra/pi/skills/install-nixpi/SKILL.md"'
assert_file_contains "$SCRIPT" 'pi --skill "$INSTALL_SKILL" "$INSTALL_PROMPT"'
assert_file_contains "$SCRIPT" 'shell nixpkgs#nodejs_22 -c npx --yes @mariozechner/pi-coding-agent@0.55.1 --skill "$INSTALL_SKILL" "$INSTALL_PROMPT"'

# Failure path: clear guard for non-repo target collisions and unknown options.
assert_file_contains "$SCRIPT" 'exists but is not a git repository'
assert_file_contains "$SCRIPT" 'usage: $0 [--dry-run] [--non-interactive] [target-dir]'
assert_file_contains "$SCRIPT" 'error: unknown option:'

# System default: flakes + nix-command are enabled declaratively system-wide.
assert_file_contains "$BASE" 'nix.settings.experimental-features = [ "nix-command" "flakes" ];'
assert_not_contains "$BASE_CONTENT" 'nix.settings.experimental-features = [ ];'

# Edge case: idempotent rerun should skip cloning and avoid git dependency checks.
assert_file_contains "$SCRIPT" 'Repository already present, skipping clone'
assert_not_contains "$SCRIPT_CONTENT" 'command -v git'

# Optional mode: non-interactive apply is available but not default.
assert_file_contains "$SCRIPT" 'NON_INTERACTIVE=0'
assert_file_contains "$SCRIPT" 'if [ "$NON_INTERACTIVE" -eq 1 ]; then'
assert_file_contains "$SCRIPT" 'FLAKE_REF="path:$TARGET_DIR#$(hostname)"'
assert_file_contains "$SCRIPT" 'sudo env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake "$FLAKE_REF"'
assert_file_contains "$SCRIPT" 'bootstrap-fresh-nixos: non-interactive apply finished'

# Dry-run mode: preview commands and avoid mutating system.
assert_file_contains "$SCRIPT" 'DRY_RUN=0'
assert_file_contains "$SCRIPT" 'if [ "$DRY_RUN" -eq 1 ]; then'
assert_file_contains "$SCRIPT" 'DRY RUN: would refresh host config with ./scripts/add-host.sh --force "$(hostname)"'
assert_file_contains "$SCRIPT" 'bootstrap-fresh-nixos: dry run complete'

# Skill regression: install skill exists and follows skill naming conventions.
assert_file_contains "$SKILL" 'name: install-nixpi'
assert_file_contains "$SKILL" 'description:'

# Docs regression: reinstall flow points to clone + bootstrap + Pi install skill guidance.
assert_file_contains "$DOC" './scripts/bootstrap-fresh-nixos.sh'
assert_file_contains "$DOC" 'install-nixpi'
assert_file_contains "$README" 'install-nixpi'
assert_file_contains "$DOCS_HOME" 'Reinstall on Fresh NixOS'
assert_file_contains "$OPERATING" 'REINSTALL.md'

# Edge docs: include one-liner and optional non-interactive/dry-run mode.
assert_file_contains "$README" 'nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi && cd ~/Nixpi && ./scripts/bootstrap-fresh-nixos.sh'
assert_file_contains "$DOC" 'nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git -c git clone https://github.com/alexradunet/nixpi.git Nixpi && cd ~/Nixpi && ./scripts/bootstrap-fresh-nixos.sh'
assert_file_contains "$DOC" './scripts/bootstrap-fresh-nixos.sh --non-interactive'
assert_file_contains "$DOC" './scripts/bootstrap-fresh-nixos.sh --dry-run'

# No stale split-installer docs references should remain.
assert_not_contains "$README_CONTENT" 'REINSTALL_MINIMAL_HEADLESS.md'
assert_not_contains "$DOCS_HOME_CONTENT" 'REINSTALL_MINIMAL_HEADLESS.md'
assert_not_contains "$OPERATING_CONTENT" 'REINSTALL_MINIMAL_HEADLESS.md'
assert_not_contains "$README_CONTENT" 'REINSTALL_MINIMAL.md'
assert_not_contains "$DOCS_HOME_CONTENT" 'REINSTALL_MINIMAL.md'
assert_not_contains "$OPERATING_CONTENT" 'REINSTALL_MINIMAL.md'
assert_not_contains "$DOC_CONTENT" 'headless'

echo "PASS: bootstrap automation + guided/non-interactive/dry-run install workflow"