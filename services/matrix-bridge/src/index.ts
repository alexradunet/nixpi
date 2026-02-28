/**
 * Nixpi Matrix Bridge — matrix-bot-sdk → Pi print mode bridge.
 *
 * Architecture (Ports and Adapters):
 * - Port: MessageChannel interface (from @nixpi/core)
 * - Adapter: matrix-bot-sdk implementation of MessageChannel
 * - Core: Message → spawn `pi -p` → capture stdout → respond
 *
 * MVP scope: text messages only, 1:1 conversations only, no groups.
 */

import { execFile } from "node:child_process";
import fs from "node:fs";
import { promisify } from "node:util";
import {
  MatrixClient,
  SimpleFsStorageProvider,
  AutojoinRoomsMixin,
} from "matrix-bot-sdk";
import type { IncomingMessage, MessageChannel, AgentConfig } from "@nixpi/core";

const execFileAsync = promisify(execFile);

// --- Matrix-specific config (extends core AgentConfig) ---

interface MatrixBridgeConfig extends AgentConfig {
  homeserverUrl: string;
  accessToken: string;
  allowedUsers: string[];
  storageDir: string;
}

// --- Core: Pi Agent Bridge ---

const DEFAULT_CONFIG: MatrixBridgeConfig = {
  piCommand: process.env.NIXPI_PI_COMMAND || "pi",
  piDir: process.env.PI_CODING_AGENT_DIR || `${process.env.HOME}/Nixpi/.pi/agent`,
  repoRoot: process.env.NIXPI_REPO_ROOT || `${process.env.HOME}/Nixpi`,
  objectsDir: process.env.NIXPI_OBJECTS_DIR || `${process.env.HOME}/Nixpi/data/objects`,
  skillsDir: process.env.NIXPI_SKILLS_DIR || `${process.env.HOME}/Nixpi/infra/pi/skills`,
  homeserverUrl: process.env.NIXPI_MATRIX_HOMESERVER || "http://localhost:6167",
  accessToken: process.env.NIXPI_MATRIX_ACCESS_TOKEN || "",
  allowedUsers: (process.env.NIXPI_MATRIX_ALLOWED_USERS || "").split(",").filter(Boolean),
  storageDir: process.env.NIXPI_MATRIX_STORAGE_DIR || `${process.env.HOME}/Nixpi/.pi/agent/matrix-storage`,
  timeoutMs: Number(process.env.NIXPI_MATRIX_TIMEOUT_MS) || 120_000,
};

function isAllowed(userId: string, config: MatrixBridgeConfig): boolean {
  if (config.allowedUsers.length === 0) return true; // no whitelist = allow all
  return config.allowedUsers.includes(userId);
}

// Message processing queue — one at a time to avoid Pi session conflicts.
let processingQueue: Promise<void> = Promise.resolve();

function enqueue(fn: () => Promise<void>): Promise<void> {
  processingQueue = processingQueue.then(fn).catch((err) => {
    console.error("Queue processing error:", err instanceof Error ? err.message : String(err));
  });
  return processingQueue;
}

export async function processMessage(
  text: string,
  config: MatrixBridgeConfig = DEFAULT_CONFIG
): Promise<string> {
  try {
    const { stdout } = await execFileAsync(
      config.piCommand,
      ["-p", text],
      {
        cwd: config.repoRoot,
        env: {
          ...process.env,
          PI_CODING_AGENT_DIR: config.piDir,
          NIXPI_OBJECTS_DIR: config.objectsDir,
        },
        timeout: config.timeoutMs,
        maxBuffer: 1024 * 1024, // 1MB
      }
    );
    return stdout.trim() || "(no response)";
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`Pi processing error: ${message}`);
    return "Sorry, I encountered an error processing your message. Please try again.";
  }
}

// --- Adapter: Matrix Bot SDK ---

