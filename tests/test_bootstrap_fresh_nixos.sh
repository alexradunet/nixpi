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

# Happy path: bootstrap clones repo and runs setup wizard.
assert_executable "$SCRIPT"
assert_file_contains "$SCRIPT" 'NIXPI_REPO="https://github.com/alexradunet/nixpi.git"'
assert_file_contains "$SCRIPT" 'git clone "$NIXPI_REPO" "$BOOTSTRAP_DIR"'
assert_file_contains "$SCRIPT" 'nixpi-setup.sh'

# Failure path: clear guard for unknown options and root requirement.
assert_file_contains "$SCRIPT" 'usage: sudo $0 [--dry-run] [--non-interactive] [target-dir]'
assert_file_contains "$SCRIPT" 'error: unknown option:'

# System default: flakes + nix-command are enabled declaratively system-wide.
assert_file_contains "$BASE" 'nix.settings.experimental-features = [ "nix-command" "flakes" ];'
assert_not_contains "$BASE_CONTENT" 'nix.settings.experimental-features = [ ];'

# Edge case: idempotent rerun should skip cloning when repo already present.
assert_file_contains "$SCRIPT" '$BOOTSTRAP_DIR/.git'
assert_not_contains "$SCRIPT_CONTENT" 'command -v git'

# Optional mode: non-interactive apply is available but not default.
assert_file_contains "$SCRIPT" 'NON_INTERACTIVE=0'
assert_file_contains "$SCRIPT" 'nixos-rebuild switch --flake'
assert_file_contains "$SCRIPT" 'bootstrap-fresh-nixos: complete!'

# Dry-run mode: preview commands and avoid mutating system.
assert_file_contains "$SCRIPT" 'DRY_RUN=0'
assert_file_contains "$SCRIPT" 'DRY RUN: would clone'
assert_file_contains "$SCRIPT" 'DRY RUN: would nixos-rebuild switch'

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