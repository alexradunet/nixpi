# nixpi Data Policy (v1)

This policy defines how nixpi handles data in a privacy-first, EU-aligned way.

## 1) Data Categories

nixpi may process:
- **Operational data**: commands, tool inputs/outputs, status checks
- **Configuration data**: Nix/system config files, project settings
- **User-provided data**: prompts, explicit files/notes shared by user
- **Audit data**: action logs, timestamps, outcomes, errors

## 2) Data Minimization

- Process only data needed for the current task.
- Prefer scoped file access over broad directory ingestion.
- Avoid sending unrelated local context to external model providers.

## 3) Purpose Limitation

- Data is used strictly for requested operations and system safety.
- No secondary use without explicit user opt-in.

## 4) Retention

- Keep logs for the shortest useful period.
- Define configurable retention windows (e.g., 7/30/90 days).
- Support secure deletion of expired records.

## 5) User Rights (Product Direction)

nixpi should support:
- Data export (machine-readable)
- Data deletion requests (where technically possible)
- Clear visibility into stored memory/logs

## 6) Sensitive Data Handling

- Do not hardcode credentials in repo or prompts.
- Use secret stores/environment variables for API keys and tokens.
- Mask sensitive values in logs where feasible.
- Mark high-sensitivity paths as protected by policy.

## 7) Data Location and Providers

- Prefer EU-hosted or self-hosted model providers where required.
- Document provider and region choices for deployments.
- Make remote-provider usage explicit to the user.

## 8) Security Controls

- Run agent with least privilege.
- Restrict privileged commands and protected paths.
- Maintain audit logs for security-relevant actions.

## 9) Incident Response

- Detect and record unusual or failed high-risk operations.
- Provide operator-visible incident summaries.
- Define rollback and containment procedures.

---

This is a living policy. Future versions should map controls to concrete implementation and legal review requirements.
