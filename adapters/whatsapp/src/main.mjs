import fs from 'node:fs/promises';
import path from 'node:path';

import makeWASocket, {
  DisconnectReason,
  makeCacheableSignalKeyStore,
  useMultiFileAuthState,
} from '@whiskeysockets/baileys';
import pino from 'pino';

import { parseAdapterConfig } from './config.mjs';
import {
  extractTextMessage,
  isDirectUserJid,
  isSenderAllowed,
  truncateReply,
} from './message-utils.mjs';
import { promptNixpi } from './pi-client.mjs';

const SEEN_ID_TTL_MS = 5 * 60 * 1000;

function cleanupSeenIds(seenIds, now) {
  for (const [id, timestamp] of seenIds.entries()) {
    if (now - timestamp > SEEN_ID_TTL_MS) {
      seenIds.delete(id);
    }
  }
}

function enqueueByChat(queueByJid, jid, task) {
  const previous = queueByJid.get(jid) ?? Promise.resolve();
  const next = previous.then(task, task);
  queueByJid.set(jid, next.catch(() => {}));
  return next;
}

async function startSocket(config, logger) {
  await fs.mkdir(config.stateDir, { recursive: true });
  const authDir = path.join(config.stateDir, 'auth');
  await fs.mkdir(authDir, { recursive: true });

  const { state, saveCreds } = await useMultiFileAuthState(authDir);

  const sock = makeWASocket({
    auth: {
      creds: state.creds,
      keys: makeCacheableSignalKeyStore(state.keys, logger),
    },
    logger,
    printQRInTerminal: true,
  });

  sock.ev.on('creds.update', saveCreds);

  return sock;
}

export async function startWhatsAppAdapter() {
  const config = parseAdapterConfig(process.env);
  const logger = pino({ level: process.env.NIXPI_WHATSAPP_LOG_LEVEL ?? 'info' });

  logger.info(
    {
      stateDir: config.stateDir,
      allowlistSize: config.allowedNumbers.size,
      piBin: config.piBin,
    },
    'Starting Nixpi WhatsApp adapter'
  );

  let sock = await startSocket(config, logger);
  const seenIds = new Map();
  const queueByJid = new Map();

  const bindSocketEvents = () => {
    sock.ev.on('connection.update', async ({ connection, lastDisconnect }) => {
      if (connection === 'open') {
        logger.info('WhatsApp connection open');
        return;
      }

      if (connection !== 'close') {
        return;
      }

      const statusCode = lastDisconnect?.error?.output?.statusCode;
      const shouldReconnect = statusCode !== DisconnectReason.loggedOut;

      if (!shouldReconnect) {
        logger.error('WhatsApp session logged out. Please re-link the device.');
        return;
      }

      logger.warn('WhatsApp connection closed; reconnecting...');
      sock = await startSocket(config, logger);
      bindSocketEvents();
    });

    sock.ev.on('messages.upsert', async ({ messages, type }) => {
      if (type !== 'notify') return;

      for (const msg of messages) {
        const messageId = msg?.key?.id;
        const remoteJid = msg?.key?.remoteJid;

        if (!messageId || !remoteJid || !msg.message || msg.key?.fromMe) {
          continue;
        }

        const now = Date.now();
        cleanupSeenIds(seenIds, now);
        if (seenIds.has(messageId)) {
          logger.debug({ messageId }, 'Skipping duplicate message ID');
          continue;
        }
        seenIds.set(messageId, now);

        if (!isDirectUserJid(remoteJid)) {
          logger.debug({ remoteJid }, 'Skipping non-direct WhatsApp chat');
          continue;
        }

        if (!isSenderAllowed(remoteJid, config.allowedNumbers)) {
          logger.warn({ remoteJid }, 'Sender blocked (not in allowlist)');
          continue;
        }

        const text = extractTextMessage(msg);
        if (!text) {
          logger.debug({ messageId }, 'Skipping non-text WhatsApp payload');
          continue;
        }

        enqueueByChat(queueByJid, remoteJid, async () => {
          try {
            const prompt = `[WhatsApp chat ${remoteJid}] ${text}`;
            const response = await promptNixpi(config.piBin, prompt);
            const reply = truncateReply(response || '✅ Done.', config.maxReplyChars);

            await sock.sendMessage(remoteJid, { text: reply });
          } catch (error) {
            logger.error({ error, remoteJid }, 'Failed to process WhatsApp message');
            await sock.sendMessage(remoteJid, {
              text: '⚠️ Adapter error while contacting Nixpi. Please retry.',
            });
          }
        }).catch((error) => {
          logger.error({ error, remoteJid }, 'Queue execution failed');
        });
      }
    });
  };

  bindSocketEvents();
}

if (import.meta.url === `file://${process.argv[1]}`) {
  startWhatsAppAdapter().catch((error) => {
    console.error('Fatal WhatsApp adapter error:', error);
    process.exit(1);
  });
}
