import type {
  ToolDefinition,
  ToolExecutionContext,
  ToolResult,
  ExecutedToolCall,
  ConfirmationRequest,
  ExecutionPolicy,
  Logger,
} from '@lafly/types';
import { ToolRegistry } from './registry.js';
import {
  getExecutionPolicy,
  getToolSafety,
  shouldSimulate,
  isSandboxed,
} from './safety/policy.js';
import { buildDryRunResult, formatDryRunSummary } from './safety/dry-run.js';

export interface ToolExecutorOptions {
  registry?: ToolRegistry;
  logger?: Logger;
  requestConfirmation?: (req: Omit<ConfirmationRequest, 'id' | 'timestamp'>) => Promise<boolean>;
  confirmSensitive?: boolean;
  confirmDangerous?: boolean;
  /** Overrides the process-wide policy. Tests use this to pin a mode. */
  policy?: ExecutionPolicy;
}

const defaultLogger: Logger = {
  debug: (msg, meta) => console.debug(`[DEBUG] ${msg}`, meta || ''),
  info: (msg, meta) => console.info(`[INFO] ${msg}`, meta || ''),
  warn: (msg, meta) => console.warn(`[WARN] ${msg}`, meta || ''),
  error: (msg, meta) => console.error(`[ERROR] ${msg}`, meta || ''),
};

export class ToolExecutor {
  private registry: ToolRegistry;
  private logger: Logger;
  private requestConfirmation?: (req: Omit<ConfirmationRequest, 'id' | 'timestamp'>) => Promise<boolean>;
  private confirmSensitive: boolean;
  private confirmDangerous: boolean;
  private policy: ExecutionPolicy;

  constructor(options: ToolExecutorOptions = {}) {
    this.registry = options.registry || new ToolRegistry();
    this.logger = options.logger || defaultLogger;
    this.requestConfirmation = options.requestConfirmation;
    this.confirmSensitive = options.confirmSensitive ?? (options.requestConfirmation !== undefined);
    this.confirmDangerous = options.confirmDangerous ?? (options.requestConfirmation !== undefined);
    this.policy = options.policy ?? getExecutionPolicy();

    if (this.policy.configError) {
      this.logger.warn(this.policy.configError);
    }
  }

  public getRegistry(): ToolRegistry {
    return this.registry;
  }

  public getPolicy(): ExecutionPolicy {
    return this.policy;
  }

  public async execute(
    toolName: string,
    parameters: Record<string, unknown> = {},
    callId: string = `call_${Date.now()}`
  ): Promise<ExecutedToolCall> {
    const startTime = Date.now();
    this.logger.info(`Tool execution requested: ${toolName}`, { callId, parameters });

    // 1. Verify tool existence
    const tool = this.registry.get(toolName);
    if (!tool) {
      const errorMsg = `Tool "${toolName}" not found in registry.`;
      this.logger.error(errorMsg);
      return {
        id: callId,
        name: toolName,
        parameters,
        result: { success: false, error: errorMsg },
        durationMs: Date.now() - startTime,
      };
    }

    // 2. Validate parameters
    if (tool.validate) {
      const validation = tool.validate(parameters);
      if (!validation.valid) {
        const errorMsg = `Invalid parameters for tool "${toolName}": ${validation.error}`;
        this.logger.error(errorMsg);
        return {
          id: callId,
          name: toolName,
          parameters,
          result: { success: false, error: errorMsg },
          durationMs: Date.now() - startTime,
        };
      }
    }

    // 3. Side-effect gate. This sits below the LLM: no prompt, tool description,
    //    or model output can reach step 4 unless the policy allows the side effect.
    if (shouldSimulate(this.policy, tool.safety)) {
      this.logger.info(formatDryRunSummary(toolName, parameters), {
        callId,
        mode: 'dry_run',
        executed: false,
        sideEffect: getToolSafety(tool.safety).sideEffect,
      });

      return {
        id: callId,
        name: toolName,
        parameters,
        result: buildDryRunResult({
          toolName,
          parameters,
          safety: tool.safety,
          policy: this.policy,
        }),
        durationMs: Date.now() - startTime,
      };
    }

    // 4. Permission checks (outside of tool's internal checks)
    const requiresConfirmation =
      (tool.permissionLevel === 'DANGEROUS' && this.confirmDangerous) ||
      (tool.permissionLevel === 'SENSITIVE' && this.confirmSensitive);

    if (requiresConfirmation && this.requestConfirmation && toolName !== 'run_command') {
      // run_command handles its own granular confirmation with command safety inspection
      const approved = await this.requestConfirmation({
        toolName,
        parameters,
        permissionLevel: tool.permissionLevel,
        description: `Execute ${toolName} with parameters: ${JSON.stringify(parameters)}`,
      });

      if (!approved) {
        this.logger.warn(`User rejected execution of tool: ${toolName}`);
        return {
          id: callId,
          name: toolName,
          parameters,
          result: {
            success: false,
            error: `User denied permission to execute ${toolName}.`,
            metadata: { cancelledByUser: true },
          },
          durationMs: Date.now() - startTime,
        };
      }
    }

    // 5. Execution context
    const sandboxed = isSandboxed(this.policy, tool.safety);
    if (sandboxed) {
      this.logger.info(`[SANDBOX] ${toolName} confined to ${this.policy.sandboxRoot}`, { callId });
    }

    const context: ToolExecutionContext = {
      requestId: callId,
      logger: this.logger,
      requestConfirmation: (this.confirmDangerous || this.confirmSensitive)
        ? this.requestConfirmation
        : undefined,
      policy: this.policy,
    };

    // 6. Safe execution
    try {
      const result: ToolResult = await tool.execute(parameters, context);
      const durationMs = Date.now() - startTime;
      this.logger.info(`Tool ${toolName} finished in ${durationMs}ms (success: ${result.success})`);

      return {
        id: callId,
        name: toolName,
        parameters,
        result: {
          ...result,
          metadata: {
            mode: sandboxed ? 'sandbox' : 'live',
            executed: true,
            dryRun: false,
            sandboxed,
            ...(result.metadata ?? {}),
          },
        },
        durationMs,
      };
    } catch (err: unknown) {
      const durationMs = Date.now() - startTime;
      const errorMsg = err instanceof Error ? err.message : String(err);
      this.logger.error(`Tool ${toolName} failed with unhandled error: ${errorMsg}`);

      return {
        id: callId,
        name: toolName,
        parameters,
        result: {
          success: false,
          error: `Execution error in "${toolName}": ${errorMsg}`,
        },
        durationMs,
      };
    }
  }
}
