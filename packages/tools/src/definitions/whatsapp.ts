import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@kacung/types';
import { WhatsAppController, WhatsAppMessageResult } from '../whatsapp/controller.js';

// ----------------------------------------------------------------------------
// Open WhatsApp Tool
// ----------------------------------------------------------------------------
export const openWhatsAppTool: ToolDefinition<Record<string, never>, { target: string; message: string }> = {
  name: 'open_whatsapp',
  description: 'Opens WhatsApp Desktop application or WhatsApp Web in the browser.',
  permissionLevel: 'SAFE',
  parameters: {
    type: 'object',
    properties: {},
  },
  async execute(_params: Record<string, never>, context: ToolExecutionContext): Promise<ToolResult<{ target: string; message: string }>> {
    const controller = new WhatsAppController(context.logger);
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
    const controller = new WhatsAppController(context.logger);
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
    const controller = new WhatsAppController(context.logger);
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
export interface SendWhatsAppMessageParams {
  contact: string;
  message: string;
}

export const sendWhatsAppMessageTool: ToolDefinition<SendWhatsAppMessageParams, WhatsAppMessageResult> = {
  name: 'send_whatsapp_message',
  description: 'Sends a WhatsApp text message to a contact. Prompts for user confirmation before dispatching.',
  permissionLevel: 'SENSITIVE',
  parameters: {
    type: 'object',
    properties: {
      contact: {
        type: 'string',
        description: 'Recipient contact name (e.g. "Andi", "Budi").',
      },
      message: {
        type: 'string',
        description: 'The message body to send (e.g. "Gue telat 15 menit.").',
      },
    },
    required: ['contact', 'message'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.contact || typeof p.contact !== 'string') {
      return { valid: false, error: 'contact is required' };
    }
    if (!p.message || typeof p.message !== 'string') {
      return { valid: false, error: 'message is required' };
    }
    return { valid: true };
  },
  async execute(params: SendWhatsAppMessageParams, context: ToolExecutionContext): Promise<ToolResult<WhatsAppMessageResult>> {
    const { contact, message } = params;
    context.logger.info(`send_whatsapp_message requested for "${contact}": "${message}"`);

    // Safety confirmation flow
    if (context.requestConfirmation) {
      const prompt = `Gue akan kirim ke ${contact}: "${message}". Kirim sekarang?`;
      const approved = await context.requestConfirmation({
        toolName: 'send_whatsapp_message',
        parameters: { contact, message },
        permissionLevel: 'SENSITIVE',
        description: prompt,
      });

      if (!approved) {
        return {
          success: false,
          error: `Pengiriman pesan ke "${contact}" dibatalkan oleh pengguna.`,
          data: {
            recipient: contact,
            text: message,
            sent: false,
            verified: false,
            details: 'Dibatalkan oleh pengguna.',
          },
        };
      }
    }

    const controller = new WhatsAppController(context.logger);
    const result = await controller.sendMessage(contact, message);

    return {
      success: result.sent,
      data: result,
      error: result.sent ? undefined : result.details,
    };
  },
};
