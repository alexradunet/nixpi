/**
 * Bridge scenario tests using TestMessageChannel + ScenarioBasedPiMock.
 *
 * Wires the same flow as production (message → Pi → response) without
 * subprocess or network — pure in-process.
 */
import { describe, it, beforeEach } from "node:test";
import assert from "node:assert/strict";
import {
  TestMessageChannel,
  ScenarioBasedPiMock,
  ALL_SCENARIOS,
} from "@nixpi/core/testing";
import { isAllowed } from "../index.js";
import type { MatrixBridgeConfig } from "../index.js";

function makeConfig(overrides: Partial<MatrixBridgeConfig> = {}): MatrixBridgeConfig {
  return {
    piCommand: "unused",
    piDir: "/tmp",
    repoRoot: "/tmp",
    objectsDir: "/tmp",
    skillsDir: "/tmp",
    homeserverUrl: "http://localhost:6167",
    accessToken: "test-token",
    allowedUsers: ["@alice:test"],
    storageDir: "/tmp",
    timeoutMs: 5000,
    ...overrides,
  };
}

describe("Bridge scenarios (TestMessageChannel + ScenarioBasedPiMock)", () => {
  let channel: TestMessageChannel;
  let piMock: ScenarioBasedPiMock;
  let config: MatrixBridgeConfig;

  beforeEach(() => {
    channel = new TestMessageChannel();
    piMock = new ScenarioBasedPiMock(ALL_SCENARIOS);
    config = makeConfig();

    // Wire: incoming message → check allowed → Pi mock → response
    channel.onMessage(async (msg) => {
      if (!isAllowed(msg.from, config)) {
        return ""; // silently ignore (production drops the message)
      }
      const response = piMock.respond(msg.text);
      return response || "(no response)";
    });
  });

  it("task creation message flow", async () => {
    await channel.connect();
    const response = await channel.simulateMessage("@alice:test", "create a new task for groceries");
    assert.ok(response.includes("created task/my-task"));
    assert.equal(piMock.calls.length, 1);
    assert.equal(piMock.calls[0].matchedScenario, "task-create");
  });

  it("heartbeat message flow", async () => {
    await channel.connect();
    const response = await channel.simulateMessage("@alice:test", "run heartbeat");
    assert.ok(response.includes("heartbeat logged"));
    assert.equal(piMock.calls[0].matchedScenario, "heartbeat");
  });

  it("unknown input returns default response", async () => {
    await channel.connect();
    const response = await channel.simulateMessage("@alice:test", "tell me a joke");
    assert.equal(response, "(no response)");
    assert.equal(piMock.calls[0].matchedScenario, null);
  });

  it("error input triggers error scenario", async () => {
    await channel.connect();
    const response = await channel.simulateMessage("@alice:test", "trigger an error please");
    assert.ok(response.includes("Sorry, I encountered an error"));
    assert.equal(piMock.calls[0].matchedScenario, "error");
  });

  it("blocked user gets empty response (no Pi invocation)", async () => {
    await channel.connect();
    const response = await channel.simulateMessage("@eve:test", "create task hacking");
    assert.equal(response, "");
    assert.equal(piMock.calls.length, 0); // Pi was never called
  });

  it("empty Pi response returns '(no response)'", async () => {
    const emptyMock = new ScenarioBasedPiMock([], "");
    channel = new TestMessageChannel();
    channel.onMessage(async (msg) => {
      const resp = emptyMock.respond(msg.text);
      return resp || "(no response)";
    });
    await channel.connect();
    const response = await channel.simulateMessage("@alice:test", "anything");
    assert.equal(response, "(no response)");
  });

  it("multiple rapid messages processed sequentially", async () => {
    await channel.connect();
    const messages = [
      "create task one",
      "heartbeat",
      "list all tasks",
    ];

    const responses = await Promise.all(
      messages.map((text) => channel.simulateMessage("@alice:test", text))
    );

    // All 3 should have gotten through
    assert.equal(responses.length, 3);
    assert.equal(piMock.calls.length, 3);

    // Verify each matched correctly
    assert.equal(piMock.calls[0].matchedScenario, "task-create");
    assert.equal(piMock.calls[1].matchedScenario, "heartbeat");
    assert.equal(piMock.calls[2].matchedScenario, "list-tasks");
  });

  it("channel captures sent messages after connect", async () => {
    await channel.connect();
    await channel.sendMessage("@room:test", "hello");
    assert.equal(channel.sent.length, 1);
    assert.equal(channel.sent[0].text, "hello");
  });
});
