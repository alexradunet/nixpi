# Documentation Style Guide

Related: [Docs Home](../README.md) · [Source of Truth Map](./SOURCE_OF_TRUTH.md) · [Operating Model](../runtime/OPERATING_MODEL.md) · [Emoji Dictionary](../ux/EMOJI_DICTIONARY.md)

## Goals
- Treat documentation like code: modular, composable, reviewable.
- Keep docs easy to navigate for both humans and AI agents.

## Link Policy (Canonical)
Use standard Markdown links as the default and canonical format:
- Example: `[Operating Model](../runtime/OPERATING_MODEL.md)`

## File and Content Conventions
- One concept per file.
- Keep files short and focused; split when a section grows too much.
- Start with a concise purpose paragraph.
- Include a `Related:` line near the top with Markdown links.
- Prefer stable filenames once published.

## Standards-First Documentation Rule
- Use standards-based syntax and formats only (CommonMark-style Markdown).
- Avoid tool-specific link syntaxes and proprietary notation.

## Suggested Structure
- `docs/README.md` — docs home (map of content)
- `docs/meta/SOURCE_OF_TRUTH.md` — canonical ownership and precedence
- `docs/runtime/OPERATING_MODEL.md` — system operating workflow
- `docs/agents/README.md` — agent role overview
- `docs/agents/<agent>/README.md` — per-agent contract
- `docs/ux/EMOJI_DICTIONARY.md` — visual language
- `docs/meta/DOCS_STYLE.md` — this policy
- Optional future areas:
  - `docs/extensions/`
  - `docs/operations/`

## Pre-Release Simplicity Policy
- Before first stable release, do not keep legacy redirect files.
- Update references directly to canonical paths.

## Generated Artifacts
- Do not commit generated operational artifacts unless explicitly required.
- Handoff files under `docs/agents/handoffs/*.md` are local by default.

## Authoring Checklist
- Added/updated Markdown links?
- Avoided duplicate concepts across files?
- Updated docs home (`docs/README.md`) when adding a major doc?
- Updated `docs/meta/SOURCE_OF_TRUTH.md` if ownership/precedence changed?
- Kept examples executable and current?
- Used documentation emojis from `docs/ux/EMOJI_DICTIONARY.md` consistently?
