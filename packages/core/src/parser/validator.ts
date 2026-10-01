import type { StructuredActionIntent, WhatsAppIntentValidation } from '@lofly/types';

/**
 * Validates a parsed WhatsApp intent prior to execution.
 * Enforces:
 * 1. Intent exists
 * 2. Recipient exists and is non-empty
 * 3. Message exists and is non-empty
 *
 * If validation fails, DO NOT SEND.
 */
export function validateWhatsAppIntent(intent: StructuredActionIntent): WhatsAppIntentValidation {
  if (intent.intent !== 'send_whatsapp_message') {
    return {
      valid: false,
      reason: 'invalid_intent',
    };
  }

  const recipient = (intent.recipient || '').trim();
  const message = (intent.message || '').trim();

  if (!recipient) {
    return {
      valid: false,
      reason: 'recipient_missing',
      recipient: '',
      message,
    };
  }

  if (!message) {
    return {
      valid: false,
      reason: 'message_missing',
      recipient,
      message: '',
    };
  }

  return {
    valid: true,
    reason: 'ok',
    recipient,
    message,
  };
}
