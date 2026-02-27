#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="scripts/nixpi-object.sh"
DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT
export NIXPI_OBJECTS_DIR="$DIR"

# Create evolution object
out="$("$SCRIPT" create evolution "test-evo" \
  --title="Test Evolution" --status=proposed --agent=hermes --risk=low --area=system)"
assert_contains "$out" "created"
assert_file_exists "$DIR/evolution/test-evo.md"
assert_file_contains "$DIR/evolution/test-evo.md" "type: evolution"
assert_file_contains "$DIR/evolution/test-evo.md" "status: proposed"
assert_file_contains "$DIR/evolution/test-evo.md" "agent: hermes"
assert_file_contains "$DIR/evolution/test-evo.md" "risk: low"
assert_file_contains "$DIR/evolution/test-evo.md" "area: system"

# Update status transition
"$SCRIPT" update evolution "test-evo" --status=planning --agent=athena
assert_file_contains "$DIR/evolution/test-evo.md" "status: planning"
assert_file_contains "$DIR/evolution/test-evo.md" "agent: athena"

# List by status
"$SCRIPT" create evolution "test-evo-2" \
  --title="Second Evolution" --status=implementing --agent=hephaestus --risk=medium --area=core
output="$("$SCRIPT" list evolution --status=implementing)"
assert_contains "$output" "test-evo-2"
assert_not_contains "$output" "test-evo "

# NixOS module includes evolution type
assert_file_contains "infra/nixos/modules/objects.nix" '"evolution"'

echo "PASS: evolution object CRUD and NixOS module"
