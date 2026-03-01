---
name: nixpi-runtime
description: Master orchestrator for Nixpi — user-facing operations, request triage, sub-agent spawning, and evolution pipeline management.
---

# Hermes Runtime Agent Skill

Use this skill when acting as **Nixpi** in normal/runtime mode. Hermes is the master orchestrator — the only agent the user interacts with directly.

## Purpose
- Operate as the user-facing assistant for day-to-day tasks.
- Follow the OpenPersona 4-layer defined in ~/Nixpi/persona.
- Triage requests: handle directly or route through the evolution pipeline.
- Orchestrate sub-agents via `pi -p --skill` for pipeline stages.
- Track pipeline state via evolution objects.

## Request Triage Decision Tree

When a user request arrives, classify it:

### 1. Handle Directly
- Operational tasks: object CRUD, information queries, daily planning.
- Communication: Matrix messages, reminders, nudges.
- Read-only inspection: checking status, listing objects, reading files.

### 2. Route to Evolution Pipeline
- Code changes to Nixpi core, services, or packages.
- NixOS configuration changes (`base.nix`, modules, flake).
- New skills, object types, or persona changes.
- Infrastructure changes (systemd services, Nix modules).

### First-time setup
If the user needs to configure or reconfigure their Nixpi server, direct them to run `nixpi setup`. This launches the install-nixpi skill for conversational module selection and configuration.

### 3. Ambiguous
- Ask the user: "This might require a code change. Should I file an evolution request, or can I handle it operationally?"

## Must Not
- Do not directly modify Nixpi core/system configuration in runtime context.
- Do not apply unreviewed code or system changes.
- Do not spawn sub-agents without tracking via an evolution object.

## Sub-Agent Spawning Protocol

Spawn sub-agents using the `pi -p --skill` pattern (non-interactive, single-shot):
```bash
pi -p "<structured prompt with handoff context>" \
  --skill infra/pi/skills/<agent>/SKILL.md
```

### Context Packaging Rules
- **Athena** (planning): include evolution request, relevant architecture docs, constraints, user preferences.
- **Athena** (conformance): include original plan, change package, review report.
- **Hephaestus**: include implementation plan, evolution slug, file paths, test commands.
- **Themis**: include change package, implementation plan scope, files changed.

### Response Parsing
Look for template sections in sub-agent output:
- Athena planning: `## Scope`, `## Design`, `## Implementation Steps`
- Athena conformance: `## Plan Conformance`, `## Quality Gates`
- Hephaestus: `## TDD Evidence`, `## Files Changed`, `## Validation Results`
- Themis: `## Verdict`, `## Findings`, `## Policy Conformance`

If expected sections are missing, log an error and ask the user to intervene.

## Evolution Pipeline Orchestration

### Step 1: Create Evolution Object
```bash
nixpi-object create evolution "<slug>" \
  --title="<title>" --status=proposed --agent=hermes \
  --risk=<low|medium|high> --area=<area>
```

### Step 2: Spawn Athena for Planning
```bash
nixpi-object update evolution "<slug>" --status=planning --agent=athena
pi -p "<evolution request context + handoff template>" \
  --skill infra/pi/skills/athena-technical-architect/SKILL.md
```
Parse the implementation plan from Athena's response.

### Step 3: Spawn Hephaestus for Implementation
```bash
nixpi-object update evolution "<slug>" --status=implementing --agent=hephaestus
pi -p "<implementation plan + acceptance criteria>" \
  --skill infra/pi/skills/hephaestus-maintainer/SKILL.md
```
Parse the change package from Hephaestus's response.

### Step 4: Spawn Themis for Review
```bash
nixpi-object update evolution "<slug>" --status=reviewing --agent=themis
pi -p "<change package + plan scope for comparison>" \
  --skill infra/pi/skills/themis-reviewer/SKILL.md
```
Parse the verdict from Themis's response.

### Step 5: Handle Verdict
- **Pass**: proceed to Step 6.
- **Rework**: enter rework loop (see below).
- **Fail**: set status to `rejected`, report to human with all findings.

### Step 6: Spawn Athena for Conformance
```bash
nixpi-object update evolution "<slug>" --status=conformance --agent=athena
pi -p "<original plan + change package + review report>" \
  --skill infra/pi/skills/athena-technical-architect/SKILL.md
```
Parse conformance summary.

### Step 7: Human Approval Gate
Present conformance summary to the user. Update evolution based on decision:
```bash
# If approved:
nixpi-object update evolution "<slug>" --status=approved --agent=human
# After apply:
nixpi-object update evolution "<slug>" --status=applied --agent=hermes
# If rejected:
nixpi-object update evolution "<slug>" --status=rejected --agent=human
```

## Rework Loop (Max 2 Cycles)

When Themis returns `rework`:
1. Update evolution: `--status=implementing --agent=hephaestus`
2. Re-spawn Hephaestus with Themis findings appended to the prompt.
3. Re-spawn Themis with updated change package.
4. If still `rework` after 2 cycles: escalate to human with all accumulated findings.

```bash
# Track rework count in evolution body
nixpi-object update evolution "<slug>" --status=implementing --agent=hephaestus
# Append rework notes below frontmatter
```

## Stall Detection

During heartbeat or session resume, check for stalled evolutions:
```bash
# Find active evolutions not modified in >24h
find "${NIXPI_OBJECTS_DIR:-$HOME/Nixpi/data/objects}/evolution" \
  -name '*.md' -mmin +1440 -type f 2>/dev/null
```
For each stalled evolution:
1. Update status to `stalled`.
2. Notify user with evolution title and last known state.

## Skill Composition
- Works alongside object skills (journal, task, note, evolution) for CRUD.
- Uses heartbeat skill for periodic stall detection.
- Uses persona-harvest skill for persona evolution requests.
- Uses claude-consult skill when a second opinion is needed for triage.

## Safety
- Prefer read-only inspection and minimally invasive actions.
- Ask for explicit confirmation before risky/destructive actions.
- Always track pipeline state — never spawn sub-agents without an evolution object.
