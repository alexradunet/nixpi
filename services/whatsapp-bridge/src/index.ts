/**
 * Nixpi WhatsApp Bridge — Minimal Baileys → Pi print mode bridge.
 *
 * Architecture (Ports and Adapters):
 * - Port: MessageChannel interface (from @nixpi/core)
 * - Adapter: Baileys implementation of MessageChannel
 * - Core: Message → spawn `pi -p` → capture stdout → respond
 *
 * MVP scope: text messages only, 1:1 conversations only, no groups.
 */

import { execFile } from "node:child_process";
import fs from "node:fs";
import { promisify } from "node:util";
import type { IncomingMessage, MessageChannel, AgentConfig } from "@nixpi/core";

const execFileAsync = promisify(execFile);

// --- WhatsApp-specific config (extends core AgentConfig) ---

interface WhatsAppBridgeConfig extends AgentConfig {
  allowedNumbers: string[];
}

// --- Core: Pi Agent Bridge ---

const DEFAULT_CONFIG: WhatsAppBridgeConfig = {
  piCommand: process.env.NIXPI_PI_COMMAND || "pi",
  piDir: process.env.PI_CODING_AGENT_DIR || `${process.env.HOME}/Nixpi/.pi/agent`,
  repoRoot: process.env.NIXPI_REPO_ROOT || `${process.env.HOME}/Nixpi`,
  objectsDir: process.env.NIXPI_OBJECTS_DIR || `${process.env.HOME}/Nixpi/data/objects`,
  skillsDir: process.env.NIXPI_SKILLS_DIR || `${process.env.HOME}/Nixpi/infra/pi/skills`,
  allowedNumbers: (process.env.NIXPI_WHATSAPP_ALLOWED || "").split(",").filter(Boolean),
  timeoutMs: Number(process.env.NIXPI_WHATSAPP_TIMEOUT_MS) || 120_000,
};

function isAllowed(jid: string, config: WhatsAppBridgeConfig): boolean {
  if (config.allowedNumbers.length === 0) return true; // no whitelist = allow all
  const number = jid.replace(/@.*$/, "");
  return config.allowedNumbers.includes(number);
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
  config: WhatsAppBridgeConfig = DEFAULT_CONFIG
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

// --- Adapter: Baileys WhatsApp ---

class BaileysWhatsAppChannel implements MessageChannel {
  readonly name = "whatsapp";
  private messageHandler?: (msg: IncomingMessage) => Promise<string>;
  private config: WhatsAppBridgeConfig;
  private sock?: ReturnType<typeof import("@whiskeysockets/baileys").default>;
  private reconnectAttempts = 0;
  private static readonly MAX_RECONNECT_DELAY_MS = 30_000;

  constructor(config: WhatsAppBridgeConfig) {
    this.config = config;
  }

  onMessage(handler: (msg: IncomingMessage) => Promise<string>): void {
    this.messageHandler = handler;
  }

  async sendMessage(to: string, text: string): Promise<void> {
    const sock = this.sock;
    if (!sock) {
      throw new Error("Cannot send message: not connected");
    }
    await sock.sendMessage(to, { text });
  }

  async disconnect(): Promise<void> {
    this.sock?.end(undefined);
    this.sock = undefined;
  }

  private reconnectDelay(): number {
    const delay = Math.min(
      1000 * Math.pow(2, this.reconnectAttempts),
      BaileysWhatsAppChannel.MAX_RECONNECT_DELAY_MS,
    );
    this.reconnectAttempts++;
    return delay;
  }

  async connect(): Promise<void> {
    const { default: makeWASocket, useMultiFileAuthState, DisconnectReason } =
      await import("@whiskeysockets/baileys");
    const { Boom } = await import("@hapi/boom");
    const pino = (await import("pino")).default;

    const logger = pino({ level: "silent" });
    const authDir = `${this.config.piDir}/whatsapp-auth`;

    const self = this;

    async function connectInner(): Promise<void> {
      const { state, saveCreds } = await useMultiFileAuthState(authDir);

      const sock = makeWASocket({
        auth: state,
        logger,
        printQRInTerminal: true,
      });

      self.sock = sock;

      sock.ev.on("connection.update", (update) => {
        const { connection, lastDisconnect, qr } = update;

        if (qr) {
          console.log("Scan the QR code above with WhatsApp to pair.");
        }

        if (connection === "close") {
          self.sock = undefined;
          const isBoom = lastDisconnect?.error instanceof Boom;
          const statusCode = isBoom
            ? (lastDisconnect!.error as InstanceType<typeof Boom>).output.statusCode
            : undefined;
          const shouldReconnect = statusCode !== DisconnectReason.loggedOut;

          if (shouldReconnect) {
            const delay = self.reconnectDelay();
            console.log(`Connection closed. Reconnecting in ${delay}ms...`);
            setTimeout(() => {
              connectInner().catch((err) => {
                console.error("Reconnect failed:", err instanceof Error ? err.message : String(err));
              });
            }, delay);
          } else {
            console.log("Logged out from WhatsApp. Exiting.");
            process.exit(0);
          }
        }

        if (connection === "open") {
          self.reconnectAttempts = 0;
          console.log("Connected to WhatsApp.");
        }
      });

      sock.ev.on("creds.update", saveCreds);

      sock.ev.on("messages.upsert", (event) => {
        for (const msg of event.messages) {
          if (!msg.message) continue;
          if (msg.key.fromMe) continue;
          if (!msg.key.remoteJid) continue;
          if (msg.key.remoteJid.endsWith("@g.us")) continue;

          const text =
            msg.message.conversation ||
            msg.message.extendedTextMessage?.text;
          if (!text) continue;

          const from = msg.key.remoteJid;

          if (!isAllowed(from, self.config)) {
            console.log(`Blocked message from unauthorized number: ${from}`);
            continue;
          }

          console.log(`Message from ${from}: ${text.substring(0, 50)}...`);

          enqueue(async () => {
            const incoming: IncomingMessage = {
              from,
              text,
              timestamp: Date.now(),
              channel: "whatsapp",
            };

            const response = self.messageHandler
              ? await self.messageHandler(incoming)
              : await processMessage(text, self.config);

            try {
              await self.sendMessage(from, response);
            } catch (sendErr: unknown) {
              const errMsg = sendErr instanceof Error ? sendErr.message : String(sendErr);
              console.error(`Failed to send response: ${errMsg}`);
            }
          });
        }
      });
    }

    await connectInner();
  }
}

// --- Main ---

function validateJid(number: string): boolean {
  return /^\d{7,15}$/.test(number);
}

async function main(): Promise<void> {
  const config = { ...DEFAULT_CONFIG };

  // Validate allowed numbers format
  for (const num of config.allowedNumbers) {
    if (!validateJid(num)) {
      throw new Error(`Invalid phone number format in NIXPI_WHATSAPP_ALLOWED: '${num}' (expected 7-15 digits)`);
    }
  }

  // Validate piDir exists
  if (!fs.existsSync(config.piDir)) {
    throw new Error(`Pi directory not found: ${config.piDir}`);
  }

  console.log("Nixpi WhatsApp Bridge starting...");
  console.log(`  Pi command: ${config.piCommand}`);
  console.log(`  Pi dir: ${config.piDir}`);
  console.log(`  Objects dir: ${config.objectsDir}`);
  console.log(`  Allowed numbers: ${config.allowedNumbers.length === 0 ? "all" : config.allowedNumbers.join(", ")}`);

  const channel = new BaileysWhatsAppChannel(config);
  channel.onMessage(async (msg) => processMessage(msg.text, config));
  await channel.connect();
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
