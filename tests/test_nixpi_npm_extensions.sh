#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"
README="README.md"
OPERATING="docs/runtime/OPERATING_MODEL.md"
MANIFEST="infra/pi/extensions/packages.json"

# Happy path: nixpi supports npm install workflow that writes through pi and tracks manifest.
assert_file_contains "$BASE" 'nixpi npm install <package...>'
assert_file_contains "$BASE" 'EXTENSIONS_MANIFEST="$REPO_ROOT/infra/pi/extensions/packages.json"'
assert_file_contains "$BASE" '"$PI_BIN" install "$source"'

# Failure path: missing/unknown npm subcommands return explicit usage errors.
assert_file_contains "$BASE" 'nixpi npm install requires at least one package name.'
assert_file_contains "$BASE" 'Unknown nixpi npm subcommand:'

# Edge case: package names without npm: prefix are normalized, while prefixed sources are preserved.
assert_file_contains "$BASE" 'npm:*) source="$pkg" ;;'
assert_file_contains "$BASE" '*) source="npm:$pkg" ;;'

# Declarative reproducibility: extension source list is committed and seeded into settings defaults.
[ -f "$MANIFEST" ] || fail "expected committed extension manifest: $MANIFEST"
assert_file_contains "$MANIFEST" '"packages"'
assert_file_contains "$MANIFEST" '"npm:@aaronmaturen/pi-context7"'
assert_file_contains "$BASE" 'extensionManifest = builtins.fromJSON (builtins.readFile ../pi/extensions/packages.json);'
assert_file_contains "$BASE" 'packages = extensionPackages;'

# Docs regression: users can discover the nixpi npm install workflow.
assert_file_contains "$README" 'nixpi npm install @scope/extension'
assert_file_contains "$OPERATING" '`nixpi npm install <package>`'

echo "PASS: nixpi npm extension install workflow is declarative and commit-friendly"
