#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
DOC="docs/extensions/WHATSAPP_ADAPTER.md"
README="README.md"

# Happy path: declarative NixOS options + service wiring exist.
assert_file_contains "$BASE" 'options.nixpi.whatsapp.enable = lib.mkEnableOption'
assert_file_contains "$BASE" 'options.nixpi.whatsapp.environmentFile = lib.mkOption {'
assert_file_contains "$BASE" 'systemd.services.nixpi-whatsapp-adapter = lib.mkIf config.nixpi.whatsapp.enable'
assert_file_contains "$BASE" 'ExecStart = "${whatsappAdapterRunner}/bin/nixpi-whatsapp-adapter";'
assert_file_contains "$BASE" 'NIXPI_WHATSAPP_PI_BIN = "${nixpiCli}/bin/nixpi";'

# Failure path: enabling adapter requires explicit allowlist source.
assert_file_contains "$BASE" 'nixpi.whatsapp.enable requires either nixpi.whatsapp.allowlistedNumbers or nixpi.whatsapp.environmentFile'

# Edge case: state directory is created declaratively with strict ownership.
assert_file_contains "$BASE" 'systemd.tmpfiles.rules = lib.mkIf config.nixpi.whatsapp.enable'
assert_file_contains "$BASE" 'd ${config.nixpi.whatsapp.stateDir} 0700 ${primaryUser} users - -'

# Docs: operator can discover declarative host config + environment file strategy.
assert_file_contains "$DOC" 'nixpi.whatsapp.enable = true;'
assert_file_contains "$DOC" 'nixpi.whatsapp.environmentFile'
assert_file_contains "$README" 'nixpi.whatsapp.enable'

echo "PASS: WhatsApp adapter declarative NixOS wiring"