import { execFile } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import os from 'os';
import fs from 'fs';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@lofly/types';
import { toolSafety } from '../safety/policy.js';

const execFileAsync = promisify(execFile);

export interface ScreenshotParams {
  includeBase64?: boolean;
}

export interface ScreenshotResultData {
  filePath: string;
  timestamp: number;
  base64?: string;
  sizeBytes?: number;
}

export const screenshotTool: ToolDefinition<ScreenshotParams, ScreenshotResultData> = {
  name: 'screenshot',
  description: 'Takes a screenshot of the main macOS display and saves it locally. Useful for inspecting current screen state or UI.',
  permissionLevel: 'SAFE',
  safety: toolSafety('none', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      includeBase64: {
        type: 'boolean',
        description: 'Whether to return the base64-encoded image string for vision processing.',
      },
    },
  },
  async execute(params: ScreenshotParams, context: ToolExecutionContext): Promise<ToolResult<ScreenshotResultData>> {
    context.logger.info('Capturing macOS screen');
    const timestamp = Date.now();
    const destDir = path.join(os.tmpdir(), 'lofly-screenshots');

    try {
      if (!fs.existsSync(destDir)) {
        fs.mkdirSync(destDir, { recursive: true });
      }

      const filePath = path.join(destDir, `screen-${timestamp}.png`);

      // Use native macOS screencapture (-x = silent, no sound)
      await execFileAsync('screencapture', ['-x', filePath]);

      const stat = fs.statSync(filePath);
      let base64: string | undefined;

      if (params?.includeBase64) {
        const buffer = fs.readFileSync(filePath);
        base64 = buffer.toString('base64');
      }

      context.logger.info(`Screenshot captured at: ${filePath} (${stat.size} bytes)`);

      return {
        success: true,
        data: {
          filePath,
          timestamp,
          sizeBytes: stat.size,
          base64,
        },
      };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      context.logger.error(`Screenshot failed: ${message}`);
      return {
        success: false,
        error: `Failed to capture screenshot: ${message}`,
      };
    }
  },
};

export interface ScreenshotAppParams {
  appName: string;
  includeBase64?: boolean;
}

export const screenshotAppTool: ToolDefinition<ScreenshotAppParams, ScreenshotResultData & { appName: string }> = {
  name: 'screenshot_app',
  description: 'Brings a specific application to front and captures a screenshot of its window or area.',
  permissionLevel: 'SAFE',
  safety: toolSafety('none', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      appName: {
        type: 'string',
        description: 'Name of the macOS application to capture (e.g. "Spotify", "Safari", "WhatsApp").',
      },
      includeBase64: {
        type: 'boolean',
        description: 'Whether to return the base64-encoded image string for vision processing.',
      },
    },
    required: ['appName'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.appName || typeof p.appName !== 'string' || p.appName.trim() === '') {
      return { valid: false, error: 'appName is required' };
    }
    return { valid: true };
  },
  async execute(params: ScreenshotAppParams, context: ToolExecutionContext): Promise<ToolResult<ScreenshotResultData & { appName: string }>> {
    const appName = params.appName.trim();
    context.logger.info(`Capturing screenshot for application: ${appName}`);

    // Activate the app first
    try {
      await execFileAsync('osascript', ['-e', `tell application "${appName.replace(/"/g, '\\"')}" to activate`]);
      // Small pause for window rendering
      await new Promise((resolve) => setTimeout(resolve, 300));
    } catch (err) {
      context.logger.warn(`Could not activate app ${appName}: ${err}`);
    }

    const timestamp = Date.now();
    const destDir = path.join(os.tmpdir(), 'lofly-screenshots');
    if (!fs.existsSync(destDir)) {
      fs.mkdirSync(destDir, { recursive: true });
    }
    const filePath = path.join(destDir, `app-${appName.toLowerCase().replace(/\s+/g, '-')}-${timestamp}.png`);

    try {
      await execFileAsync('screencapture', ['-x', filePath]);
      const stat = fs.statSync(filePath);
      let base64: string | undefined;

      if (params?.includeBase64) {
        const buffer = fs.readFileSync(filePath);
        base64 = buffer.toString('base64');
      }

      return {
        success: true,
        data: {
          appName,
          filePath,
          timestamp,
          sizeBytes: stat.size,
          base64,
        },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return {
        success: false,
        error: `Failed to screenshot app "${appName}": ${msg}`,
      };
    }
  },
};

export interface LocateOnScreenParams {
  appName?: string;
  query?: string;
}

export const locateOnScreenTool: ToolDefinition<LocateOnScreenParams, any> = {
  name: 'locate_on_screen',
  description: 'Locates text and interactive elements on screen or inside a specific application window using native macOS Vision OCR. Returns screen coordinates (x, y, width, height, centerX, centerY) and confidence.',
  permissionLevel: 'SAFE',
  safety: toolSafety('none', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      appName: {
        type: 'string',
        description: 'Optional name of the target application window to scan (e.g. "WhatsApp", "Spotify", "Safari"). If omitted, scans the frontmost window/screen.',
      },
      query: {
        type: 'string',
        description: 'Optional text or substring to search for (e.g. "Search", "Send", contact name).',
      },
    },
  },
  async execute(params: LocateOnScreenParams, context: ToolExecutionContext) {
    const { locateOnScreen } = await import('../vision/ocr.js');
    context.logger.info(`Locating text on screen for app: ${params?.appName || 'any'}, query: "${params?.query || ''}"`);
    try {
      const result = await locateOnScreen(params?.appName, params?.query);
      return {
        success: true,
        data: result,
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return {
        success: false,
        error: `Failed to locate elements on screen: ${msg}`,
      };
    }
  },
};

export interface ClickElementByTextParams {
  text: string;
  appName?: string;
}

export const clickElementByTextTool: ToolDefinition<ClickElementByTextParams, { clicked: boolean; x?: number; y?: number }> = {
  name: 'click_element_by_text',
  description: 'Finds an element or button on the screen matching the specified text using macOS Vision OCR and simulates a mouse click on it.',
  permissionLevel: 'SENSITIVE',
  safety: toolSafety('external', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      text: {
        type: 'string',
        description: 'The visible label, button text, or name to click (e.g. "Search", contact name, "Play").',
      },
      appName: {
        type: 'string',
        description: 'Optional application name to focus before clicking (e.g. "WhatsApp").',
      },
    },
    required: ['text'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.text || typeof p.text !== 'string' || p.text.trim() === '') {
      return { valid: false, error: 'text is required' };
    }
    return { valid: true };
  },
  async execute(params: ClickElementByTextParams, context: ToolExecutionContext) {
    const { clickTextOnScreen } = await import('../vision/ocr.js');
    const appName = params.appName?.trim() || '';
    const text = params.text.trim();
    context.logger.info(`Clicking element by text: "${text}" in ${appName || 'current window'}`);

    try {
      const res = await clickTextOnScreen(appName, text);
      if (res.clicked) {
        return {
          success: true,
          data: res,
        };
      }
      return {
        success: false,
        error: `Could not find text "${text}" on screen to click.`,
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return {
        success: false,
        error: `Click element by text failed: ${msg}`,
      };
    }
  },
};

