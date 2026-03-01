---
name: claude-consult
description: Consult Claude Code non-interactively with `claude -p` (Opus) using full conversation context, then integrate the result into the final response.
compatibility: Requires `claude` CLI on PATH and authenticated.
---

# Claude Consult (Opus via CLI)

Use this skill when:

- The user explicitly asks to consult Claude/Opus.
- A second opinion is helpful for complex or uncertain answers.

## Safety Rules

- Never include secrets/credentials in delegated prompts.
- Redact tokens, private keys, passwords, and protected file contents before sending history.
- Use non-interactive mode only (`-p`) and disable tools for read-only consultation.

## Required Workflow

1. **Build delegated prompt**
   - Include the full relevant conversation history (redacted if needed).
   - Include the exact current user request.
   - Ask for a direct, actionable answer.

2. **Run Claude via CLI (`-p`)**

```bash
claude -p \
  --model claude-opus-4-6 \
  --output-format text \
  --permission-mode dontAsk \
  --tools "" <<'PROMPT'
You are assisting another AI assistant. Use the full conversation transcript below.

<conversation_history>
{{FULL_CONVERSATION_HISTORY}}
</conversation_history>

<latest_user_request>
{{LATEST_USER_REQUEST}}
</latest_user_request>

Return:
1) Best direct answer to the user request.
2) Key assumptions/uncertainties.
3) Any corrections to likely mistakes.
PROMPT
```

3. **Integrate result**
   - Evaluate Claude output for correctness and policy compliance.
   - Update your response using useful parts of Claude output.
   - If Claude conflicts with known facts, resolve before replying.

## Failure Handling

- If CLI call fails, report that Claude consult failed and continue with your own best answer.
- If prompt is too long, summarize oldest turns while keeping recent turns verbatim.

## Response Transparency

When this skill is used, briefly state that you consulted Claude via CLI and integrated the result.
