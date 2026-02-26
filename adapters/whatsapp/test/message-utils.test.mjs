import test from 'node:test';
import assert from 'node:assert/strict';

import {
  extractTextMessage,
  normalizeSenderNumber,
  isSenderAllowed,
  isDirectUserJid,
  truncateReply,
} from '../src/message-utils.mjs';

test('extractTextMessage: happy path reads conversation and extended text', () => {
  const conversation = extractTextMessage({ message: { conversation: 'hello' } });
  const extended = extractTextMessage({
    message: { extendedTextMessage: { text: 'world' } },
  });

  assert.equal(conversation, 'hello');
  assert.equal(extended, 'world');
});

test('extractTextMessage: failure path returns null for unsupported payload', () => {
  assert.equal(extractTextMessage({ message: { imageMessage: {} } }), null);
});

test('isSenderAllowed: edge path normalizes JID and matches allowlist', () => {
  const allowed = new Set(['40722000111']);
  assert.equal(normalizeSenderNumber('40722000111@s.whatsapp.net'), '40722000111');
  assert.equal(isSenderAllowed('40722000111@s.whatsapp.net', allowed), true);
  assert.equal(isSenderAllowed('40722000112@s.whatsapp.net', allowed), false);
});

test('isDirectUserJid: failure path rejects groups and non-whatsapp IDs', () => {
  assert.equal(isDirectUserJid('40722000111@s.whatsapp.net'), true);
  assert.equal(isDirectUserJid('123456-12345@g.us'), false);
  assert.equal(isDirectUserJid('invalid'), false);
});

test('truncateReply: edge path truncates long payload with marker', () => {
  const source = 'x'.repeat(12);
  const out = truncateReply(source, 10);

  assert.equal(out.endsWith('\n\n[…truncated]'), true);
  assert.equal(out.length <= 10 + '\n\n[…truncated]'.length, true);
});
