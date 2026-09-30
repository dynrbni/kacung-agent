import type {
  StructuredActionIntent,
  CommandParseResult,
  WhatsAppIntentValidation,
} from '@kacung/types';
import { validateWhatsAppIntent } from './validator.js';

/**
 * Message intent markers in Indonesian and English.
 * Ordered by specificity (longer compound markers first).
 */
const MESSAGE_MARKER_PATTERNS = [
  // Indonesian compound markers with connectors
  /\b(?:terus|trus|habis\s+itu|lalu|kemudian|sekalian|sama|dan)\s+(?:send\s+message\s+bilang|message\s+bilang)\b/i,
  /\b(?:terus|trus|habis\s+itu|lalu|kemudian|sekalian|sama|dan)\s+(?:bilang|tulis|katakan|kirim\s+pesan|kirim\s+chat)\b/i,
  /\b(?:isi\s+pesannya|dengan\s+isi|dengan\s+pesan)\b/i,
  // Single Indonesian markers
  /\b(?:bilang|tulis|katakan|kirim\s+pesan|kirim\s+chat)\b/i,
  // English & code-switching compound markers
  /\b(?:and\s+tell\s+(?:him|her|them)|tell\s+(?:him|her|them)|and\s+tell)\b/i,
  /\b(?:send\s+a\s+message\s+saying|message\s+(?:him|her|them)\s+saying|text\s+(?:him|her|them)\s+saying)\b/i,
  /\b(?:saying|and\s+saying)\b/i,
  /\b(?:say|tell)\b/i,
];

/**
 * Action prefix matcher for messaging commands.
 */
const MESSAGING_PREFIX_PATTERNS = [
  // "WhatsApp Reja Agung", "Open WhatsApp terus message Reja Agung"
  /^(?:coba\s+|tolong\s+|please\s+)?(?:open\s+|buka\s+)?whatsapp(?:\s+(?:terus|trus|lalu|and|then)\s+(?:send\s+message|message|chat))?(?:\s+(?:ke|to))?\s+/i,
  // "Chat Reja Agung", "Chat ke Reja Agung"
  /^(?:coba\s+|tolong\s+|please\s+)?chat(?:\s+(?:ke|to))?\s+/i,
  // "WA-in Dimas", "Wain Dimas"
  /^(?:coba\s+|tolong\s+|please\s+)?wa-?in(?:\s+(?:ke|to))?\s+/i,
  // "Kirim WA ke Reja Agung", "Kirim pesan ke Reja Agung", "Kirim chat ke Reja Agung"
  /^(?:coba\s+|tolong\s+|please\s+)?kirim\s+(?:wa|pesan|chat)(?:\s+(?:ke|to))?\s+/i,
  // "Message John", "Text John"
  /^(?:coba\s+|tolong\s+|please\s+)?(?:message|text)(?:\s+(?:ke|to))?\s+/i,
];

/**
 * Multi-action subsequent command matcher:
 * Looks for e.g. "terus buka Spotify" or "lalu putar musik" after a message.
 */
const SUBSEQUENT_ACTION_REGEX = /\s+(?:terus|trus|lalu|habis\s+itu|kemudian|then|and\s+then)\s+(buka|open|tutup|close|putar|play)\s+([^,.]+)/i;

/**
 * Parses raw or normalized user voice transcript into structured command intents.
 * Strictly separates recipient, intent, and verbatim message payload.
 */
