# Nixpi Emoji -> Concept Dictionary

A compact visual language for Nixpi user communication.

## Purpose
- Reduce cognitive load in status updates, plans, and operations.
- Keep messages scannable while preserving precise meaning.

## Usage Rules
- Use **at most 1-3 emojis per section** (avoid emoji noise).
- Always include plain text next to emoji (never emoji-only meaning).
- Use consistent mapping from this document.
- Prefer stable semantics over creative alternatives.

## Core Status
- ✅ Done / success
- 🟡 In progress / pending user input
- ⏸️ Paused / waiting
- ❌ Failed / blocked
- ⚠️ Warning / caution
- ℹ️ Info / context

## Action Types
- 🔍 Analyze / inspect / read-only checks
- 🛠️ Implement / modify code
- 🧪 Test / validate behavior
- 🧹 Refactor / cleanup
- 📦 Package / dependency or artifact changes
- 🚀 Apply / deploy / rebuild
- 🔁 Retry / rerun

## Risk & Safety
- 🟢 Low risk (docs, non-behavioral)
- 🟠 Medium risk (code behavior changes)
- 🔴 High risk (system-level, security, data integrity)
- 🔒 Security-sensitive area
- 🔐 Secrets/credentials boundary
- 🧯 Rollback/recovery note

## TDD Flow (Mandatory)
- 🔴 Red: failing test added first
- 🟢 Green: minimal code makes tests pass
- ♻️ Refactor: structure improvements with tests green
- 🧪 Regression/edge-case tests included

## Nix/NixOS Operations
- ❄️ Nix/NixOS declarative configuration
- 🧱 Flake inputs/outputs or reproducibility boundary
- 🔄 `nixos-rebuild switch` apply step
- ⏪ NixOS generation rollback path

## Runtime vs Maintainer Roles
- 🤖 Runtime assistant action (user-facing operations)
- 🧑‍💻 Maintainer/development agent action
- 📨 Evolution request created by runtime
- 🧾 Reviewable diff/PR artifact

## Decision & Approval Signals
- 👍 Approved / proceed
- ❓ Clarification needed
- ✋ Explicit confirmation required before risky action

## Recommended Message Pattern
Use this structure for operational messages:
1. **Status** (emoji + text)
2. **Risk** (emoji + level)
3. **Next action** (emoji + concrete step)
4. **Validation** (emoji + commands/results)

### Example
- 🟡 In progress: adding Matrix adapter config docs.
- 🟢 Risk: low (docs only).
- 🛠️ Next: update `README.md` and `docs/OPERATING_MODEL.md`.
- 🧪 Validation: run `./scripts/check.sh`.
