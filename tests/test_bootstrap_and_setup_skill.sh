#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BOOTSTRAP="scripts/bootstrap.sh"
SKILL="infra/pi/skills/install-nixpi/SKILL.md"
BASE="infra/nixos/base.nix"
CLI="infra/nixos/scripts/nixpi-cli.sh"
README="README.md"
REINSTALL="docs/runtime/REINSTALL.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"

# --- bootstrap.sh ---

# Happy path: bootstrap exists and is executable.
assert_executable "$BOOTSTRAP"

# Content: contains prepare_os, git clone, pi-coding-agent, install-nixpi/SKILL.md.
assert_file_contains "$BOOTSTRAP" 'prepare_os'
assert_file_contains "$BOOTSTRAP" 'git clone'
assert_file_contains "$BOOTSTRAP" 'pi-coding-agent'
assert_file_contains "$BOOTSTRAP" 'install-nixpi/SKILL.md'

# Phase 1: OS preparation enables flakes before flake-based rebuild.
assert_file_contains "$BOOTSTRAP" 'nix flake --help'
assert_file_contains "$BOOTSTRAP" '/etc/nixos/configuration.nix'
assert_file_contains "$BOOTSTRAP" 'nixos-rebuild switch -I'

# Negative: no dialog or old wizard references.
BOOTSTRAP_CONTENT="$(<"$BOOTSTRAP")"
assert_file_not_contains "$BOOTSTRAP" 'dialog'
assert_file_not_contains "$BOOTSTRAP" 'nixpi-setup.sh'
assert_file_not_contains "$BOOTSTRAP" '--dry-run'
assert_file_not_contains "$BOOTSTRAP" '--non-interactive'

# --- install-nixpi SKILL.md ---

# Frontmatter: correct name and description.
assert_file_contains "$SKILL" 'name: install-nixpi'
assert_file_contains "$SKILL" 'description:'

# Required phases present.
assert_file_contains "$SKILL" 'nixos-generate-config'
assert_file_contains "$SKILL" '/sys/firmware/efi'
assert_file_contains "$SKILL" '/etc/nixpi/.setup-complete'
assert_file_contains "$SKILL" 'verify-nixpi.sh'

# Phase structure keywords.
assert_file_contains "$SKILL" 'Phase 1'
assert_file_contains "$SKILL" 'Phase 2'
assert_file_contains "$SKILL" 'Phase 3'
assert_file_contains "$SKILL" 'Phase 4'
assert_file_contains "$SKILL" 'Phase 5'
assert_file_contains "$SKILL" 'Phase 6'
assert_file_contains "$SKILL" 'Phase 7'

# No old wizard references.
assert_file_not_contains "$SKILL" 'dialog'
assert_file_not_contains "$SKILL" 'nixpi-setup.sh'

# --- Templates still exist ---
assert_file_exists "templates/default/flake.nix"
assert_file_exists "templates/default/nixpi-config.nix"

# --- nixpi-cli.sh setup case uses Pi skill ---
assert_file_contains "$CLI" 'install-nixpi/SKILL.md'
CLI_CONTENT="$(<"$CLI")"
assert_not_contains "$CLI_CONTENT" 'nixpi-setup.sh'

# --- base.nix: no dialog dependency ---
BASE_CONTENT="$(<"$BASE")"
assert_not_contains "$BASE_CONTENT" 'pkgs.dialog'

# --- Stale reference checks ---
README_CONTENT="$(<"$README")"
assert_not_contains "$README_CONTENT" 'nixpi-setup.sh'
assert_not_contains "$README_CONTENT" 'add-host.sh'
assert_not_contains "$README_CONTENT" 'bootstrap-fresh-nixos'

REINSTALL_CONTENT="$(<"$REINSTALL")"
assert_not_contains "$REINSTALL_CONTENT" 'nixpi-setup.sh'
assert_not_contains "$REINSTALL_CONTENT" 'add-host.sh'
assert_not_contains "$REINSTALL_CONTENT" 'bootstrap-fresh-nixos'

OPERATING_CONTENT="$(<"$OPERATING")"
assert_not_contains "$OPERATING_CONTENT" 'nixpi-setup.sh'
assert_not_contains "$OPERATING_CONTENT" 'add-host.sh'
assert_not_contains "$OPERATING_CONTENT" 'bootstrap-fresh-nixos'
assert_not_contains "$OPERATING_CONTENT" 'dialog TUI'

# --- System default: flakes + nix-command enabled ---
assert_file_contains "$BASE" 'nix.settings.experimental-features = [ "nix-command" "flakes" ];'

echo "PASS: bootstrap + setup skill + stale reference checks"
