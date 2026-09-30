import { describe, it, expect } from 'vitest';
import { evaluateCommandSafety } from './command-safety.js';

describe('evaluateCommandSafety', () => {
  it('blocks catastrophic commands unconditionally', () => {
    const blockedCommands = [
      'rm -rf /',
      'rm -rf /*',
      'rm -rf ~',
      'rm -rf $HOME',
      ':(){ :|:& };:',
      'dd if=/dev/zero of=/dev/rdisk0',
      'mkfs.ext4 /dev/sda1',
    ];

    for (const cmd of blockedCommands) {
      const result = evaluateCommandSafety(cmd);
      expect(result.isBlocked).toBe(true);
      expect(result.blockReason).toBeDefined();
    }
  });

  it('marks destructive commands as DANGEROUS requiring confirmation', () => {
    const dangerousCommands = [
      'sudo systemctl restart nginx',
      'rm -rf ./my-folder',
      'kill -9 1234',
      'git reset --hard HEAD~1',
      'chmod 777 script.sh',
    ];

    for (const cmd of dangerousCommands) {
      const result = evaluateCommandSafety(cmd);
      expect(result.isBlocked).toBe(false);
      expect(result.level).toBe('DANGEROUS');
      expect(result.isSafeToExecuteDirectly).toBe(false);
    }
  });

  it('marks state-changing commands as SENSITIVE', () => {
    const sensitiveCommands = [
      'npm install express',
      'git commit -m "feat: hello"',
      'mkdir new_directory',
      'echo "hello" > output.txt',
    ];

    for (const cmd of sensitiveCommands) {
      const result = evaluateCommandSafety(cmd);
      expect(result.isBlocked).toBe(false);
      expect(result.level).toBe('SENSITIVE');
      expect(result.isSafeToExecuteDirectly).toBe(false);
    }
  });

  it('allows safe read-only commands directly', () => {
    const safeCommands = [
      'pwd',
      'ls -la',
      'whoami',
      'date',
      'git status',
      'git log',
      'sw_vers',
    ];

    for (const cmd of safeCommands) {
      const result = evaluateCommandSafety(cmd);
      expect(result.isBlocked).toBe(false);
      expect(result.level).toBe('SAFE');
      expect(result.isSafeToExecuteDirectly).toBe(true);
    }
  });
});
