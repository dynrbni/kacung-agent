import { execFile } from 'child_process';
import { promisify } from 'util';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@lofly/types';
import { toolSafety } from '../safety/policy.js';

const execFileAsync = promisify(execFile);

export interface OpenAppParams {
  appName: string;
}

export const openAppTool: ToolDefinition<OpenAppParams, { appName: string; app: string; message: string }> = {
  name: 'open_app',
  description: 'Opens a macOS application by its name (e.g., "Safari", "Spotify", "Terminal", "VS Code").',
  permissionLevel: 'SAFE',
  safety: toolSafety('reversible', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      appName: {
        type: 'string',
        description: 'The name of the macOS application to launch or bring to the foreground.',
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
      return { valid: false, error: 'appName is required and must be a non-empty string' };
    }
    return { valid: true };
  },
  async execute(params: OpenAppParams, context: ToolExecutionContext): Promise<ToolResult<{ appName: string; app: string; message: string }>> {
    const appName = params.appName.trim();
    context.logger.info(`Opening application: ${appName}`);

    try {
      // First try standard `open -a <appName>`
      await execFileAsync('open', ['-a', appName]);
      return {
        success: true,
        data: {
          appName,
          app: appName,
          message: `Application "${appName}" opened successfully.`,
        },
      };
    } catch (err: unknown) {
      // Fallback via AppleScript activate
      try {
        const appleScript = `tell application "${appName.replace(/"/g, '\\"')}" to activate`;
        await execFileAsync('osascript', ['-e', appleScript]);
        return {
          success: true,
          data: {
            appName,
            app: appName,
            message: `Application "${appName}" activated via AppleScript.`,
          },
        };
      } catch (fallbackErr: unknown) {
        const message = fallbackErr instanceof Error ? fallbackErr.message : String(fallbackErr);
        context.logger.error(`Failed to open application ${appName}: ${message}`);
        return {
          success: false,
          error: `Could not open application "${appName}": ${message}`,
        };
      }
    }
  },
};

export interface CloseAppParams {
  appName: string;
}

export const closeAppTool: ToolDefinition<CloseAppParams, { appName: string; message: string }> = {
  name: 'close_app',
  description: 'Gracefully closes/quits a macOS application by its name.',
  permissionLevel: 'SAFE',
  safety: toolSafety('reversible', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      appName: {
        type: 'string',
        description: 'The name of the application to quit.',
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
      return { valid: false, error: 'appName is required and must be a non-empty string' };
    }
    return { valid: true };
  },
  async execute(params: CloseAppParams, context: ToolExecutionContext): Promise<ToolResult<{ appName: string; message: string }>> {
    const appName = params.appName.trim();
    context.logger.info(`Closing application: ${appName}`);

    try {
      const appleScript = `tell application "${appName.replace(/"/g, '\\"')}" to quit`;
      await execFileAsync('osascript', ['-e', appleScript]);
      return {
        success: true,
        data: {
          appName,
          message: `Application "${appName}" closed successfully.`,
        },
      };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      context.logger.error(`Failed to close application ${appName}: ${message}`);
      return {
        success: false,
        error: `Could not close application "${appName}": ${message}`,
      };
    }
  },
};

export interface FocusAppParams {
  appName: string;
}

export const focusAppTool: ToolDefinition<FocusAppParams, { appName: string; message: string }> = {
  name: 'focus_app',
  description: 'Brings a running macOS application to the foreground and focuses its main window.',
  permissionLevel: 'SAFE',
  safety: toolSafety('reversible', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      appName: {
        type: 'string',
        description: 'The name of the application to focus (e.g. "Spotify", "Safari", "WhatsApp").',
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
      return { valid: false, error: 'appName is required and must be a non-empty string' };
    }
    return { valid: true };
  },
  async execute(params: FocusAppParams, context: ToolExecutionContext): Promise<ToolResult<{ appName: string; message: string }>> {
    const appName = params.appName.trim();
    context.logger.info(`Focusing application: ${appName}`);

    try {
      const script = `tell application "${appName.replace(/"/g, '\\"')}" to activate`;
      await execFileAsync('osascript', ['-e', script]);
      return {
        success: true,
        data: {
          appName,
          message: `Application "${appName}" focused successfully.`,
        },
      };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      context.logger.error(`Failed to focus application ${appName}: ${message}`);
      return {
        success: false,
        error: `Could not focus application "${appName}": ${message}`,
      };
    }
  },
};

export interface IsAppRunningParams {
  appName: string;
}

export const isAppRunningTool: ToolDefinition<IsAppRunningParams, { appName: string; running: boolean }> = {
  name: 'is_app_running',
  description: 'Checks whether a macOS application is currently running.',
  permissionLevel: 'SAFE',
  safety: toolSafety('none', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      appName: {
        type: 'string',
        description: 'The name of the application to check (e.g. "Spotify", "WhatsApp", "Code").',
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
      return { valid: false, error: 'appName is required and must be a non-empty string' };
    }
    return { valid: true };
  },
  async execute(params: IsAppRunningParams, context: ToolExecutionContext): Promise<ToolResult<{ appName: string; running: boolean }>> {
    const appName = params.appName.trim();
    context.logger.info(`Checking if application is running: ${appName}`);

    try {
      const script = `
        tell application "System Events"
          set isRunning to (exists (processes where name is "${appName.replace(/"/g, '\\"')}"))
          return isRunning
        end tell
      `;
      const { stdout } = await execFileAsync('osascript', ['-e', script]);
      const running = stdout.trim().toLowerCase() === 'true';

      return {
        success: true,
        data: {
          appName,
          running,
        },
      };
    } catch {
      // Fallback via pgrep
      try {
        const { stdout } = await execFileAsync('pgrep', ['-ix', appName]);
        const running = stdout.trim().length > 0;
        return {
          success: true,
          data: {
            appName,
            running,
          },
        };
      } catch {
        return {
          success: true,
          data: {
            appName,
            running: false,
          },
        };
      }
    }
  },
};
