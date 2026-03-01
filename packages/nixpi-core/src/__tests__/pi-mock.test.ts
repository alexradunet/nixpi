import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { ScenarioBasedPiMock } from "../testing/pi-mock.js";
import {
  TASK_CREATE_SCENARIO,
  HEARTBEAT_SCENARIO,
  ERROR_SCENARIO,
  ALL_SCENARIOS,
} from "../testing/fixtures/pi-scenarios.js";

describe("ScenarioBasedPiMock", () => {
  it("matches string patterns", () => {
    const mock = new ScenarioBasedPiMock([
      { name: "greeting", match: "hello", response: "hi there" },
    ]);
    assert.equal(mock.respond("hello world"), "hi there");
  });

  it("matches regex patterns", () => {
    const mock = new ScenarioBasedPiMock([TASK_CREATE_SCENARIO]);
    const response = mock.respond("create a new task for groceries");
    assert.ok(response.includes("created task/my-task"));
  });

  it("returns default response when no match", () => {
    const mock = new ScenarioBasedPiMock([TASK_CREATE_SCENARIO]);
    assert.equal(mock.respond("unrelated input"), "(no response)");
  });

  it("uses custom default response", () => {
    const mock = new ScenarioBasedPiMock([], "fallback");
    assert.equal(mock.respond("anything"), "fallback");
  });

  it("matches first scenario in priority order", () => {
    const mock = new ScenarioBasedPiMock([
      ERROR_SCENARIO,
      TASK_CREATE_SCENARIO,
    ]);
    // "create task error" matches both — error should win (first)
    const response = mock.respond("create task error");
    assert.ok(response.includes("Sorry, I encountered an error"));
  });

  it("logs all calls", () => {
    const mock = new ScenarioBasedPiMock(ALL_SCENARIOS);

    mock.respond("create task foo");
    mock.respond("heartbeat");
    mock.respond("unknown");

    assert.equal(mock.calls.length, 3);
    assert.equal(mock.calls[0].matchedScenario, "task-create");
    assert.equal(mock.calls[1].matchedScenario, "heartbeat");
    assert.equal(mock.calls[2].matchedScenario, null);
  });

  it("logs input text in calls", () => {
    const mock = new ScenarioBasedPiMock([HEARTBEAT_SCENARIO]);
    mock.respond("run heartbeat now");
    assert.equal(mock.calls[0].input, "run heartbeat now");
  });

  it("reset clears calls", () => {
    const mock = new ScenarioBasedPiMock(ALL_SCENARIOS);
    mock.respond("heartbeat");
    assert.equal(mock.calls.length, 1);
    mock.reset();
    assert.equal(mock.calls.length, 0);
  });

  it("ALL_SCENARIOS covers task, heartbeat, journal, note, error", () => {
    const mock = new ScenarioBasedPiMock(ALL_SCENARIOS);

    const results = [
      { input: "create a task", expected: "task-create" },
      { input: "list tasks", expected: "list-tasks" },
      { input: "heartbeat", expected: "heartbeat" },
      { input: "journal entry", expected: "journal" },
      { input: "take a note", expected: "note" },
      { input: "trigger error", expected: "error" },
    ];

    for (const { input, expected } of results) {
      mock.reset();
      mock.respond(input);
      assert.equal(
        mock.calls[0].matchedScenario,
        expected,
        `Expected "${input}" to match "${expected}"`,
      );
    }
  });
});
