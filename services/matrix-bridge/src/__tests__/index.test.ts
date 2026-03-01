import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  validateMatrixUserId,
  isAllowed,
  processMessage,
  MatrixBotChannel,
} from "../index.js";
import type { MatrixBridgeConfig } from "../index.js";

function makeConfig(
  overrides: Partial<MatrixBridgeConfig> = {},
): MatrixBridgeConfig {
  return {
    piCommand: "echo",
    piDir: "/tmp",
    repoRoot: "/tmp",
    objectsDir: "/tmp",
    skillsDir: "/tmp",
    homeserverUrl: "http://localhost:6167",
    accessToken: "test-token",
    allowedUsers: ["@alice:example.com"],
    storageDir: "/tmp",
    timeoutMs: 5000,
    ...overrides,
  };
}

describe("validateMatrixUserId", () => {
  it("accepts valid user IDs", () => {
    assert.equal(validateMatrixUserId("@alice:example.com"), true);
    assert.equal(validateMatrixUserId("@user123:matrix.org"), true);
    assert.equal(validateMatrixUserId("@my.user:server.io"), true);
    assert.equal(validateMatrixUserId("@a_b-c+d=e/f:host"), true);
  });

  it("rejects missing @ prefix", () => {
    assert.equal(validateMatrixUserId("alice:example.com"), false);
  });

  it("rejects missing colon separator", () => {
    assert.equal(validateMatrixUserId("@aliceexample.com"), false);
  });

  it("rejects empty localpart", () => {
    assert.equal(validateMatrixUserId("@:example.com"), false);
  });

  it("rejects empty domain", () => {
    assert.equal(validateMatrixUserId("@alice:"), false);
  });

  it("rejects spaces in user ID", () => {
    assert.equal(validateMatrixUserId("@alice smith:example.com"), false);
  });

  it("rejects empty string", () => {
    assert.equal(validateMatrixUserId(""), false);
  });
});

describe("isAllowed", () => {
  it("allows user in allowedUsers list", () => {
    const config = makeConfig({
      allowedUsers: ["@alice:example.com", "@bob:example.com"],
    });
    assert.equal(isAllowed("@alice:example.com", config), true);
  });

  it("blocks user not in allowedUsers list", () => {
    const config = makeConfig({ allowedUsers: ["@alice:example.com"] });
    assert.equal(isAllowed("@eve:example.com", config), false);
  });

  it("allows all users when allowedUsers is empty", () => {
    const config = makeConfig({ allowedUsers: [] });
    assert.equal(isAllowed("@anyone:anywhere.com", config), true);
  });
});

describe("processMessage", () => {
  it("returns trimmed stdout from the pi command", async () => {
    const config = makeConfig({ piCommand: "echo" });
    const result = await processMessage("hello world", config);
    // echo "hello world" would output: -p hello world
    // because processMessage passes ["-p", text] to execFile
    assert.equal(result, "-p hello world");
  });

  it("returns '(no response)' for empty stdout", async () => {
    const config = makeConfig({ piCommand: "true" });
    const result = await processMessage("test", config);
    assert.equal(result, "(no response)");
  });

  it("returns error message when command fails", async () => {
    const config = makeConfig({ piCommand: "/nonexistent/command" });
    const result = await processMessage("test", config);
    assert.ok(result.includes("Sorry, I encountered an error"));
  });
});

describe("MatrixBotChannel", () => {
  it("throws if connect() is called without onMessage()", async () => {
    const config = makeConfig();
    const channel = new MatrixBotChannel(config);
    await assert.rejects(() => channel.connect(), {
      message: "onMessage must be called before connect()",
    });
  });
});