class MatrixBotChannel implements MessageChannel {
  readonly name = "matrix";
  private messageHandler?: (msg: IncomingMessage) => Promise<string>;
  private config: MatrixBridgeConfig;
  private client?: MatrixClient;

  constructor(config: MatrixBridgeConfig) {
    this.config = config;
  }

  onMessage(handler: (msg: IncomingMessage) => Promise<string>): void {
    this.messageHandler = handler;
  }

  async sendMessage(to: string, text: string): Promise<void> {
    if (!this.client) {
      throw new Error("Cannot send message: not connected");
    }
    await this.client.sendText(to, text);
  }

  async disconnect(): Promise<void> {
    this.client?.stop();
    this.client = undefined;
  }

  async connect(): Promise<void> {
    // Ensure storage directory exists
    fs.mkdirSync(this.config.storageDir, { recursive: true });

    const storage = new SimpleFsStorageProvider(
      `${this.config.storageDir}/bot.json`
    );

    const client = new MatrixClient(
      this.config.homeserverUrl,
      this.config.accessToken,
      storage
    );

    AutojoinRoomsMixin.setupOnClient(client);

    this.client = client;
    const self = this;

    const botUserId = await client.getUserId();
    console.log(`Bot user ID: ${botUserId}`);

    client.on("room.message", async (roomId: string, event: Record<string, unknown>) => {
      // Skip own messages
      if (event.sender === botUserId) return;

      // Only handle text messages
      const content = event.content as Record<string, unknown> | undefined;
      if (!content || content.msgtype !== "m.text") return;

      const text = content.body as string;
      if (!text) return;

      const from = event.sender as string;

      if (!isAllowed(from, self.config)) {
        console.log(`Blocked message from unauthorized user: ${from}`);
        return;
      }

      console.log(`Message from ${from}: ${text.substring(0, 50)}...`);

      enqueue(async () => {
        const incoming: IncomingMessage = {
          from,
          text,
          timestamp: Date.now(),
          channel: "matrix",
        };

        const response = self.messageHandler
          ? await self.messageHandler(incoming)
          : await processMessage(text, self.config);

        try {
          await self.sendMessage(roomId, response);
        } catch (sendErr: unknown) {
          const errMsg = sendErr instanceof Error ? sendErr.message : String(sendErr);
          console.error(`Failed to send response: ${errMsg}`);
        }
      });
    });

    await client.start();
    console.log("Connected to Matrix homeserver.");
  }
}

// --- Main ---

function validateMatrixUserId(userId: string): boolean {
  return /^@[a-zA-Z0-9._=/+-]+:[a-zA-Z0-9.-]+$/.test(userId);
}

async function main(): Promise<void> {
  const config = { ...DEFAULT_CONFIG };

  // Validate access token
  if (!config.accessToken) {
    throw new Error("NIXPI_MATRIX_ACCESS_TOKEN is required");
  }

  // Validate allowed users format
  for (const userId of config.allowedUsers) {
    if (!validateMatrixUserId(userId)) {
      throw new Error(`Invalid Matrix user ID format in NIXPI_MATRIX_ALLOWED_USERS: '${userId}' (expected @localpart:domain)`);
    }
  }

  // Validate piDir exists
  if (!fs.existsSync(config.piDir)) {
    throw new Error(`Pi directory not found: ${config.piDir}`);
  }

  console.log("Nixpi Matrix Bridge starting...");
  console.log(`  Homeserver: ${config.homeserverUrl}`);
  console.log(`  Pi command: ${config.piCommand}`);
  console.log(`  Pi dir: ${config.piDir}`);
  console.log(`  Objects dir: ${config.objectsDir}`);
  console.log(`  Allowed users: ${config.allowedUsers.length === 0 ? "all" : config.allowedUsers.join(", ")}`);

  const channel = new MatrixBotChannel(config);
  channel.onMessage(async (msg) => processMessage(msg.text, config));
  await channel.connect();
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
