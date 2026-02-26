#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

BASE="infra/nixos/base.nix"

# Happy path: base.nix reads persona files for system prompt injection.
assert_file_contains "$BASE" "persona"
assert_file_contains "$BASE" "SOUL.md"
assert_file_contains "$BASE" "BODY.md"
assert_file_contains "$BASE" "FACULTY.md"
assert_file_contains "$BASE" "SKILL.md"

# Happy path: persona dir is configurable via NixOS option.
assert_file_contains "$BASE" "nixpi.persona.dir"

# Happy path: persona content is injected into SYSTEM.md.
assert_file_contains "$BASE" "personaContent"

echo "PASS: persona layers are injected into system prompt via activation script"
