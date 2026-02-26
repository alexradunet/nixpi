#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

AGENTS_DOC="docs/agents/README.md"
SKILLS_DOC="docs/agents/SKILLS.md"
AGENTS_CONTENT="$(<"$AGENTS_DOC")"

# Expect concise docs: one short pointer in agents overview + dedicated skills index page.
assert_file_contains "$AGENTS_DOC" '[Agent Skills Index](./SKILLS.md)'
assert_file_contains "$SKILLS_DOC" '# Agent Skills Index'

# Skills index contains short mapping and direct links to skill definitions.
assert_file_contains "$SKILLS_DOC" 'Hermes (Runtime)'
assert_file_contains "$SKILLS_DOC" 'Athena (Technical Architect)'
assert_file_contains "$SKILLS_DOC" 'Hephaestus (Maintainer)'
assert_file_contains "$SKILLS_DOC" 'Themis (Reviewer)'
assert_file_contains "$SKILLS_DOC" '../../infra/pi/skills/hermes-runtime/SKILL.md'
assert_file_contains "$SKILLS_DOC" '../../infra/pi/skills/athena-technical-architect/SKILL.md'
assert_file_contains "$SKILLS_DOC" '../../infra/pi/skills/hephaestus-maintainer/SKILL.md'
assert_file_contains "$SKILLS_DOC" '../../infra/pi/skills/themis-reviewer/SKILL.md'

# Agents overview should not duplicate per-skill file path details.
assert_not_contains "$AGENTS_CONTENT" 'infra/pi/skills/hermes-runtime/SKILL.md'
assert_not_contains "$AGENTS_CONTENT" 'infra/pi/skills/athena-technical-architect/SKILL.md'
assert_not_contains "$AGENTS_CONTENT" 'infra/pi/skills/hephaestus-maintainer/SKILL.md'
assert_not_contains "$AGENTS_CONTENT" 'infra/pi/skills/themis-reviewer/SKILL.md'

echo "PASS: agents docs use concise skills index link"
