#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SKILL="infra/pi/skills/install-nixpi/SKILL.md"
BASE="infra/nixos/base.nix"
CLI="infra/nixos/scripts/nixpi-cli.sh"
README="README.md"
REINSTALL="docs/runtime/REINSTALL.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"

# --- install-nixpi SKILL.md ---

# Frontmatter: correct name and description.
assert_file_contains "$SKILL" 'name: install-nixpi'
assert_file_contains "$SKILL" 'description:'

# Required phases present.
assert_file_contains "$SKILL" 'nixos-generate-config'
assert_file_contains "$SKILL" '/sys/firmware/efi'
assert_file_contains "$SKILL" '/etc/nixpi/.setup-complete'
assert_file_contains "$SKILL" 'verify-nixpi.sh'

# Prerequisites section exists.
assert_file_contains "$SKILL" '## Prerequisites'
assert_file_contains "$SKILL" 'nix-command'

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

# No AI Provider phase or API key management.
assert_file_not_contains "$SKILL" 'AI Provider'
assert_file_not_contains "$SKILL" 'ai-provider.env'

# --- Templates still exist ---
assert_file_exists "templates/default/flake.nix"
assert_file_exists "templates/default/nixpi-config.nix"
assert_file_exists "templates/default/README.md"
assert_executable "templates/default/scripts/install-nixpi-skill.sh"

# --- nixpi-cli.sh setup case uses Pi skill ---
assert_file_contains "$CLI" 'install-nixpi/SKILL.md'
assert_file_contains "$CLI" 'resolve_skill_path'
assert_file_contains "$CLI" 'NIXPI_STORE_SKILLS_DIR'
CLI_CONTENT="$(<"$CLI")"
assert_not_contains "$CLI_CONTENT" 'nixpi-setup.sh'

# --- base.nix: no dialog dependency, no ai-provider sourcing ---
BASE_CONTENT="$(<"$BASE")"
assert_file_contains "$BASE" 'NIXPI_STORE_SKILLS_DIR'
assert_not_contains "$BASE_CONTENT" 'pkgs.dialog'
assert_not_contains "$BASE_CONTENT" 'ai-provider.env'

# --- Stale reference checks ---
README_CONTENT="$(<"$README")"
assert_file_contains "$README" './scripts/install-nixpi-skill.sh'
assert_not_contains "$README_CONTENT" 'nixpi-setup.sh'
assert_not_contains "$README_CONTENT" 'add-host.sh'
assert_not_contains "$README_CONTENT" 'bootstrap-fresh-nixos'
assert_not_contains "$README_CONTENT" 'bootstrap.sh'
assert_not_contains "$README_CONTENT" 'ai-provider'

REINSTALL_CONTENT="$(<"$REINSTALL")"
assert_file_contains "$REINSTALL" './scripts/install-nixpi-skill.sh'
assert_not_contains "$REINSTALL_CONTENT" 'nixpi-setup.sh'
assert_not_contains "$REINSTALL_CONTENT" 'add-host.sh'
assert_not_contains "$REINSTALL_CONTENT" 'bootstrap-fresh-nixos'
assert_not_contains "$REINSTALL_CONTENT" 'bootstrap.sh'
assert_not_contains "$REINSTALL_CONTENT" 'ai-provider'

OPERATING_CONTENT="$(<"$OPERATING")"
assert_not_contains "$OPERATING_CONTENT" 'nixpi-setup.sh'
assert_not_contains "$OPERATING_CONTENT" 'add-host.sh'
assert_not_contains "$OPERATING_CONTENT" 'bootstrap-fresh-nixos'
assert_not_contains "$OPERATING_CONTENT" 'dialog TUI'
assert_not_contains "$OPERATING_CONTENT" 'bootstrap script'
assert_not_contains "$OPERATING_CONTENT" 'ai-provider'

# --- System default: flakes + nix-command enabled ---
assert_file_contains "$BASE" '"nix-command"'
assert_file_contains "$BASE" '"flakes"'

echo "PASS: setup skill + stale reference checks"
