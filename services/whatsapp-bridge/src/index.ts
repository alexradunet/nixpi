/**
 * Nixpi WhatsApp Bridge — Minimal Baileys → Pi print mode bridge.
 *
 * Architecture (Ports and Adapters):
 * - Port: MessageChannel interface (receive message, send response)
 * - Adapter: Baileys implementation of MessageChannel
 * - Core: Message → spawn `pi -p` → capture stdout → respond
 *
 * MVP scope: text messages only, 1:1 conversations only, no groups.
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

// --- Port (interface) ---

export interface IncomingMessage {
  from: string; // sender JID (e.g. "1234567890@s.whatsapp.net")
  text: string; // message body
  timestamp: number;
}

export interface MessageChannel {
  onMessage(handler: (msg: IncomingMessage) => Promise<string>): void;
  sendMessage(to: string, text: string): Promise<void>;
  connect(): Promise<void>;
  disconnect(): Promise<void>;
}

// --- Core: Pi Agent Bridge ---

export interface AgentConfig {
  piCommand: string;
  piDir: string;
  repoRoot: string;
  objectsDir: string;
  skillsDir: string;
  allowedNumbers: string[];
  timeoutMs: number;
}

const DEFAULT_CONFIG: AgentConfig = {
  piCommand: process.env.NIXPI_PI_COMMAND || "pi",
  piDir: process.env.PI_CODING_AGENT_DIR || `${process.env.HOME}/Nixpi/.pi/agent`,
  repoRoot: process.env.NIXPI_REPO_ROOT || `${process.env.HOME}/Nixpi`,
  objectsDir: process.env.NIXPI_OBJECTS_DIR || `${process.env.HOME}/Nixpi/data/objects`,
  skillsDir: process.env.NIXPI_SKILLS_DIR || `${process.env.HOME}/Nixpi/infra/pi/skills`,
  allowedNumbers: (process.env.NIXPI_WHATSAPP_ALLOWED || "").split(",").filter(Boolean),
  timeoutMs: Number(process.env.NIXPI_WHATSAPP_TIMEOUT_MS) || 120_000,
};

function isAllowed(jid: string, config: AgentConfig): boolean {
  if (config.allowedNumbers.length === 0) return true; // no whitelist = allow all
  const number = jid.replace(/@.*$/, "");
  return config.allowedNumbers.includes(number);
}

// Message processing queue — one at a time to avoid Pi session conflicts.
let processingQueue: Promise<void> = Promise.resolve();

function enqueue(fn: () => Promise<void>): Promise<void> {
  processingQueue = processingQueue.then(fn, fn);
  return processingQueue;
}

export async function processMessage(
  text: string,
  config: AgentConfig = DEFAULT_CONFIG
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

async function startBaileysAdapter(config: AgentConfig): Promise<void> {
  // Dynamic import for Baileys (ESM)
  const { default: makeWASocket, useMultiFileAuthState, DisconnectReason } =
    await import("@whiskeysockets/baileys");
  const { Boom } = await import("@hapi/boom");
  const pino = (await import("pino")).default;

  const logger = pino({ level: "silent" });
  const authDir = `${config.piDir}/whatsapp-auth`;

  async function connect(): Promise<void> {
    const { state, saveCreds } = await useMultiFileAuthState(authDir);

    const sock = makeWASocket({
      auth: state,
      logger,
      printQRInTerminal: true,
    });

    sock.ev.on("connection.update", (update) => {
      const { connection, lastDisconnect, qr } = update;

      if (qr) {
        console.log("Scan the QR code above with WhatsApp to pair.");
      }

      if (connection === "close") {
        const statusCode = (lastDisconnect?.error as InstanceType<typeof Boom>)
          ?.output?.statusCode;
        const shouldReconnect = statusCode !== DisconnectReason.loggedOut;

        if (shouldReconnect) {
          console.log("Connection closed. Reconnecting...");
          connect();
        } else {
          console.log("Logged out from WhatsApp. Exiting.");
          process.exit(0);
        }
      }

      if (connection === "open") {
        console.log("Connected to WhatsApp.");
      }
    });

    sock.ev.on("creds.update", saveCreds);

    sock.ev.on("messages.upsert", (event) => {
      for (const msg of event.messages) {
        // Skip non-text messages, group messages, and own messages.
        if (!msg.message) continue;
        if (msg.key.fromMe) continue;
        if (!msg.key.remoteJid) continue;
        if (msg.key.remoteJid.endsWith("@g.us")) continue; // no groups

        const text =
          msg.message.conversation ||
          msg.message.extendedTextMessage?.text;
        if (!text) continue;

        const from = msg.key.remoteJid;

        if (!isAllowed(from, config)) {
          console.log(`Blocked message from unauthorized number: ${from}`);
          continue;
        }

        console.log(`Message from ${from}: ${text.substring(0, 50)}...`);

        // Enqueue for sequential processing.
        enqueue(async () => {
          const response = await processMessage(text, config);
          try {
            await sock.sendMessage(from, { text: response });
          } catch (sendErr: unknown) {
            const errMsg = sendErr instanceof Error ? sendErr.message : String(sendErr);
            console.error(`Failed to send response: ${errMsg}`);
          }
        });
      }
    });
  }

  await connect();
}

// --- Main ---

async function main(): Promise<void> {
  const config = { ...DEFAULT_CONFIG };

  console.log("Nixpi WhatsApp Bridge starting...");
  console.log(`  Pi command: ${config.piCommand}`);
  console.log(`  Pi dir: ${config.piDir}`);
  console.log(`  Objects dir: ${config.objectsDir}`);
  console.log(`  Allowed numbers: ${config.allowedNumbers.length === 0 ? "all" : config.allowedNumbers.join(", ")}`);

  await startBaileysAdapter(config);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
