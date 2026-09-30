import { exec } from 'child_process';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@lafly/types';
import { evaluateCommandSafety } from '../security/command-safety.js';
import { toolSafety } from '../safety/policy.js';

export interface RunCommandParams {
  command: string;
  cwd?: string;
  timeoutMs?: number;
}

export interface RunCommandResultData {
  command: string;
  stdout: string;
  stderr: string;
  exitCode: number;
  durationMs: number;
}

export const runCommandTool: ToolDefinition<RunCommandParams, RunCommandResultData> = {
  name: 'run_command',
  description: 'Executes a validated shell command in the terminal. Safe read-only commands run directly, while sensitive or state-changing commands require confirmation. Destructive commands are strictly blocked.',
  permissionLevel: 'SENSITIVE',
  safety: toolSafety('destructive', { supportsSandbox: false }),
  parameters: {
    type: 'object',
    properties: {
      command: {
        type: 'string',
        description: 'The exact shell command line to run.',
      },
      cwd: {
        type: 'string',
        description: 'Optional working directory for command execution.',
      },
      timeoutMs: {
        type: 'number',
        description: 'Execution timeout in milliseconds (default: 30000).',
      },
    },
    required: ['command'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.command || typeof p.command !== 'string' || p.command.trim() === '') {
      return { valid: false, error: 'command is required and must be a non-empty string' };
    }
    return { valid: true };
  },
  async execute(params: RunCommandParams, context: ToolExecutionContext): Promise<ToolResult<RunCommandResultData>> {
    const rawCommand = params.command.trim();
    const timeout = params.timeoutMs || 30_000;
    const cwd = params.cwd || process.cwd();

    context.logger.info(`Evaluating command safety: "${rawCommand}"`);

    // 1. Evaluate safety
    const evaluation = evaluateCommandSafety(rawCommand);

    if (evaluation.isBlocked) {
      context.logger.error(`Blocked command execution: "${rawCommand}". Reason: ${evaluation.blockReason}`);
      return {
        success: false,
        error: `Command blocked by security policy: ${evaluation.blockReason}`,
        metadata: { evaluation },
      };
    }

    // 2. Request user confirmation if command is sensitive/dangerous and not explicitly safe
    if (!evaluation.isSafeToExecuteDirectly && context.requestConfirmation) {
      context.logger.info(`Requesting confirmation for ${evaluation.level} command: "${rawCommand}"`);
      const approved = await context.requestConfirmation({
        toolName: 'run_command',
        parameters: { command: rawCommand, cwd },
        permissionLevel: evaluation.level,
        description: `Execute shell command: "${rawCommand}" (${evaluation.warning || 'May change system state'})`,
      });

      if (!approved) {
        context.logger.warn(`User rejected execution of command: "${rawCommand}"`);
        return {
          success: false,
          error: `Execution cancelled: User denied permission to run command "${rawCommand}".`,
          metadata: { evaluation, cancelledByUser: true },
        };
      }
    }

    // 3. Execute command
    const startTime = Date.now();
    return new Promise((resolve) => {
      exec(
        rawCommand,
        {
          cwd,
          timeout,
          env: {
            ...process.env,
            PAGER: 'cat',
          },
        },
        (error, stdout, stderr) => {
          const durationMs = Date.now() - startTime;
          const exitCode = error?.code !== undefined ? (typeof error.code === 'number' ? error.code : 1) : 0;

          if (error && error.killed) {
            context.logger.error(`Command timed out after ${timeout}ms: "${rawCommand}"`);
            return resolve({
              success: false,
              error: `Command timed out after ${timeout}ms`,
              data: {
                command: rawCommand,
                stdout: stdout.toString(),
                stderr: stderr.toString(),
                exitCode: 124,
                durationMs,
              },
            });
          }

          context.logger.info(`Command executed with exit code ${exitCode} (${durationMs}ms)`);

          resolve({
            success: exitCode === 0,
            error: exitCode !== 0 ? `Command exited with code ${exitCode}: ${stderr || stdout}` : undefined,
            data: {
              command: rawCommand,
              stdout: stdout.toString(),
              stderr: stderr.toString(),
              exitCode,
              durationMs,
            },
          });
        }
      );
    });
  },
};
