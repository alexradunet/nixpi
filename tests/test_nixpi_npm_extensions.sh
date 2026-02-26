#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
README="README.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"
MANIFEST="infra/pi/extensions/packages.json"

# Happy path: nixpi supports pinned npm install workflow and manifest sync.
assert_file_contains "$BASE" 'nixpi npm install <package@x.y.z...>'
assert_file_contains "$BASE" 'nixpi npm sync'
assert_file_contains "$BASE" 'sync_manifest_to_profile() {'
assert_file_contains "$BASE" '.packages = ($manifest.packages // [])'

# Failure path: missing/unknown npm subcommands and unpinned versions fail with clear errors.
assert_file_contains "$BASE" 'nixpi npm install requires pinned npm package versions.'
assert_file_contains "$BASE" 'Use pinned npm sources (exact versions), e.g. npm:@scope/extension@1.2.3.'
assert_file_contains "$BASE" 'nixpi extension manifest contains unpinned source:'
assert_file_contains "$BASE" 'Unknown nixpi npm subcommand:'

# Edge case: manifest entries are validated declaratively before activation.
assert_file_contains "$BASE" 'isPinnedNpmSource = source:'
assert_file_contains "$BASE" 'extensionPackagesArePinned = builtins.all isPinnedNpmSource extensionPackages;'
assert_file_contains "$BASE" 'All infra/pi/extensions/packages.json entries must be pinned npm sources'

# Declarative reproducibility: extension source list is committed, pinned, and seeded into defaults.
[ -f "$MANIFEST" ] || fail "expected committed extension manifest: $MANIFEST"
assert_file_contains "$MANIFEST" '"packages"'
assert_file_contains "$MANIFEST" '"npm:@aaronmaturen/pi-context7@1.0.1"'
assert_file_contains "$BASE" 'extensionManifest = builtins.fromJSON (builtins.readFile ../pi/extensions/packages.json);'
assert_file_contains "$BASE" 'packages = extensionPackages;'

# Docs regression: users can discover pinned install + sync workflow.
assert_file_contains "$README" 'nixpi npm install @scope/extension@1.2.3'
assert_file_contains "$README" 'nixpi npm sync'
assert_file_contains "$OPERATING" '`nixpi npm install <package@version>`'
assert_file_contains "$OPERATING" '`nixpi npm sync`'

echo "PASS: nixpi npm extension workflow is pinned, declarative, and syncable"
