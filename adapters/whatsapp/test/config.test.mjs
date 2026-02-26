import test from 'node:test';
import assert from 'node:assert/strict';

import { parseAdapterConfig } from '../src/config.mjs';

test('parseAdapterConfig: happy path parses and normalizes env', () => {
  const cfg = parseAdapterConfig({
    HOME: '/home/alex',
    NIXPI_WHATSAPP_ALLOWED_NUMBERS: ' +40 722 000 111,40722000111@s.whatsapp.net ',
    NIXPI_WHATSAPP_PI_BIN: 'nixpi',
    NIXPI_WHATSAPP_MAX_REPLY_CHARS: '1200',
  });

  assert.equal(cfg.stateDir, '/home/alex/.local/share/nixpi/whatsapp');
  assert.equal(cfg.piBin, 'nixpi');
  assert.equal(cfg.maxReplyChars, 1200);
  assert.deepEqual([...cfg.allowedNumbers], ['40722000111']);
});

test('parseAdapterConfig: failure path when allowlist missing', () => {
  assert.throws(
    () => parseAdapterConfig({ HOME: '/home/alex' }),
    /NIXPI_WHATSAPP_ALLOWED_NUMBERS/
  );
});

test('parseAdapterConfig: edge case invalid max reply chars falls back to default', () => {
  const cfg = parseAdapterConfig({
    HOME: '/home/alex',
    NIXPI_WHATSAPP_ALLOWED_NUMBERS: '40722000111',
    NIXPI_WHATSAPP_MAX_REPLY_CHARS: 'abc',
  });

  assert.equal(cfg.maxReplyChars, 3500);
});
