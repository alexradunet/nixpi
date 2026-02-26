import path from 'node:path';

import { normalizeSenderNumber } from './message-utils.mjs';

export const DEFAULT_MAX_REPLY_CHARS = 3500;

function parseAllowedNumbers(rawAllowlist) {
  return new Set(
    String(rawAllowlist ?? '')
      .split(',')
      .map((value) => normalizeSenderNumber(value.trim()))
      .filter(Boolean)
  );
}

function parseMaxReplyChars(rawValue) {
  const parsed = Number.parseInt(String(rawValue ?? ''), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return DEFAULT_MAX_REPLY_CHARS;
  }
  return parsed;
}

export function parseAdapterConfig(env = process.env) {
  const allowedNumbers = parseAllowedNumbers(env.NIXPI_WHATSAPP_ALLOWED_NUMBERS);
  if (allowedNumbers.size === 0) {
    throw new Error(
      'NIXPI_WHATSAPP_ALLOWED_NUMBERS is required (comma-separated phone numbers, e.g. 40722000111,491234567890).'
    );
  }

  const home = env.HOME ?? process.cwd();

  return {
    stateDir:
      env.NIXPI_WHATSAPP_STATE_DIR ??
      path.join(home, '.local', 'share', 'nixpi', 'whatsapp'),
    piBin: env.NIXPI_WHATSAPP_PI_BIN ?? 'nixpi',
    maxReplyChars: parseMaxReplyChars(env.NIXPI_WHATSAPP_MAX_REPLY_CHARS),
    allowedNumbers,
  };
}
