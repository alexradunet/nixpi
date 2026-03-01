---
name: persona-harvest
description: Propose improvements to Nixpi's OpenPersona layers through the evolution pipeline.
---

# Persona Harvest Skill

Use this skill when Nixpi identifies opportunities to improve its persona layers based on interaction patterns.

## Purpose

Persona layers (SOUL.md, BODY.md, FACULTY.md, SKILL.md) define how Nixpi behaves. Over time, interactions reveal gaps, mismatches, or growth opportunities. This skill guides structured persona improvement proposals through the evolution pipeline.

## When to Trigger

- User explicitly requests a persona change ("be more brief", "remind me about X").
- Repeated friction detected (user corrects tone, format, or behavior multiple times).
- New capability added that should update SKILL.md competency inventory.
- Channel behavior needs adjustment (Matrix responses too long, TUI too terse).

## Process

1. **Observe**: Identify the pattern or feedback.
2. **Classify**: Determine which layer to modify:
   - SOUL.md — identity, values, voice, boundaries
   - BODY.md — channel adaptation, presence behavior
   - FACULTY.md — reasoning patterns, PARA methodology, reflection
   - SKILL.md — capability inventory, known limitations, tool preferences
3. **Propose**: Create an evolution request using the Hermes -> Athena handoff template.
4. **Include in the request**:
   - Which persona layer(s) to change
   - Specific additions, removals, or modifications
   - Evidence (interaction patterns, user feedback)
   - Acceptance criteria for the change

## Must Not

- Do not directly modify persona files. All changes go through the evolution pipeline.
- Do not propose changes that contradict SOUL.md boundaries.
- Do not add capabilities to SKILL.md that haven't actually been implemented.

## Evolution Request Template

```markdown
## Evolution Request: Persona Update

**Layer**: [SOUL|BODY|FACULTY|SKILL]
**Change type**: [addition|modification|removal]
**Evidence**: [description of pattern or feedback]

### Proposed Change

[Specific text to add/modify/remove]

### Acceptance Criteria

- [ ] Persona layer updated
- [ ] No contradiction with other layers
- [ ] Tests pass (`./scripts/test.sh`)
- [ ] Flake checks pass
```
