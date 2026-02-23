# nixpi Risk Tiers (v1)

This document defines operational risk levels for agent actions and required controls.

## Tier L0 — Read-only / Observability

Examples:
- Read files
- List directories
- Check service status
- Query system metrics/logs

Policy:
- Allowed by default.
- Still logged.

## Tier L1 — Low-risk Local Changes

Examples:
- Edit files in approved project workspace
- Install/update user-level development dependencies
- Restart non-critical user services

Policy:
- Allowed in approved paths/contexts.
- Logged with before/after summary.

## Tier L2 — Moderate System Changes

Examples:
- Modify declarative system config (Nix files)
- Rebuild/apply system config
- Install system packages via approved workflow

Policy:
- Requires policy match and pre-checks.
- Requires pre-change checkpoint (generation/snapshot).
- Post-change health checks required.

## Tier L3 — High-risk / Potentially Disruptive

Examples:
- Network/firewall changes
- Authentication/user/group changes
- Critical service restarts
- Data migrations

Policy:
- Explicit user approval required.
- Dry-run/plan output required before execution.
- Enhanced logging and rollback readiness required.

## Tier L4 — Critical / Destructive or Irreversible

Examples:
- Disk partitioning/formatting
- Recursive deletes outside approved scope
- Bootloader/kernel-critical changes
- External irreversible actions (payments, account deletions)

Policy:
- Blocked by default.
- Two-step confirmation if ever enabled.
- Must include explicit operator intent and recovery plan.

---

## Global Rules

- Least privilege execution at all tiers.
- Protected paths are denied unless explicit policy exception.
- All actions must include: intent, command/change, result, timestamp.
- On uncertainty, escalate to user confirmation.

## Nix-first Rule

Where possible, system mutation should follow:
1. Edit declarative config
2. Validate/build
3. Apply
4. Verify
5. Rollback if needed

This reduces drift and improves reproducibility.
