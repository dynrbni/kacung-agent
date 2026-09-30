import { execFile } from 'child_process';
import { promisify } from 'util';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@lafly/types';
import { toolSafety } from '../safety/policy.js';

const execFileAsync = promisify(execFile);

export interface WaitParams {
  ms: number;
}

export const waitTool: ToolDefinition<WaitParams, { waitedMs: number; message: string }> = {
  name: 'wait',
  description: 'Pauses execution for a specified duration in milliseconds (e.g. 1000 for 1 second) to allow applications to launch or UI to update.',
  permissionLevel: 'SAFE',
  safety: toolSafety('none', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      ms: {
        type: 'number',
        description: 'Duration to wait in milliseconds (max 10000ms).',
      },
    },
    required: ['ms'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (typeof p.ms !== 'number' || isNaN(p.ms) || p.ms < 0) {
      return { valid: false, error: 'ms must be a non-negative number' };
    }
    return { valid: true };
  },
  async execute(params: WaitParams, context: ToolExecutionContext): Promise<ToolResult<{ waitedMs: number; message: string }>> {
    const cappedMs = Math.min(Math.max(params.ms, 50), 10000);
    context.logger.info(`Waiting for ${cappedMs}ms`);
    await new Promise((resolve) => setTimeout(resolve, cappedMs));
    return {
      success: true,
      data: {
        waitedMs: cappedMs,
        message: `Waited for ${cappedMs}ms.`,
      },
    };
  },
};

export interface WaitForAppParams {
  appName: string;
  timeoutMs?: number;
}

export const waitForAppTool: ToolDefinition<WaitForAppParams, { appName: string; running: boolean; waitedMs: number }> = {
  name: 'wait_for_app',
  description: 'Waits until a target macOS application is running or until timeout.',
  permissionLevel: 'SAFE',
  safety: toolSafety('none', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      appName: {
        type: 'string',
        description: 'Name of the application to wait for (e.g. "Spotify", "WhatsApp").',
      },
      timeoutMs: {
        type: 'number',
        description: 'Maximum time to wait in milliseconds (default: 5000ms, max 15000ms).',
      },
    },
    required: ['appName'],
  },
  async execute(params: WaitForAppParams, context: ToolExecutionContext): Promise<ToolResult<{ appName: string; running: boolean; waitedMs: number }>> {
    const appName = params.appName.trim();
    const timeout = Math.min(params.timeoutMs || 5000, 15000);
    const start = Date.now();

    context.logger.info(`Waiting for app "${appName}" to launch (timeout: ${timeout}ms)`);

    while (Date.now() - start < timeout) {
      try {
        const { stdout } = await execFileAsync('pgrep', ['-ix', appName]);
        if (stdout.trim().length > 0) {
          return {
            success: true,
            data: {
              appName,
              running: true,
              waitedMs: Date.now() - start,
            },
          };
        }
      } catch {
        // App not found yet
      }
      await new Promise((resolve) => setTimeout(resolve, 300));
    }

    return {
      success: false,
      error: `Timeout waiting for "${appName}" to start after ${timeout}ms.`,
      data: {
        appName,
        running: false,
        waitedMs: Date.now() - start,
      },
    };
  },
};
