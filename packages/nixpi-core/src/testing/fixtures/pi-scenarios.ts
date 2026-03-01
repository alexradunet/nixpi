/**
 * Pre-built Pi scenarios for common Nixpi operations.
 */
import type { PiScenario } from "../pi-mock.js";

export const TASK_CREATE_SCENARIO: PiScenario = {
  name: "task-create",
  match: /\b(create|add|new)\b.*\btask\b/i,
  response: "created task/my-task\nTitle: my-task\nStatus: open",
};

export const LIST_TASKS_SCENARIO: PiScenario = {
  name: "list-tasks",
  match: /\b(list|show|ls)\b.*\btask/i,
  response: "task/my-task — open\ntask/another-task — done",
};

export const HEARTBEAT_SCENARIO: PiScenario = {
  name: "heartbeat",
  match: /\bheartbeat\b/i,
  response: "heartbeat logged at 2026-03-01T00:00:00Z",
};

export const JOURNAL_SCENARIO: PiScenario = {
  name: "journal",
  match: /\bjournal\b/i,
  response: "created journal/2026-03-01\nBody captured.",
};

export const NOTE_SCENARIO: PiScenario = {
  name: "note",
  match: /\b(note|memo)\b/i,
  response: "created note/quick-note\nTitle: quick-note",
};

export const ERROR_SCENARIO: PiScenario = {
  name: "error",
  match: /\berror\b/i,
  response: "Sorry, I encountered an error processing your message. Please try again.",
};

/** All built-in scenarios in priority order. */
export const ALL_SCENARIOS: PiScenario[] = [
  ERROR_SCENARIO,
  TASK_CREATE_SCENARIO,
  LIST_TASKS_SCENARIO,
  HEARTBEAT_SCENARIO,
  JOURNAL_SCENARIO,
  NOTE_SCENARIO,
];
