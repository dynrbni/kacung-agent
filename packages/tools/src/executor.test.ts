import { describe, it, expect, vi } from 'vitest';
import path from 'path';
import os from 'os';
import fs from 'fs';
import { ToolExecutor } from './executor.js';
import type { ExecutionPolicy } from '@lofly/types';

/**
 * Opt-in live policy for the three cases below that genuinely need real
 * behaviour. `pwd` is a read-only subprocess, the denied `mkdir` never runs, and
 * the file test writes to a temporary directory — none of them reach a person,
 * a remote service, or a real user file. Everything else in the suite stays in
 * dry-run mode.
 */
const LIVE: ExecutionPolicy = {
  mode: 'live',
  safeTestMode: false,
  liveSideEffects: true,
  sandboxRoot: path.join(os.tmpdir(), 'LoflySandbox'),
};

describe('ToolExecutor', () => {
  it('returns structured error when tool is not found', async () => {
    const executor = new ToolExecutor();
    const result = await executor.execute('non_existent_tool', {});
    expect(result.result.success).toBe(false);
    expect(result.result.error).toContain('not found in registry');
  });

  it('validates parameters and rejects invalid arguments', async () => {
    const executor = new ToolExecutor();
    // open_app requires appName to be a non-empty string
    const result = await executor.execute('open_app', { appName: '' });
    expect(result.result.success).toBe(false);
    expect(result.result.error).toContain('appName is required');
  });

  it('simulates run_command instead of spawning a shell by default', async () => {
    const executor = new ToolExecutor();
    const result = await executor.execute('run_command', { command: 'pwd' });

    expect(result.result.success).toBe(true);
    expect(result.result.metadata?.mode).toBe('dry_run');
    expect(result.result.metadata?.executed).toBe(false);
    const data = result.result.data as { command: string; exitCode: number | null };
    expect(data.exitCode).toBeNull();
    expect(data.command).toBe('pwd');
  });

  it('executes safe terminal commands like pwd successfully when live', async () => {
    const executor = new ToolExecutor({ policy: LIVE });
    const result = await executor.execute('run_command', { command: 'pwd' });
    expect(result.result.success).toBe(true);
    expect(result.result.data).toBeDefined();
    const data = result.result.data as { stdout: string; exitCode: number };
    expect(data.exitCode).toBe(0);
    expect(data.stdout.trim().length).toBeGreaterThan(0);
  });

  it('requires confirmation for sensitive commands and respects user denial', async () => {
    const confirmMock = vi.fn().mockResolvedValue(false);
    const executor = new ToolExecutor({
      requestConfirmation: confirmMock,
      policy: LIVE,
    });

    const result = await executor.execute('run_command', { command: 'mkdir /tmp/lofly-test-denied' });
    expect(confirmMock).toHaveBeenCalled();
    expect(result.result.success).toBe(false);
    expect(result.result.error).toContain('User denied permission');
  });

  it('can write and read files safely', async () => {
    const testFile = path.join(os.tmpdir(), `lofly-test-${Date.now()}.txt`);
    const executor = new ToolExecutor({
      confirmSensitive: false, // Bypass confirmation in automated test
      policy: LIVE,
    });

    const writeRes = await executor.execute('write_file', {
      path: testFile,
      content: 'Halo Lofly!',
    });
    expect(writeRes.result.success).toBe(true);

    const readRes = await executor.execute('read_file', { path: testFile });
    expect(readRes.result.success).toBe(true);
    const readData = readRes.result.data as { content: string };
    expect(readData.content).toBe('Halo Lofly!');

    // Cleanup
    if (fs.existsSync(testFile)) {
      fs.unlinkSync(testFile);
    }
  });

  it('confines filesystem writes to the sandbox root in sandbox mode', async () => {
    const sandboxRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'lofly-sandbox-'));
    const executor = new ToolExecutor({
      confirmSensitive: false,
      policy: { mode: 'sandbox', safeTestMode: true, liveSideEffects: false, sandboxRoot },
    });

    const writeRes = await executor.execute('write_file', {
      path: 'notes.txt',
      content: 'inside sandbox',
    });
    expect(writeRes.result.success).toBe(true);
    expect(fs.existsSync(path.join(sandboxRoot, 'notes.txt'))).toBe(true);
    expect(fs.readFileSync(path.join(sandboxRoot, 'notes.txt'), 'utf-8')).toBe('inside sandbox');

    fs.rmSync(sandboxRoot, { recursive: true, force: true });
  });
});
