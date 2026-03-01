import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { MatrixStubServer } from "../testing/matrix-stub-server.js";

describe("MatrixStubServer", () => {
  let server: MatrixStubServer;

  beforeEach(async () => {
    server = new MatrixStubServer();
    await server.start();
  });

  afterEach(async () => {
    await server.stop();
  });

  async function fetchJson(
    path: string,
    options?: RequestInit,
  ): Promise<unknown> {
    const res = await fetch(`${server.url}${path}`, {
      headers: { "Content-Type": "application/json" },
      ...options,
    });
    return res.json();
  }

  it("returns versions", async () => {
    const data = (await fetchJson("/_matrix/client/versions")) as {
      versions: string[];
    };
    assert.ok(Array.isArray(data.versions));
    assert.ok(data.versions.includes("v1.1"));
  });

  it("handles login", async () => {
    const data = (await fetchJson("/_matrix/client/v3/login", {
      method: "POST",
      body: JSON.stringify({
        type: "m.login.password",
        user: "bot",
        password: "pass",
      }),
    })) as { user_id: string; access_token: string };
    assert.equal(data.user_id, "@bot:test");
    assert.ok(data.access_token);
  });

  it("returns whoami", async () => {
    const data = (await fetchJson("/_matrix/client/v3/account/whoami")) as {
      user_id: string;
    };
    assert.equal(data.user_id, "@bot:test");
  });

  it("returns joined rooms", async () => {
    const data = (await fetchJson("/_matrix/client/v3/joined_rooms")) as {
      joined_rooms: string[];
    };
    assert.ok(Array.isArray(data.joined_rooms));
    assert.ok(data.joined_rooms.includes("!default:test"));
  });

  it("captures sent messages via PUT /send", async () => {
    const roomId = encodeURIComponent("!room:test");
    const type = "m.room.message";
    const txnId = "txn_001";

    await fetchJson(
      `/_matrix/client/v3/rooms/${roomId}/send/${type}/${txnId}`,
      {
        method: "PUT",
        body: JSON.stringify({ msgtype: "m.text", body: "hello" }),
      },
    );

    assert.equal(server.sentEvents.length, 1);
    assert.equal(server.sentEvents[0].roomId, "!room:test");
    assert.equal(server.sentEvents[0].content.body, "hello");
    assert.equal(server.sentEvents[0].txnId, "txn_001");
  });

  it("handles room join", async () => {
    const roomId = encodeURIComponent("!new:test");
    await fetchJson(`/_matrix/client/v3/join/${roomId}`, { method: "POST" });

    const rooms = (await fetchJson("/_matrix/client/v3/joined_rooms")) as {
      joined_rooms: string[];
    };
    assert.ok(rooms.joined_rooms.includes("!new:test"));
  });

  it("sync returns empty on initial call", async () => {
    const data = (await fetchJson("/_matrix/client/v3/sync?timeout=0")) as {
      next_batch: string;
      rooms: { join: Record<string, unknown> };
    };
    assert.ok(data.next_batch);
    assert.deepEqual(data.rooms.join, {});
  });

  it("sync delivers injected messages", async () => {
    server.injectRoomMessage("!room:test", "@alice:test", "hello bot");

    const data = (await fetchJson("/_matrix/client/v3/sync?timeout=0")) as {
      rooms: {
        join: Record<
          string,
          { timeline: { events: Array<{ content: { body: string } }> } }
        >;
      };
    };

    const roomData = data.rooms.join["!room:test"];
    assert.ok(roomData, "Expected room data in sync response");
    assert.equal(roomData.timeline.events.length, 1);
    assert.equal(roomData.timeline.events[0].content.body, "hello bot");
  });

  it("sync long-polls and delivers events when injected", async () => {
    // Start a sync with timeout (will wait for events)
    const syncPromise = fetchJson("/_matrix/client/v3/sync?timeout=5000");

    // Inject after a short delay
    await new Promise((r) => setTimeout(r, 100));
    server.injectRoomMessage("!room:test", "@alice:test", "delayed msg");

    const data = (await syncPromise) as {
      rooms: {
        join: Record<
          string,
          { timeline: { events: Array<{ content: { body: string } }> } }
        >;
      };
    };

    const roomData = data.rooms.join["!room:test"];
    assert.ok(roomData);
    assert.equal(roomData.timeline.events[0].content.body, "delayed msg");
  });

  it("waitForSentEvent resolves when matching event arrives", async () => {
    // Send event first
    const roomId = encodeURIComponent("!room:test");
    await fetchJson(
      `/_matrix/client/v3/rooms/${roomId}/send/m.room.message/txn1`,
      {
        method: "PUT",
        body: JSON.stringify({ msgtype: "m.text", body: "response" }),
      },
    );

    const event = await server.waitForSentEvent(
      (e) => e.content.body === "response",
      1000,
    );
    assert.equal(event.content.body, "response");
  });

  it("waitForSentEvent times out if no match", async () => {
    await assert.rejects(() => server.waitForSentEvent(() => false, 200), {
      message: /No matching sent event within 200ms/,
    });
  });

  it("handles filter creation", async () => {
    const data = (await fetchJson("/_matrix/client/v3/user/@bot:test/filter", {
      method: "POST",
      body: JSON.stringify({}),
    })) as { filter_id: string };
    assert.ok(data.filter_id);
  });

  it("reset clears all state", async () => {
    server.injectRoomMessage("!room:test", "@alice:test", "msg");
    const roomId = encodeURIComponent("!room:test");
    await fetchJson(
      `/_matrix/client/v3/rooms/${roomId}/send/m.room.message/txn1`,
      {
        method: "PUT",
        body: JSON.stringify({ body: "sent" }),
      },
    );

    server.reset();

    assert.equal(server.sentEvents.length, 0);
    // Sync should return empty after reset
    const data = (await fetchJson("/_matrix/client/v3/sync?timeout=0")) as {
      rooms: { join: Record<string, unknown> };
    };
    assert.deepEqual(data.rooms.join, {});
  });

  it("delivers invite events in invite section", async () => {
    server.injectInvite("!invited:test", "@alice:test");

    const data = (await fetchJson("/_matrix/client/v3/sync?timeout=0")) as {
      rooms: {
        invite: Record<
          string,
          { invite_state: { events: Array<{ type: string }> } }
        >;
      };
    };

    const inviteData = data.rooms.invite["!invited:test"];
    assert.ok(inviteData, "Expected invite data");
    assert.equal(inviteData.invite_state.events[0].type, "m.room.member");
  });

  it("returns 404 for unknown endpoints", async () => {
    const res = await fetch(`${server.url}/_matrix/unknown/endpoint`);
    assert.equal(res.status, 404);
  });

  it("binds to random port (no conflicts)", async () => {
    const server2 = new MatrixStubServer();
    await server2.start();
    assert.notEqual(server.url, server2.url);
    await server2.stop();
  });
});
