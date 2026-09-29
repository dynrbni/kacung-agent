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
