import fs from 'fs';
import path from 'path';
import os from 'os';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@kacung/types';

function resolvePath(filePath: string): string {
  if (filePath.startsWith('~/') || filePath === '~') {
    return path.join(os.homedir(), filePath.slice(1));
  }
  return path.resolve(process.cwd(), filePath);
}

// ----------------------------------------------------------------------------
// Read File Tool
// ----------------------------------------------------------------------------
export interface ReadFileParams {
  path: string;
  maxBytes?: number;
}

export const readFileTool: ToolDefinition<ReadFileParams, { path: string; content: string; sizeBytes: number }> = {
  name: 'read_file',
  description: 'Reads the contents of a local file as UTF-8 text.',
  permissionLevel: 'SAFE',
  parameters: {
    type: 'object',
    properties: {
      path: {
        type: 'string',
        description: 'The file path to read (supports relative paths and ~/...)',
      },
      maxBytes: {
        type: 'number',
        description: 'Maximum bytes to read (default: 100000)',
      },
    },
    required: ['path'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.path || typeof p.path !== 'string') {
      return { valid: false, error: 'path is required and must be a string' };
    }
    return { valid: true };
  },
  async execute(params: ReadFileParams, context: ToolExecutionContext): Promise<ToolResult<{ path: string; content: string; sizeBytes: number }>> {
    const targetPath = resolvePath(params.path);
    const maxBytes = params.maxBytes || 100_000;
    context.logger.info(`Reading file: ${targetPath}`);

    try {
      if (!fs.existsSync(targetPath)) {
        return {
          success: false,
          error: `File does not exist: ${targetPath}`,
        };
      }

      const stat = fs.statSync(targetPath);
      if (stat.isDirectory()) {
        return {
          success: false,
          error: `Target path is a directory, not a file: ${targetPath}`,
        };
      }

      const buffer = Buffer.alloc(Math.min(stat.size, maxBytes));
      const fd = fs.openSync(targetPath, 'r');
      fs.readSync(fd, buffer, 0, buffer.length, 0);
      fs.closeSync(fd);

      const content = buffer.toString('utf-8');

      return {
        success: true,
        data: {
          path: targetPath,
          content,
          sizeBytes: stat.size,
        },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Read file failed: ${msg}`);
      return { success: false, error: `Failed to read file: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Write File Tool
// ----------------------------------------------------------------------------
export interface WriteFileParams {
  path: string;
  content: string;
}

export const writeFileTool: ToolDefinition<WriteFileParams, { path: string; bytesWritten: number; message: string }> = {
  name: 'write_file',
  description: 'Writes or updates text content to a local file. Creates parent directories if they do not exist.',
  permissionLevel: 'SENSITIVE',
  parameters: {
    type: 'object',
    properties: {
      path: {
        type: 'string',
        description: 'The target file path to write to.',
      },
      content: {
        type: 'string',
        description: 'The text content to write into the file.',
      },
    },
    required: ['path', 'content'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.path || typeof p.path !== 'string') {
      return { valid: false, error: 'path is required and must be a string' };
    }
    if (typeof p.content !== 'string') {
      return { valid: false, error: 'content is required and must be a string' };
    }
    return { valid: true };
  },
  async execute(params: WriteFileParams, context: ToolExecutionContext): Promise<ToolResult<{ path: string; bytesWritten: number; message: string }>> {
    const targetPath = resolvePath(params.path);
    context.logger.info(`Writing file: ${targetPath}`);

    try {
      const dir = path.dirname(targetPath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }

      fs.writeFileSync(targetPath, params.content, 'utf-8');
      const bytesWritten = Buffer.byteLength(params.content, 'utf-8');

      return {
        success: true,
        data: {
          path: targetPath,
          bytesWritten,
          message: `Successfully wrote ${bytesWritten} bytes to ${targetPath}`,
        },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Write file failed: ${msg}`);
      return { success: false, error: `Failed to write file: ${msg}` };
    }
  },
};
