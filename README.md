# nixpi

nixpi is an autonomous AI personal agent project built on top of **pi.dev**.

## Project Goal

Build an AI-first operating environment where:

- **Linux/NixOS is the execution layer** (kernel, filesystem, services, networking)
- **The AI agent is the control layer** (planning, orchestration, automation)
- **Policy and safety guardrails** prevent destructive or unsafe actions

In practice, the user gives goals, and the agent continuously:

1. Observes system state
2. Plans actions
3. Executes approved operations
4. Verifies outcomes
5. Logs decisions and results
6. Rolls back when needed

## Core Principles

- **Safety first**: strict risk tiers, protected paths, approval for high-risk actions
- **Reproducibility**: declarative config and version pinning (Nix flakes)
- **Recoverability**: rollback via NixOS generations + VM/filesystem snapshots
- **Auditability**: every important action has traceable intent and outcome

## Initial Direction

- Host OS: Fedora workstation
- Target environment: NixOS VM
- Agent runtime: pi SDK + custom pi extensions
- Control model: policy-gated autonomy (not unrestricted root shell)

## Status

Early design phase. No implementation committed yet.
