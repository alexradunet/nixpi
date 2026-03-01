import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { TestMessageChannel } from "../testing/test-message-channel.js";

describe("TestMessageChannel", () => {
  it("captures sent messages", async () => {
    const ch = new TestMessageChannel();
    ch.onMessage(async (msg) => `echo: ${msg.text}`);
    await ch.connect();
    await ch.sendMessage("@user:test", "hello");

    assert.equal(ch.sent.length, 1);
    assert.equal(ch.sent[0].to, "@user:test");
    assert.equal(ch.sent[0].text, "hello");
  });

  it("simulateMessage invokes handler and returns response", async () => {
    const ch = new TestMessageChannel();
    ch.onMessage(async (msg) => `processed: ${msg.text}`);
    await ch.connect();

    const response = await ch.simulateMessage("@alice:test", "create task foo");
    assert.equal(response, "processed: create task foo");
  });

  it("simulateMessage populates IncomingMessage fields", async () => {
    const ch = new TestMessageChannel();
    let captured: { from: string; channel: string } | undefined;
    ch.onMessage(async (msg) => {
      captured = { from: msg.from, channel: msg.channel };
      return "ok";
    });
    await ch.connect();

    await ch.simulateMessage("@bob:test", "hi");
    assert.equal(captured?.from, "@bob:test");
    assert.equal(captured?.channel, "test");
  });

  it("throws when sending before connect", async () => {
    const ch = new TestMessageChannel();
    ch.onMessage(async () => "ok");
    await assert.rejects(() => ch.sendMessage("@x:y", "msg"), {
      message: "Cannot send message: not connected",
    });
  });

  it("throws when simulating before connect", async () => {
    const ch = new TestMessageChannel();
    ch.onMessage(async () => "ok");
    await assert.rejects(() => ch.simulateMessage("@x:y", "msg"), {
      message: "Channel is not connected",
    });
  });

  it("throws when connect without handler", async () => {
    const ch = new TestMessageChannel();
    await assert.rejects(() => ch.connect(), {
      message: "onMessage must be called before connect()",
    });
  });

  it("setConnectError makes connect throw", async () => {
    const ch = new TestMessageChannel();
    ch.onMessage(async () => "ok");
    ch.setConnectError(new Error("network down"));
    await assert.rejects(() => ch.connect(), {
      message: "network down",
    });
  });

  it("reset clears all state", async () => {
    const ch = new TestMessageChannel();
    ch.onMessage(async () => "ok");
    await ch.connect();
    await ch.sendMessage("@x:y", "msg");
    assert.equal(ch.sent.length, 1);

    ch.reset();
    assert.equal(ch.sent.length, 0);
    // After reset, should need new handler + connect
    await assert.rejects(() => ch.simulateMessage("@x:y", "msg"), {
      message: "No message handler registered",
    });
  });

  it("disconnect prevents further sends", async () => {
    const ch = new TestMessageChannel();
    ch.onMessage(async () => "ok");
    await ch.connect();
    await ch.disconnect();
    await assert.rejects(() => ch.sendMessage("@x:y", "msg"), {
      message: "Cannot send message: not connected",
    });
  });

  it("name is 'test'", () => {
    const ch = new TestMessageChannel();
    assert.equal(ch.name, "test");
  });
});
