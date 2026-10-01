import type { ToolDefinition, ToolExecutionContext, ToolResult, WhatsAppMessageResult } from '@lofly/types';
import { WhatsAppController } from '../whatsapp/controller.js';
import { toolSafety } from '../safety/policy.js';

// ----------------------------------------------------------------------------
// Open WhatsApp Tool
// ----------------------------------------------------------------------------
export const openWhatsAppTool: ToolDefinition<Record<string, never>, { target: string; message: string }> = {
  name: 'open_whatsapp',
  description: 'Opens WhatsApp Desktop application or WhatsApp Web in the browser.',
  permissionLevel: 'SAFE',
  safety: toolSafety('external', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {},
  },
  async execute(_params: Record<string, never>, context: ToolExecutionContext): Promise<ToolResult<{ target: string; message: string }>> {
    const controller = new WhatsAppController(context.logger, context.policy);
    const res = await controller.openWhatsApp();
    return {
      success: true,
      data: res,
    };
  },
};

// ----------------------------------------------------------------------------
// Search WhatsApp Contact Tool
// ----------------------------------------------------------------------------
export interface SearchWhatsAppContactParams {
  name: string;
}

export const searchWhatsAppContactTool: ToolDefinition<SearchWhatsAppContactParams, { name: string; message: string }> = {
  name: 'search_whatsapp_contact',
  description: 'Searches for a person or chat in WhatsApp by contact name.',
  permissionLevel: 'SAFE',
  safety: toolSafety('external', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      name: {
        type: 'string',
        description: 'The name of the contact or group to search (e.g. "Andi", "Budi", "Keluarga").',
      },
    },
    required: ['name'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.name || typeof p.name !== 'string') {
      return { valid: false, error: 'name is required' };
    }
    return { valid: true };
  },
  async execute(params: SearchWhatsAppContactParams, context: ToolExecutionContext): Promise<ToolResult<{ name: string; message: string }>> {
    const controller = new WhatsAppController(context.logger, context.policy);
    const res = await controller.searchContact(params.name.trim());
    return {
      success: res.success,
      data: {
        name: params.name,
        message: res.message,
      },
    };
  },
};

// ----------------------------------------------------------------------------
// Open WhatsApp Chat Tool
// ----------------------------------------------------------------------------
export interface OpenWhatsAppChatParams {
  contact: string;
  phone?: string;
}

export const openWhatsAppChatTool: ToolDefinition<OpenWhatsAppChatParams, { contact: string; message: string }> = {
  name: 'open_whatsapp_chat',
  description: 'Opens a chat conversation with a specific contact or phone number in WhatsApp.',
  permissionLevel: 'SAFE',
  safety: toolSafety('external', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      contact: {
        type: 'string',
        description: 'Name of the contact or group to chat with.',
      },
      phone: {
        type: 'string',
        description: 'Optional phone number with country code (e.g. "628123456789").',
      },
    },
    required: ['contact'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.contact || typeof p.contact !== 'string') {
      return { valid: false, error: 'contact is required' };
    }
    return { valid: true };
  },
  async execute(params: OpenWhatsAppChatParams, context: ToolExecutionContext): Promise<ToolResult<{ contact: string; message: string }>> {
    const controller = new WhatsAppController(context.logger, context.policy);
    const res = await controller.openChat(params.contact.trim(), params.phone);
    return {
      success: res.success,
      data: {
        contact: params.contact,
        message: res.message,
      },
    };
  },
};

// ----------------------------------------------------------------------------
// Send WhatsApp Message Tool (SENSITIVE — With Explicit Confirmation)
// ----------------------------------------------------------------------------
// Send WhatsApp Message Tool (SENSITIVE — With Explicit Confirmation)
// ----------------------------------------------------------------------------
export interface SendWhatsAppMessageParams {
  recipient?: string;
  contact?: string; // alias for backward compatibility
  message: string;
}

export const sendWhatsAppMessageTool: ToolDefinition<SendWhatsAppMessageParams, WhatsAppMessageResult> = {
  name: 'send_whatsapp_message',
  description: 'Send a WhatsApp message to a specific recipient. Preserve the user\'s intended message content exactly.',
  permissionLevel: 'SENSITIVE',
  safety: toolSafety('external', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      recipient: {
        type: 'string',
        minLength: 1,
        description: 'Recipient contact name (e.g. "Reja Agung", "Dimas", "Andi").',
      },
      message: {
        type: 'string',
        minLength: 1,
        description: 'The exact message body to send. Must be preserved verbatim without truncation or summarization.',
      },
      contact: {
        type: 'string',
        description: 'Alias for recipient.',
      },
    },
    required: ['recipient', 'message'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    const target = typeof p.recipient === 'string' && p.recipient.trim()
      ? p.recipient.trim()
      : typeof p.contact === 'string' && p.contact.trim()
      ? p.contact.trim()
      : '';
    if (!target) {
      return { valid: false, error: 'recipient is required and must not be empty' };
    }
    if (!p.message || typeof p.message !== 'string' || !p.message.trim()) {
      return { valid: false, error: 'message is required and must not be empty' };
    }
    return { valid: true };
  },
  async execute(params: SendWhatsAppMessageParams, context: ToolExecutionContext): Promise<ToolResult<WhatsAppMessageResult>> {
    const recipient = (params.recipient || params.contact || '').trim();
    const message = (params.message || '').trim();

    if (!recipient) {
      return {
        success: false,
        error: 'Recipient is required',
        data: {
          recipient: '',
          text: message,
          sent: false,
          verified: false,
          details: 'Recipient is missing.',
        },
      };
    }

    if (!message) {
      return {
        success: false,
        error: 'Message is required and cannot be empty',
        data: {
          recipient,
          text: '',
          sent: false,
          verified: false,
          details: 'Message content is missing.',
        },
      };
    }

    context.logger.info(`send_whatsapp_message requested for "${recipient}": "${message}"`);

    // Safety confirmation flow
    if (context.requestConfirmation) {
      const prompt = `Gue akan kirim ke ${recipient}: "${message}". Kirim sekarang?`;
      const approved = await context.requestConfirmation({
        toolName: 'send_whatsapp_message',
        parameters: { recipient, message },
        permissionLevel: 'SENSITIVE',
        description: prompt,
      });

      if (!approved) {
        return {
          success: false,
          error: `Pengiriman pesan ke "${recipient}" dibatalkan oleh pengguna.`,
          data: {
            recipient,
            text: message,
            sent: false,
            verified: false,
            details: 'Dibatalkan oleh pengguna.',
          },
        };
      }
    }

    const controller = new WhatsAppController(context.logger, context.policy);
    const result = await controller.sendMessage(recipient, message);

    // A simulated send is a successful simulation, not a failed send. Callers
    // must be able to tell the two apart via result.data.executed.
    return {
      success: result.executed ? result.sent : true,
      data: result,
      error: result.executed && !result.sent ? result.details : undefined,
    };
  },
};
