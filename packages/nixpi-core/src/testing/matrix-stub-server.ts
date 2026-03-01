/**
 * Lightweight Matrix CS API stub using node:http.
 *
 * Implements enough endpoints for matrix-bot-sdk to function:
 * - Version negotiation, login, whoami
 * - Sync (long-poll with queued events)
 * - Send messages, join rooms, joined rooms, filters
 *
 * Zero npm deps — pure Node.js stdlib.
 */
import http from "node:http";

export interface StubEvent {
  type: string;
  sender: string;
  event_id: string;
  room_id: string;
  content: Record<string, unknown>;
  origin_server_ts: number;
}

export interface SentEvent {
  roomId: string;
  type: string;
  txnId: string;
  content: Record<string, unknown>;
  timestamp: number;
}

export class MatrixStubServer {
  private server: http.Server;
  private port = 0;

  /** Events queued for the next /sync response. */
  private pendingEvents: StubEvent[] = [];
  /** All events sent by the bot (captured from PUT /send). */
  sentEvents: SentEvent[] = [];
  /** Rooms the bot has "joined". */
  private joinedRooms: Set<string> = new Set(["!default:test"]);
  /** Pending sync waiters (resolve when events are injected). */
  private syncWaiters: Array<(events: StubEvent[]) => void> = [];
  /** Event ID counter. */
  private eventCounter = 0;
  /** Sync batch token counter. */
  private syncBatch = 0;
  /** Filter ID counter. */
  private filterCounter = 0;

  private botUserId = "@bot:test";
  private accessToken = "stub-access-token";

  constructor() {
    this.server = http.createServer((req, res) => this.handleRequest(req, res));
  }

  /** Start the server on a random port. */
  async start(): Promise<void> {
    return new Promise((resolve) => {
      this.server.listen(0, "127.0.0.1", () => {
        const addr = this.server.address();
        if (addr && typeof addr === "object") {
          this.port = addr.port;
        }
        resolve();
      });
    });
  }

  /** Stop the server. */
  async stop(): Promise<void> {
    // Resolve any pending sync waiters so they don't hang
    for (const waiter of this.syncWaiters) {
      waiter([]);
    }
    this.syncWaiters = [];

    return new Promise((resolve, reject) => {
      this.server.close((err) => (err ? reject(err) : resolve()));
    });
  }

  /** Get the base URL (available after start()). */
  get url(): string {
    return `http://127.0.0.1:${this.port}`;
  }

  /** Inject a room message event that will be delivered on next /sync. */
  injectRoomMessage(roomId: string, sender: string, body: string): void {
    const event: StubEvent = {
      type: "m.room.message",
      sender,
      event_id: `$evt_${++this.eventCounter}`,
      room_id: roomId,
      content: { msgtype: "m.text", body },
      origin_server_ts: Date.now(),
    };
    this.pendingEvents.push(event);
    this.flushToWaiters();
  }

  /** Inject a room invite event. */
  injectInvite(roomId: string, sender: string): void {
    const event: StubEvent = {
      type: "m.room.member",
      sender,
      event_id: `$evt_${++this.eventCounter}`,
      room_id: roomId,
      content: { membership: "invite" },
      origin_server_ts: Date.now(),
    };
    this.pendingEvents.push(event);
    this.flushToWaiters();
  }

