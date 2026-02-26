const TRUNCATION_MARKER = '\n\n[…truncated]';

export function normalizeSenderNumber(value) {
  if (typeof value !== 'string' || value.length === 0) return '';
  const withoutJidSuffix = value.split('@')[0] ?? '';
  return withoutJidSuffix.replace(/\D+/g, '');
}

export function extractTextMessage(msg) {
  const message = msg?.message;
  if (!message || typeof message !== 'object') return null;

  const directConversation = message.conversation;
  if (typeof directConversation === 'string' && directConversation.trim()) {
    return directConversation.trim();
  }

  const extendedText = message.extendedTextMessage?.text;
  if (typeof extendedText === 'string' && extendedText.trim()) {
    return extendedText.trim();
  }

  const ephemeralMessage = message.ephemeralMessage?.message;
  const ephemeralConversation = ephemeralMessage?.conversation;
  if (typeof ephemeralConversation === 'string' && ephemeralConversation.trim()) {
    return ephemeralConversation.trim();
  }

  const ephemeralExtendedText = ephemeralMessage?.extendedTextMessage?.text;
  if (typeof ephemeralExtendedText === 'string' && ephemeralExtendedText.trim()) {
    return ephemeralExtendedText.trim();
  }

  return null;
}

export function isSenderAllowed(senderJid, allowedNumbers) {
  const normalized = normalizeSenderNumber(senderJid);
  return normalized.length > 0 && allowedNumbers.has(normalized);
}

export function isDirectUserJid(senderJid) {
  return typeof senderJid === 'string' && senderJid.endsWith('@s.whatsapp.net');
}

export function truncateReply(reply, maxChars) {
  const text = String(reply ?? '').trim();
  if (text.length <= maxChars) return text;

  if (maxChars <= 0) return '';
  const head = text.slice(0, maxChars);
  return `${head}${TRUNCATION_MARKER}`;
}

export { TRUNCATION_MARKER };
