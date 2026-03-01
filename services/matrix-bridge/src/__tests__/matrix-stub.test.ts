/**
 * Integration tests: MatrixBotChannel against MatrixStubServer.
 *
 * Tests the real matrix-bot-sdk adapter connecting to our lightweight
 * stub server — verifying the full SDK lifecycle without Conduit.
 */
import { describe, it, afterEach } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { MatrixStubServer } from "@nixpi/core/testing";
import { MatrixBotChannel } from "../index.js";
import type { MatrixBridgeConfig } from "../index.js";

function makeTmpDir(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), "nixpi-matrix-test-"));
}

describe("MatrixBotChannel + MatrixStubServer", () => {
  let server: MatrixStubServer;
  let channel: MatrixBotChannel;
  let storageDir: string;

  afterEach(async () => {
    if (channel) {
      try {
        await channel.disconnect();
      } catch {
        // ignore cleanup errors
      }
    }
    if (server) {
      await server.stop();
    }
    if (storageDir) {
      fs.rmSync(storageDir, { recursive: true, force: true });
    }
  });

  function makeConfig(serverUrl: string): MatrixBridgeConfig {
    storageDir = makeTmpDir();
    return {
      piCommand: "echo",
      piDir: os.tmpdir(),
      repoRoot: os.tmpdir(),
      objectsDir: os.tmpdir(),
      skillsDir: os.tmpdir(),
      homeserverUrl: serverUrl,
      accessToken: "stub-access-token",
      allowedUsers: [],
      storageDir,
      timeoutMs: 5000,
    };
  }

  it("bot connects and syncs against stub", async () => {
    server = new MatrixStubServer();
    await server.start();

    const config = makeConfig(server.url);
    channel = new MatrixBotChannel(config);

    channel.onMessage(async () => "ok");

    await channel.connect();

    // Give it a moment for initial sync
    await new Promise((r) => setTimeout(r, 500));

    // Connection succeeded if we got here without throwing
    assert.ok(true, "Bot connected and synced successfully");
  });

  it("injected message triggers handler, response sent back", async () => {
    server = new MatrixStubServer();
    await server.start();

    const config = makeConfig(server.url);
    channel = new MatrixBotChannel(config);

    channel.onMessage(async (msg) => {
      return `echo: ${msg.text}`;
    });

    await channel.connect();
    // Wait for initial sync
    await new Promise((r) => setTimeout(r, 500));

    // Inject a message from a different user
    server.injectRoomMessage("!default:test", "@alice:test", "hello bot");

    // Wait for the bot to process and respond
    const sent = await server.waitForSentEvent(
      (e) =>
        typeof e.content.body === "string" &&
        e.content.body.includes("echo: hello bot"),
      10000,
    );

    assert.ok(sent);
    assert.equal(sent.content.body, "echo: hello bot");
  });

  it("full round-trip: inject → handler → response verified", async () => {
    server = new MatrixStubServer();
    await server.start();

    const config = makeConfig(server.url);
    channel = new MatrixBotChannel(config);

    const received: string[] = [];
    channel.onMessage(async (msg) => {
      received.push(msg.text);
      return `processed: ${msg.text}`;
    });

    await channel.connect();
    await new Promise((r) => setTimeout(r, 500));

    server.injectRoomMessage("!default:test", "@user:test", "test message");

    const sent = await server.waitForSentEvent(
      (e) => e.content.body === "processed: test message",
      10000,
    );

    assert.equal(received.length, 1);
    assert.equal(received[0], "test message");
    assert.equal(sent.content.body, "processed: test message");
  });

  it("connect fails without onMessage handler", async () => {
    server = new MatrixStubServer();
    await server.start();

    const config = makeConfig(server.url);
    channel = new MatrixBotChannel(config);

    await assert.rejects(() => channel.connect(), {
      message: "onMessage must be called before connect()",
    });
  });
});
