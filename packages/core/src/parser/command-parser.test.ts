import { describe, it, expect } from 'vitest';
import { parseCommand } from './command-parser.js';
import { validateWhatsAppIntent } from './validator.js';
import { formatCommandTrace } from './trace.js';

describe('WhatsApp Command Parser & Structured Intent Pipeline', () => {
  it('Test 1: "WhatsApp Reja Agung terus bilang Yuli bubur" -> structured intent', () => {
    const input = 'WhatsApp Reja Agung terus bilang Yuli bubur';
    const result = parseCommand(input);

    expect(result.isStructured).toBe(true);
    expect(result.actions).toHaveLength(1);
    expect(result.primaryIntent).toEqual({
      intent: 'send_whatsapp_message',
      recipient: 'Reja Agung',
      message: 'Yuli bubur',
      rawMarker: 'terus bilang',
    });
    expect(result.validation?.valid).toBe(true);
  });

  it('Test 2: "Chat Reja Agung bilang gue telat" -> message: "gue telat"', () => {
    const input = 'Chat Reja Agung bilang gue telat';
    const result = parseCommand(input);

    expect(result.primaryIntent).toEqual({
      intent: 'send_whatsapp_message',
      recipient: 'Reja Agung',
      message: 'gue telat',
      rawMarker: 'bilang',
    });
    expect(result.validation?.valid).toBe(true);
  });

  it('Test 3: "WA-in Dimas bilang jangan lupa meeting jam 3" -> preserves full text', () => {
    const input = 'WA-in Dimas bilang jangan lupa meeting jam 3';
    const result = parseCommand(input);

    expect(result.primaryIntent).toEqual({
      intent: 'send_whatsapp_message',
      recipient: 'Dimas',
      message: 'jangan lupa meeting jam 3',
      rawMarker: 'bilang',
    });
    expect(result.validation?.valid).toBe(true);
  });

  it('Test 4: "WhatsApp John and tell him I\'ll be there in 10 minutes" -> English code-switching', () => {
    const input = "WhatsApp John and tell him I'll be there in 10 minutes";
    const result = parseCommand(input);

    expect(result.primaryIntent).toEqual({
      intent: 'send_whatsapp_message',
      recipient: 'John',
      message: "I'll be there in 10 minutes",
      rawMarker: 'and tell him',
    });
    expect(result.validation?.valid).toBe(true);
  });

  it('Test 5: "WhatsApp Reja Agung bilang Yuli bubur terus buka Spotify" -> multi-action', () => {
    const input = 'WhatsApp Reja Agung bilang Yuli bubur terus buka Spotify';
    const result = parseCommand(input);

    expect(result.actions).toHaveLength(2);
    expect(result.actions[0]).toEqual({
      intent: 'send_whatsapp_message',
      recipient: 'Reja Agung',
      message: 'Yuli bubur',
      rawMarker: 'bilang',
    });
    expect(result.actions[1]).toEqual({
      intent: 'open_app',
      app: 'Spotify',
    });
  });

  it('Test 6: "WhatsApp Reja Agung" -> message missing, DO NOT SEND', () => {
    const input = 'WhatsApp Reja Agung';
    const result = parseCommand(input);

    expect(result.isStructured).toBe(true);
    expect(result.primaryIntent?.intent).toBe('open_whatsapp_chat');
    expect(result.validation?.valid).toBe(false);
    expect(result.validation?.reason).toBe('message_missing');
    expect(result.validation?.recipient).toBe('Reja Agung');
  });

  it('Test 7: "WhatsApp Reja Agung terus bilang" -> message missing, DO NOT SEND', () => {
    const input = 'WhatsApp Reja Agung terus bilang';
    const result = parseCommand(input);

    expect(result.isStructured).toBe(true);
    expect(result.validation?.valid).toBe(false);
    expect(result.validation?.reason).toBe('message_missing');
    expect(result.validation?.recipient).toBe('Reja Agung');
  });

  it('Test 8: "Chat Reja Agung bilang" -> message missing, DO NOT SEND', () => {
    const input = 'Chat Reja Agung bilang';
    const result = parseCommand(input);

    expect(result.isStructured).toBe(true);
    expect(result.validation?.valid).toBe(false);
    expect(result.validation?.reason).toBe('message_missing');
    expect(result.validation?.recipient).toBe('Reja Agung');
  });

  it('Test 9: "WhatsApp Reja Agung bilang gue udh otw bro" -> preserves slang verbatim', () => {
    const input = 'WhatsApp Reja Agung bilang gue udh otw bro';
    const result = parseCommand(input);

    expect(result.primaryIntent).toEqual({
      intent: 'send_whatsapp_message',
      recipient: 'Reja Agung',
      message: 'gue udh otw bro',
      rawMarker: 'bilang',
    });
    expect(result.validation?.valid).toBe(true);
  });

  it('Test 10: "WhatsApp Reja Agung trus bilang Yuli bubur" -> matches Test 1', () => {
    const input = 'WhatsApp Reja Agung trus bilang Yuli bubur';
    const result = parseCommand(input);

    expect(result.primaryIntent).toEqual({
      intent: 'send_whatsapp_message',
      recipient: 'Reja Agung',
      message: 'Yuli bubur',
      rawMarker: 'trus bilang',
    });
    expect(result.validation?.valid).toBe(true);
  });

  it('Additional: "Kirim WA ke Reja Agung bilang Yuli bubur"', () => {
    const input = 'Kirim WA ke Reja Agung bilang Yuli bubur';
    const result = parseCommand(input);

    expect(result.primaryIntent).toEqual({
      intent: 'send_whatsapp_message',
      recipient: 'Reja Agung',
      message: 'Yuli bubur',
      rawMarker: 'bilang',
    });
  });

  it('Additional: "WhatsApp Dimas terus tulis nanti gue datang"', () => {
    const input = 'WhatsApp Dimas terus tulis nanti gue datang';
    const result = parseCommand(input);

    expect(result.primaryIntent).toEqual({
      intent: 'send_whatsapp_message',
      recipient: 'Dimas',
      message: 'nanti gue datang',
      rawMarker: 'terus tulis',
    });
  });

  it('Additional: "Open WhatsApp terus message Reja Agung bilang gue OTW"', () => {
    const input = 'Open WhatsApp terus message Reja Agung bilang gue OTW';
    const result = parseCommand(input);

    expect(result.primaryIntent).toEqual({
      intent: 'send_whatsapp_message',
      recipient: 'Reja Agung',
      message: 'gue OTW',
      rawMarker: 'bilang',
    });
  });

  it('Validation helper enforces required recipient and message', () => {
    expect(
      validateWhatsAppIntent({
        intent: 'send_whatsapp_message',
        recipient: '',
        message: 'hello',
      }).valid
    ).toBe(false);

    expect(
      validateWhatsAppIntent({
        intent: 'send_whatsapp_message',
        recipient: 'Budi',
        message: '   ',
      }).valid
    ).toBe(false);
  });

  it('Format command trace produces readable structured logs', () => {
    const trace = formatCommandTrace({
      rawTranscript: 'whatsapp reja agung trus bilang yuli bubur',
      parsedIntent: {
        intent: 'send_whatsapp_message',
        recipient: 'Reja Agung',
        message: 'Yuli bubur',
      },
      validation: {
        recipient: 'valid',
        message: 'valid',
      },
      contactResolution: {
        query: 'Reja Agung',
        resolved: true,
      },
      execution: {
        tool: 'send_whatsapp_message',
        parameters: { recipient: 'Reja Agung', message: 'Yuli bubur' },
      },
      result: {
        success: true,
        details: 'Sent',
      },
    });

    expect(trace).toContain('RAW TRANSCRIPT:');
    expect(trace).toContain('"whatsapp reja agung trus bilang yuli bubur"');
    expect(trace).toContain('intent = send_whatsapp_message');
    expect(trace).toContain('recipient = Reja Agung');
    expect(trace).toContain('message = Yuli bubur');
  });

  it('Test 13: "kirim whatsapp ke reja agung tentang bahayanya rokok lu ambil aja ringkasannya dari google" -> clean recipient & isDynamicGeneration', () => {
    const input = 'kirim whatsapp ke reja agung tentang bahayanya rokok lu ambil aja ringkasannya dari google';
    const result = parseCommand(input);

    expect(result.isStructured).toBe(true);
    expect(result.primaryIntent?.intent).toBe('send_whatsapp_message');
    if (result.primaryIntent?.intent === 'send_whatsapp_message') {
      expect(result.primaryIntent.recipient).toBe('reja agung');
      expect(result.primaryIntent.rawMarker).toBe('tentang');
      expect(result.primaryIntent.message).toContain('bahayanya rokok');
      expect(result.primaryIntent.isDynamicGeneration).toBe(true);
    }
  });

  it('Test 14: "Chat Reja Agung buat kasih tahu bahayanya ngerokok" -> separates contact from topic', () => {
    const input = 'Chat Reja Agung buat kasih tahu bahayanya ngerokok';
    const result = parseCommand(input);

    expect(result.isStructured).toBe(true);
    expect(result.primaryIntent?.intent).toBe('send_whatsapp_message');
    if (result.primaryIntent?.intent === 'send_whatsapp_message') {
      expect(result.primaryIntent.recipient).toBe('Reja Agung');
      expect(result.primaryIntent.message).toBe('bahayanya ngerokok');
    }
  });

  it('Test 15: "Kirim WhatsApp ke Reja Agung isi mess nya" -> detects missing message with clean recipient', () => {
    const input = 'Kirim WhatsApp ke Reja Agung isi mess nya';
    const result = parseCommand(input);

    expect(result.isStructured).toBe(true);
    if (result.primaryIntent?.intent === 'send_whatsapp_message') {
      expect(result.primaryIntent.recipient).toBe('Reja Agung');
      expect(result.primaryIntent.message).toBe('');
    }
    expect(result.validation?.valid).toBe(false);
    expect(result.validation?.reason).toBe('message_missing');
  });
});

