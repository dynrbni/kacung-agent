import type {
  ToolDefinition,
  ToolExecutionContext,
  ToolResult,
  ExecutedToolCall,
  ConfirmationRequest,
  Logger,
} from '@kacung/types';
import { ToolRegistry } from './registry.js';

export interface ToolExecutorOptions {
  registry?: ToolRegistry;
  logger?: Logger;
  requestConfirmation?: (req: Omit<ConfirmationRequest, 'id' | 'timestamp'>) => Promise<boolean>;
  confirmSensitive?: boolean;
  confirmDangerous?: boolean;
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

  constructor(options: ToolExecutorOptions = {}) {
    this.registry = options.registry || new ToolRegistry();
    this.logger = options.logger || defaultLogger;
    this.requestConfirmation = options.requestConfirmation;
    this.confirmSensitive = options.confirmSensitive ?? true;
    this.confirmDangerous = options.confirmDangerous ?? true;
  }

  public getRegistry(): ToolRegistry {
    return this.registry;
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

    // 3. Permission checks (outside of tool's internal checks)
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

    // 4. Execution context
    const context: ToolExecutionContext = {
      requestId: callId,
      logger: this.logger,
      requestConfirmation: this.requestConfirmation,
    };

    // 5. Safe execution
    try {
      const result: ToolResult = await tool.execute(parameters, context);
      const durationMs = Date.now() - startTime;
      this.logger.info(`Tool ${toolName} finished in ${durationMs}ms (success: ${result.success})`);

      return {
        id: callId,
        name: toolName,
        parameters,
        result,
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
