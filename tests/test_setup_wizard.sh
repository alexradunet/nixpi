#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

SETUP_SCRIPT="$SCRIPT_DIR/../scripts/nixpi-setup.sh"

# Global list of temp dirs to clean up
_CLEANUP_DIRS=()
cleanup() { for d in "${_CLEANUP_DIRS[@]:-}"; do rm -rf "$d"; done; }
trap cleanup EXIT

# Test: generate_nixpi_config produces valid Nix
test_generate_nixpi_config() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  _CLEANUP_DIRS+=("$tmp_dir")

  # Source only the generator function
  NIXPI_SETUP_GENERATE_ONLY=1 source "$SETUP_SCRIPT"

  # Call the generator
  generate_nixpi_config \
    --hostname "testbox" \
    --username "alex" \
    --timezone "Europe/Bucharest" \
    --tailscale true \
    --syncthing true \
    --ttyd false \
    --desktop true \
    --password-policy true \
    --heartbeat false \
    --matrix false \
    --output "$tmp_dir/nixpi-config.nix"

  # File was created
  assert_file_exists "$tmp_dir/nixpi-config.nix"

  # Contains expected values
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'networking.hostName = "testbox"'
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'nixpi.primaryUser = "alex"'
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'nixpi.timeZone = "Europe/Bucharest"'
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'nixpi.tailscale.enable = true'
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'nixpi.ttyd.enable = false'
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'nixpi.heartbeat.enable = false'
  assert_file_contains "$tmp_dir/nixpi-config.nix" 'boot.loader.grub.enable = false'
}

test_generate_nixpi_config

test_generate_flake() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  _CLEANUP_DIRS+=("$tmp_dir")

  NIXPI_SETUP_GENERATE_ONLY=1 source "$SETUP_SCRIPT"

  generate_flake_nix \
    --hostname "testbox" \
    --output "$tmp_dir/flake.nix"

  assert_file_exists "$tmp_dir/flake.nix"
  assert_file_contains "$tmp_dir/flake.nix" 'nixpi.url = "github:alexradunet/nixpi"'
  assert_file_contains "$tmp_dir/flake.nix" "nixosConfigurations.testbox"
}

test_generate_flake

echo "All setup wizard tests passed"
