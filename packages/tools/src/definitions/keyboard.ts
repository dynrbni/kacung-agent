import { execFile } from 'child_process';
import { promisify } from 'util';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@kacung/types';

const execFileAsync = promisify(execFile);

// ----------------------------------------------------------------------------
// Type Text Tool
// ----------------------------------------------------------------------------
export interface TypeTextParams {
  text: string;
}

export const typeTextTool: ToolDefinition<TypeTextParams, { text: string; message: string }> = {
  name: 'type_text',
  description: 'Types a string of text into the currently active macOS application or focused field.',
  permissionLevel: 'SENSITIVE',
  parameters: {
    type: 'object',
    properties: {
      text: {
        type: 'string',
        description: 'The exact string of text to type.',
      },
    },
    required: ['text'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (typeof p.text !== 'string') {
      return { valid: false, error: 'text must be a string' };
    }
    return { valid: true };
  },
  async execute(params: TypeTextParams, context: ToolExecutionContext): Promise<ToolResult<{ text: string; message: string }>> {
    const text = params.text;
    context.logger.info(`Typing text (length: ${text.length})`);

    // Escape backslashes and double quotes for AppleScript string literal
    const escaped = text.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    const appleScript = `tell application "System Events" to keystroke "${escaped}"`;

    try {
      await execFileAsync('osascript', ['-e', appleScript]);
      return {
        success: true,
        data: { text, message: `Successfully typed text.` },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Type text failed: ${msg}`);
      return { success: false, error: `Type text failed: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Press Key Tool
// ----------------------------------------------------------------------------
export interface PressKeyParams {
  key: string;
  modifiers?: Array<'command' | 'control' | 'option' | 'shift'>;
}

const KEY_CODE_MAP: Record<string, number> = {
  return: 36,
  enter: 36,
  tab: 48,
  space: 49,
  delete: 51,
  backspace: 51,
  escape: 53,
  esc: 53,
  command: 55,
  cmd: 55,
  shift: 56,
  capslock: 57,
  option: 58,
  alt: 58,
  control: 59,
  ctrl: 59,
  left: 123,
  right: 124,
  down: 125,
  up: 126,
};

export const pressKeyTool: ToolDefinition<PressKeyParams, { key: string; message: string }> = {
  name: 'press_key',
  description: 'Simulates pressing a single keyboard key (e.g. "return", "escape", "space", "tab", "up", "down") with optional modifiers ("command", "control", "option", "shift").',
  permissionLevel: 'SENSITIVE',
  parameters: {
    type: 'object',
    properties: {
      key: {
        type: 'string',
        description: 'The key name to press (e.g. "return", "escape", "tab", "space", "up", "down", "left", "right").',
      },
      modifiers: {
        type: 'array',
        items: {
          type: 'string',
          enum: ['command', 'control', 'option', 'shift'],
          description: 'Key modifier to hold while pressing the key',
        },
        description: 'Optional modifier keys to hold (e.g. ["command"])',
      },
    },
    required: ['key'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.key || typeof p.key !== 'string') {
      return { valid: false, error: 'key is required and must be a string' };
    }
    return { valid: true };
  },
  async execute(params: PressKeyParams, context: ToolExecutionContext): Promise<ToolResult<{ key: string; message: string }>> {
    const rawKey = params.key.toLowerCase().trim();
    const modifiers = params.modifiers || [];

    context.logger.info(`Pressing key: ${rawKey} with modifiers: ${modifiers.join(', ') || 'none'}`);

    const modifierClause = modifiers.length > 0
      ? ` using {${modifiers.map((m) => `${m} down`).join(', ')}}`
      : '';

    let script = '';
    const keyCode = KEY_CODE_MAP[rawKey];
    if (keyCode !== undefined) {
      script = `tell application "System Events" to key code ${keyCode}${modifierClause}`;
    } else {
      const escaped = rawKey.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
      script = `tell application "System Events" to keystroke "${escaped}"${modifierClause}`;
    }

    try {
      await execFileAsync('osascript', ['-e', script]);
      return {
        success: true,
        data: {
          key: rawKey,
          message: `Pressed key "${rawKey}" successfully.`,
        },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Press key failed: ${msg}`);
      return { success: false, error: `Press key failed: ${msg}` };
    }
  },
};
