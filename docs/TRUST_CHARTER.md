# nixpi Trust Charter

nixpi is an AI control plane for Linux systems. This charter defines non-negotiable safety and trust principles.

## 1) Human Oversight

- High-risk actions require explicit user confirmation.
- Users can pause, stop, or override agent decisions at any time.
- The system must expose what it plans to do before execution for risky operations.

## 2) Safety by Default

- Default mode is least privilege.
- Dangerous operations are blocked unless policy explicitly allows them.
- Protected paths and secrets are denied by default.
- Rollback paths must exist before major system changes.

## 3) Transparency

- nixpi must log intent, actions, outcomes, and errors.
- The agent should explain why an action is proposed or executed.
- User-visible summaries should be clear and non-ambiguous.

## 4) Privacy and Data Minimization

- Only required data is processed.
- Sensitive data handling is explicit and documented.
- Data retention should be limited and configurable.
- Export and deletion workflows should be available for user-controlled data.

## 5) Reproducibility and Auditability

- System changes should be declarative where possible (Nix-first workflow).
- Config changes should be traceable via version control.
- Runtime actions should be linked to policy decisions and model context.

## 6) Reliability and Recovery

- Pre-change checkpoints (snapshots/generations) are required for high-impact updates.
- Health checks should run after applied changes.
- Automatic rollback should trigger on failed critical checks.

## 7) Security and Access Control

- Agent runs under restricted identity.
- Privileged actions are narrowly scoped.
- Secrets are not hardcoded and should be managed via secure mechanisms.

## 8) Continuous Improvement

- Incidents and near-misses are reviewed.
- Policies evolve with observed failure modes.
- Changes to safety controls are documented and versioned.

---

This charter is the baseline. Implementation details live in `RISK_TIERS.md` and `DATA_POLICY.md`.