export function parseCommand(transcript: string): CommandParseResult {
  const rawTranscript = transcript || '';
  const trimmed = rawTranscript.trim();

  if (!trimmed) {
    return {
      rawTranscript,
      normalizedTranscript: '',
      actions: [],
      isStructured: false,
    };
  }

  // 1. Check for messaging command prefixes
  let matchedPrefix: RegExp | null = null;
  let remainingAfterPrefix = '';

  for (const pattern of MESSAGING_PREFIX_PATTERNS) {
    const match = trimmed.match(pattern);
    if (match) {
      matchedPrefix = pattern;
      remainingAfterPrefix = trimmed.slice(match[0].length);
      break;
    }
  }

  // If no messaging prefix matched, check if it's a direct WhatsApp action without spaces or punctuation
  if (!matchedPrefix) {
    return {
      rawTranscript,
      normalizedTranscript: trimmed,
      actions: [],
      isStructured: false,
    };
  }

  // 2. Identify message intent marker within the remainder
  let bestMarkerMatch: { index: number; length: number; text: string } | null = null;

  for (const markerPattern of MESSAGE_MARKER_PATTERNS) {
    const m = remainingAfterPrefix.match(markerPattern);
    if (m && m.index !== undefined) {
      // Pick earliest marker
      if (!bestMarkerMatch || m.index < bestMarkerMatch.index) {
        bestMarkerMatch = {
          index: m.index,
          length: m[0].length,
          text: m[0],
        };
      }
    }
  }

  // Case A: Message marker detected (e.g. "... terus bilang Yuli bubur")
  if (bestMarkerMatch) {
    let recipientRaw = remainingAfterPrefix.slice(0, bestMarkerMatch.index).trim();
    const rawPayload = remainingAfterPrefix.slice(bestMarkerMatch.index + bestMarkerMatch.length).trim();

    // Clean up recipient name: remove leading/trailing punctuation and colloquial noise
    recipientRaw = cleanRecipientName(recipientRaw);

    // Parse message payload & check for subsequent multi-action commands
    const { message, subsequentAction } = parsePayloadAndSubsequentActions(rawPayload);

    const actions: StructuredActionIntent[] = [];
    let validation: WhatsAppIntentValidation;

    if (!message) {
      // Marker exists, but message body is missing (e.g. "WhatsApp Reja Agung terus bilang")
      const primary: StructuredActionIntent = {
        intent: 'send_whatsapp_message',
        recipient: recipientRaw,
        message: '',
        rawMarker: bestMarkerMatch.text,
      };
      validation = validateWhatsAppIntent(primary);
      actions.push(primary);

      return {
        rawTranscript,
        normalizedTranscript: trimmed,
        actions,
        isStructured: true,
        primaryIntent: primary,
        validation,
      };
    }

    // Full valid message intent
    const primaryIntent: StructuredActionIntent = {
      intent: 'send_whatsapp_message',
      recipient: recipientRaw,
      message,
      rawMarker: bestMarkerMatch.text,
    };

    validation = validateWhatsAppIntent(primaryIntent);
    actions.push(primaryIntent);

    if (subsequentAction) {
      actions.push(subsequentAction);
    }

    return {
      rawTranscript,
      normalizedTranscript: trimmed,
      actions,
      isStructured: true,
      primaryIntent,
      validation,
    };
  }

  // Case B: No message marker present (e.g. "WhatsApp Reja Agung" or "Chat Dimas")
  const recipient = cleanRecipientName(remainingAfterPrefix);

  const primaryIntent: StructuredActionIntent = {
    intent: 'open_whatsapp_chat',
    recipient,
    messageMissing: true,
  };

  const validation: WhatsAppIntentValidation = {
    valid: false,
    reason: 'message_missing',
    recipient,
    message: '',
  };

  return {
    rawTranscript,
    normalizedTranscript: trimmed,
    actions: [primaryIntent],
    isStructured: true,
    primaryIntent,
    validation,
  };
}

/**
 * Strips connectors, prepositions, and trailing punctuation from recipient name.
 */
function cleanRecipientName(raw: string): string {
  let cleaned = raw.replace(/^[,:\s]+|[,:\s]+$/g, '');

  // Strip leading "ke " or "to "
  cleaned = cleaned.replace(/^(?:ke|to)\s+/i, '');

  // Strip trailing "di WhatsApp", "lewat WhatsApp", "via WhatsApp", "on WhatsApp"
  cleaned = cleaned.replace(/\s+(?:di|lewat|via|on|through)\s+(?:whatsapp|wa)$/i, '');

  // Strip trailing connectors before marker e.g. "Reja Agung terus send message" -> "Reja Agung"
  cleaned = cleaned.replace(/\s+(?:terus|trus|lalu|and|then)?\s*(?:send\s+message|message|chat)$/i, '');

  // Strip trailing punctuation
  cleaned = cleaned.replace(/[,.]/g, '').trim();

  return cleaned;
}

/**
 * Inspects the message payload to ensure subsequent multi-actions
 * (e.g. "terus buka Spotify") are not included in the message itself.
 */
function parsePayloadAndSubsequentActions(rawPayload: string): {
  message: string;
  subsequentAction?: StructuredActionIntent;
} {
  // Strip optional leading colon or quote: e.g. ": Yuli bubur" -> "Yuli bubur"
  let cleanMsg = rawPayload.replace(/^[:"'“”\s]+/, '').replace(/["'“”\s]+$/, '');

  const match = cleanMsg.match(SUBSEQUENT_ACTION_REGEX);
  if (!match || match.index === undefined) {
    return { message: cleanMsg };
  }

  // Split: message is everything before the subsequent action connector
  const messagePart = cleanMsg.slice(0, match.index).trim();
  const verb = match[1].toLowerCase();
  const target = match[2].trim();

  let subsequentAction: StructuredActionIntent | undefined;
  if (verb === 'buka' || verb === 'open') {
    subsequentAction = {
      intent: 'open_app',
      app: target,
    };
  } else if (verb === 'putar' || verb === 'play') {
    subsequentAction = {
      intent: 'play_music',
      query: target,
    };
  }

  return {
    message: messagePart,
    subsequentAction,
  };
}
