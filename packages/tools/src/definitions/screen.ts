import { execFile } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import os from 'os';
import fs from 'fs';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@kacung/types';

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
    const destDir = path.join(os.tmpdir(), 'kacung-screenshots');

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
    const destDir = path.join(os.tmpdir(), 'kacung-screenshots');
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