  /**
   * Wait for a sent event matching the predicate.
   * @param predicate Filter for the expected event.
   * @param timeoutMs Maximum wait time (default 5000ms).
   */
  async waitForSentEvent(
    predicate: (e: SentEvent) => boolean,
    timeoutMs = 5000
  ): Promise<SentEvent> {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
      const found = this.sentEvents.find(predicate);
      if (found) return found;
      await new Promise((r) => setTimeout(r, 50));
    }
    throw new Error(`No matching sent event within ${timeoutMs}ms`);
  }

  /** Clear all state. */
  reset(): void {
    this.pendingEvents = [];
    this.sentEvents = [];
    this.joinedRooms = new Set(["!default:test"]);
    for (const waiter of this.syncWaiters) {
      waiter([]);
    }
    this.syncWaiters = [];
    this.eventCounter = 0;
    this.syncBatch = 0;
    this.filterCounter = 0;
  }

  /** Deliver pending events to any waiting /sync callers. */
  private flushToWaiters(): void {
    if (this.syncWaiters.length === 0) return;
    const waiters = this.syncWaiters.splice(0);
    const events = this.pendingEvents.splice(0);
    for (const waiter of waiters) {
      waiter(events);
    }
  }

  // --- Request routing ---

  private handleRequest(req: http.IncomingMessage, res: http.ServerResponse): void {
    const url = new URL(req.url || "/", `http://127.0.0.1:${this.port}`);
    const path = url.pathname;
    const method = req.method || "GET";

    this.readBody(req).then((body) => {
      try {
        if (path === "/_matrix/client/versions" && method === "GET") {
          return this.json(res, { versions: ["v1.1", "v1.2", "v1.3"] });
        }

        if (path === "/_matrix/client/v3/login" && method === "POST") {
          return this.json(res, {
            user_id: this.botUserId,
            access_token: this.accessToken,
            device_id: "STUB_DEVICE",
          });
        }

        if (path === "/_matrix/client/v3/account/whoami" && method === "GET") {
          return this.json(res, { user_id: this.botUserId });
        }

        if (path === "/_matrix/client/v3/sync" && method === "GET") {
          return this.handleSync(url, res);
        }

        if (path === "/_matrix/client/v3/joined_rooms" && method === "GET") {
          return this.json(res, { joined_rooms: [...this.joinedRooms] });
        }

        // PUT /_matrix/client/v3/rooms/:roomId/send/:type/:txnId
        const sendMatch = path.match(
          /^\/_matrix\/client\/v3\/rooms\/([^/]+)\/send\/([^/]+)\/([^/]+)$/
        );
        if (sendMatch && method === "PUT") {
          const [, roomId, type, txnId] = sendMatch;
          const content = body ? JSON.parse(body) : {};
          this.sentEvents.push({
            roomId: decodeURIComponent(roomId),
            type: decodeURIComponent(type),
            txnId: decodeURIComponent(txnId),
            content,
            timestamp: Date.now(),
          });
          return this.json(res, { event_id: `$sent_${++this.eventCounter}` });
        }

        // POST /_matrix/client/v3/join/:roomId
        const joinMatch = path.match(/^\/_matrix\/client\/v3\/join\/([^/]+)$/);
        if (joinMatch && method === "POST") {
          const roomId = decodeURIComponent(joinMatch[1]);
          this.joinedRooms.add(roomId);
          return this.json(res, { room_id: roomId });
        }

        // POST /_matrix/client/v3/user/:userId/filter
        const filterMatch = path.match(
          /^\/_matrix\/client\/v3\/user\/[^/]+\/filter$/
        );
        if (filterMatch && method === "POST") {
          return this.json(res, { filter_id: String(++this.filterCounter) });
        }

        // GET /_matrix/client/v3/user/:userId/filter/:filterId
        const filterGetMatch = path.match(
          /^\/_matrix\/client\/v3\/user\/[^/]+\/filter\/[^/]+$/
        );
        if (filterGetMatch && method === "GET") {
          return this.json(res, {});
        }

        // PUT /_matrix/client/v3/rooms/:roomId/state/:type/:stateKey?
        const stateMatch = path.match(
          /^\/_matrix\/client\/v3\/rooms\/[^/]+\/state\//
        );
        if (stateMatch && method === "PUT") {
          return this.json(res, { event_id: `$state_${++this.eventCounter}` });
        }

        // Catch-all for unknown endpoints
        this.json(res, { errcode: "M_UNRECOGNIZED", error: `Unknown: ${method} ${path}` }, 404);
      } catch (err) {
        console.error("MatrixStubServer error:", err);
        this.json(res, { errcode: "M_UNKNOWN", error: String(err) }, 500);
      }
    });
  }

  private handleSync(url: URL, res: http.ServerResponse): void {
    const timeout = parseInt(url.searchParams.get("timeout") || "0", 10);

    // If we have pending events, return them immediately
    if (this.pendingEvents.length > 0) {
      const events = this.pendingEvents.splice(0);
      return this.syncResponse(res, events);
    }

    // If timeout is 0 or no events, return empty immediately for initial sync
    if (timeout === 0) {
      return this.syncResponse(res, []);
    }

    // Long-poll: wait for events or timeout
    const timer = setTimeout(() => {
      // Remove from waiters
      const idx = this.syncWaiters.indexOf(waiter);
      if (idx !== -1) this.syncWaiters.splice(idx, 1);
      this.syncResponse(res, []);
    }, Math.min(timeout, 5000)); // Cap at 5s to prevent test hangs

    const waiter = (events: StubEvent[]) => {
      clearTimeout(timer);
      this.syncResponse(res, events);
    };
    this.syncWaiters.push(waiter);
  }

  private syncResponse(res: http.ServerResponse, events: StubEvent[]): void {
    const batch = `batch_${++this.syncBatch}`;

    // Group events by room
    const rooms: Record<string, { timeline: { events: StubEvent[] } }> = {};
    for (const event of events) {
      if (!rooms[event.room_id]) {
        rooms[event.room_id] = { timeline: { events: [] } };
      }
      rooms[event.room_id].timeline.events.push(event);
    }

    // Separate invite events from join events
    const joinRooms: Record<string, unknown> = {};
    const inviteRooms: Record<string, unknown> = {};

    for (const [roomId, data] of Object.entries(rooms)) {
      const inviteEvents = data.timeline.events.filter(
        (e) => e.type === "m.room.member" && (e.content as Record<string, unknown>).membership === "invite"
      );
      const otherEvents = data.timeline.events.filter(
        (e) => !(e.type === "m.room.member" && (e.content as Record<string, unknown>).membership === "invite")
      );

      if (inviteEvents.length > 0) {
        inviteRooms[roomId] = {
          invite_state: {
            events: inviteEvents.map((e) => ({
              type: e.type,
              sender: e.sender,
              content: e.content,
              state_key: this.botUserId,
            })),
          },
        };
      }
      if (otherEvents.length > 0) {
        joinRooms[roomId] = { timeline: { events: otherEvents } };
      }
    }

    this.json(res, {
      next_batch: batch,
      rooms: {
        join: joinRooms,
        invite: inviteRooms,
        leave: {},
      },
    });
  }

  private json(res: http.ServerResponse, data: unknown, status = 200): void {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(data));
  }

  private readBody(req: http.IncomingMessage): Promise<string> {
    return new Promise((resolve) => {
      const chunks: Buffer[] = [];
      req.on("data", (chunk: Buffer) => chunks.push(chunk));
      req.on("end", () => resolve(Buffer.concat(chunks).toString()));
    });
  }
}
