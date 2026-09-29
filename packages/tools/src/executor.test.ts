import { describe, it, expect, vi } from 'vitest';
import path from 'path';
import os from 'os';
import fs from 'fs';
import { ToolExecutor } from './executor.js';

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

  it('executes safe terminal commands like pwd successfully', async () => {
    const executor = new ToolExecutor();
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
    });

    const result = await executor.execute('run_command', { command: 'mkdir /tmp/kacung-test-denied' });
    expect(confirmMock).toHaveBeenCalled();
    expect(result.result.success).toBe(false);
    expect(result.result.error).toContain('User denied permission');
  });

  it('can write and read files safely', async () => {
    const testFile = path.join(os.tmpdir(), `kacung-test-${Date.now()}.txt`);
    const executor = new ToolExecutor({
      confirmSensitive: false, // Bypass confirmation in automated test
    });

    const writeRes = await executor.execute('write_file', {
      path: testFile,
      content: 'Halo Kacung!',
    });
    expect(writeRes.result.success).toBe(true);

    const readRes = await executor.execute('read_file', { path: testFile });
    expect(readRes.result.success).toBe(true);
    const readData = readRes.result.data as { content: string };
    expect(readData.content).toBe('Halo Kacung!');

    // Cleanup
    if (fs.existsSync(testFile)) {
      fs.unlinkSync(testFile);
    }
  });
});
