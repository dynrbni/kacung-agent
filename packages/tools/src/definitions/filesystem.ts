import fs from 'fs';
import path from 'path';
import os from 'os';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@lafly/types';
import { toolSafety, resolveSandboxPath } from '../safety/policy.js';

/**
 * Resolves a path argument. In sandbox mode every path is re-rooted inside the
 * sandbox directory, so filesystem tools cannot reach the user's real files.
 */
function resolvePath(filePath: string, context?: ToolExecutionContext): string {
  if (context?.policy.mode === 'sandbox') {
    return resolveSandboxPath(context.policy.sandboxRoot, filePath);
  }
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
  safety: toolSafety('none', { supportsSandbox: true }),
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
    const targetPath = resolvePath(params.path, context);
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
  safety: toolSafety('reversible', { supportsSandbox: true }),
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
    const targetPath = resolvePath(params.path, context);
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

// ----------------------------------------------------------------------------
// List Directory Tool
// ----------------------------------------------------------------------------
export interface ListDirectoryParams {
  path?: string;
}

export const listDirectoryTool: ToolDefinition<ListDirectoryParams, { path: string; files: Array<{ name: string; isDirectory: boolean; size: number }> }> = {
  name: 'list_directory',
  description: 'Lists files and folders inside a given directory.',
  permissionLevel: 'SAFE',
  safety: toolSafety('none', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      path: {
        type: 'string',
        description: 'Directory path to list (default: current working directory)',
      },
    },
  },
  async execute(params: ListDirectoryParams, context: ToolExecutionContext): Promise<ToolResult<{ path: string; files: Array<{ name: string; isDirectory: boolean; size: number }> }>> {
    const targetDir = resolvePath(params?.path || '.', context);
    context.logger.info(`Listing directory: ${targetDir}`);

    try {
      if (!fs.existsSync(targetDir)) {
        return { success: false, error: `Directory not found: ${targetDir}` };
      }
      const entries = fs.readdirSync(targetDir, { withFileTypes: true });
      const files = entries.map((e) => {
        let size = 0;
        try {
          const s = fs.statSync(path.join(targetDir, e.name));
          size = s.size;
        } catch {}
        return {
          name: e.name,
          isDirectory: e.isDirectory(),
          size,
        };
      });

      return {
        success: true,
        data: {
          path: targetDir,
          files,
        },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: `Failed to list directory: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Find File Tool
// ----------------------------------------------------------------------------
export interface FindFileParams {
  query: string;
  directory?: string;
  maxResults?: number;
}

export const findFileTool: ToolDefinition<FindFileParams, { matches: string[]; count: number }> = {
  name: 'find_file',
  description: 'Searches for files matching a keyword or substring within a directory.',
  permissionLevel: 'SAFE',
  safety: toolSafety('none', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      query: {
        type: 'string',
        description: 'File name keyword or extension to search for (e.g. "tugas", "package.json", ".mp4").',
      },
      directory: {
        type: 'string',
        description: 'Root directory to start search from (default: user home directory or current directory).',
      },
      maxResults: {
        type: 'number',
        description: 'Maximum matches to return (default: 20).',
      },
    },
    required: ['query'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.query || typeof p.query !== 'string') {
      return { valid: false, error: 'query is required' };
    }
    return { valid: true };
  },
  async execute(params: FindFileParams, context: ToolExecutionContext): Promise<ToolResult<{ matches: string[]; count: number }>> {
    const rootDir = resolvePath(params.directory || '.', context);
    const query = params.query.toLowerCase().trim();
    const maxResults = params.maxResults || 20;
    const matches: string[] = [];

    context.logger.info(`Searching for file "${query}" in ${rootDir}`);

    function search(dir: string, depth: number) {
      if (depth > 5 || matches.length >= maxResults) return;
      try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const e of entries) {
          if (e.name.startsWith('.') || e.name === 'node_modules') continue;
          const full = path.join(dir, e.name);
          if (e.name.toLowerCase().includes(query)) {
            matches.push(full);
            if (matches.length >= maxResults) return;
          }
          if (e.isDirectory()) {
            search(full, depth + 1);
          }
        }
      } catch {}
    }

    search(rootDir, 1);

    return {
      success: true,
      data: {
        matches,
        count: matches.length,
      },
    };
  },
};

// ----------------------------------------------------------------------------
// Create Directory Tool
// ----------------------------------------------------------------------------
export interface CreateDirectoryParams {
  path: string;
}

export const createDirectoryTool: ToolDefinition<CreateDirectoryParams, { path: string; message: string }> = {
  name: 'create_directory',
  description: 'Creates a new directory (and parent directories if needed).',
  permissionLevel: 'SENSITIVE',
  safety: toolSafety('reversible', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      path: { type: 'string', description: 'Directory path to create' },
    },
    required: ['path'],
  },
  async execute(params: CreateDirectoryParams, context: ToolExecutionContext): Promise<ToolResult<{ path: string; message: string }>> {
    const targetDir = resolvePath(params.path, context);
    context.logger.info(`Creating directory: ${targetDir}`);
    try {
      fs.mkdirSync(targetDir, { recursive: true });
      return { success: true, data: { path: targetDir, message: `Created directory ${targetDir}` } };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: `Failed to create directory: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Copy File Tool
// ----------------------------------------------------------------------------
export interface CopyFileParams {
  source: string;
  destination: string;
}

export const copyFileTool: ToolDefinition<CopyFileParams, { source: string; destination: string; message: string }> = {
  name: 'copy_file',
  description: 'Copies a file from source path to destination path.',
  permissionLevel: 'SENSITIVE',
  safety: toolSafety('reversible', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      source: { type: 'string', description: 'Source file path' },
      destination: { type: 'string', description: 'Destination file path' },
    },
    required: ['source', 'destination'],
  },
  async execute(params: CopyFileParams, context: ToolExecutionContext): Promise<ToolResult<{ source: string; destination: string; message: string }>> {
    const src = resolvePath(params.source, context);
    const dest = resolvePath(params.destination, context);
    context.logger.info(`Copying file from ${src} to ${dest}`);
    try {
      fs.copyFileSync(src, dest);
      return { success: true, data: { source: src, destination: dest, message: `Copied ${src} to ${dest}` } };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: `Failed to copy file: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Move File Tool
// ----------------------------------------------------------------------------
export interface MoveFileParams {
  source: string;
  destination: string;
}

export const moveFileTool: ToolDefinition<MoveFileParams, { source: string; destination: string; message: string }> = {
  name: 'move_file',
  description: 'Moves or renames a file from source to destination.',
  permissionLevel: 'SENSITIVE',
  safety: toolSafety('reversible', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      source: { type: 'string', description: 'Current file path' },
      destination: { type: 'string', description: 'New file path or target directory' },
    },
    required: ['source', 'destination'],
  },
  async execute(params: MoveFileParams, context: ToolExecutionContext): Promise<ToolResult<{ source: string; destination: string; message: string }>> {
    const src = resolvePath(params.source, context);
    const dest = resolvePath(params.destination, context);
    context.logger.info(`Moving file from ${src} to ${dest}`);
    try {
      fs.renameSync(src, dest);
      return { success: true, data: { source: src, destination: dest, message: `Moved ${src} to ${dest}` } };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: `Failed to move file: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Delete File Tool (DANGEROUS — ALWAYS REQUIRES CONFIRMATION)
// ----------------------------------------------------------------------------
export interface DeleteFileParams {
  path: string;
}

export const deleteFileTool: ToolDefinition<DeleteFileParams, { path: string; message: string }> = {
  name: 'delete_file',
  description: 'Deletes a file or directory. This is a DANGEROUS action requiring explicit user confirmation.',
  permissionLevel: 'DANGEROUS',
  safety: toolSafety('destructive', { supportsSandbox: false }),
  parameters: {
    type: 'object',
    properties: {
      path: { type: 'string', description: 'Path of the file or directory to delete' },
    },
    required: ['path'],
  },
  async execute(params: DeleteFileParams, context: ToolExecutionContext): Promise<ToolResult<{ path: string; message: string }>> {
    const target = resolvePath(params.path, context);
    context.logger.warn(`delete_file requested for: ${target}`);

    if (context.requestConfirmation) {
      const approved = await context.requestConfirmation({
        toolName: 'delete_file',
        parameters: { path: target },
        permissionLevel: 'DANGEROUS',
        description: `Apakah Anda yakin ingin menghapus file/folder "${target}"? Tindakan ini tidak dapat dibatalkan.`,
      });
      if (!approved) {
        return {
          success: false,
          error: 'Penghapusan file dibatalkan oleh pengguna.',
        };
      }
    }

    try {
      if (fs.existsSync(target)) {
        fs.rmSync(target, { recursive: true, force: true });
        return { success: true, data: { path: target, message: `File "${target}" berhasil dihapus.` } };
      }
      return { success: false, error: `File tidak ditemukan: ${target}` };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: `Gagal menghapus file: ${msg}` };
    }
  },
};
