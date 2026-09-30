import { describe, it, expect, beforeEach } from 'vitest';
import path from 'path';
import {
  AgentRuntime,
  MockLLMProvider,
  MockTTSProvider,
} from '@lafly/core';
import {
  ToolExecutor,
  ToolRegistry,
  resolveExecutionPolicy,
  shouldSimulate,
  getToolSafety,
  resolveSandboxPath,
  buildDryRunResult,
  MockWhatsAppExecutor,
  LiveWhatsAppExecutor,
  WhatsAppController,
} from '@lafly/tools';
import type { ExecutionPolicy } from '@lafly/types';

const DRY_RUN: ExecutionPolicy = {
  mode: 'dry_run',
  safeTestMode: true,
  liveSideEffects: false,
  sandboxRoot: path.join('/tmp', 'LaflySandbox'),
};

const LIVE: ExecutionPolicy = {
  mode: 'live',
  safeTestMode: false,
  liveSideEffects: true,
  sandboxRoot: path.join('/tmp', 'LaflySandbox'),
};

function newExecutor(policy: ExecutionPolicy = DRY_RUN): ToolExecutor {
  return new ToolExecutor({ policy, confirmSensitive: false, confirmDangerous: false });
}

describe('Safe testing — policy resolution', () => {
  it('defaults to dry run when nothing is declared', () => {
    const policy = resolveExecutionPolicy({});
    expect(policy.mode).toBe('dry_run');
    expect(policy.safeTestMode).toBe(true);
    expect(policy.liveSideEffects).toBe(false);
  });

  it('fails closed when SAFE_TEST_MODE and LIVE_SIDE_EFFECTS are both enabled', () => {
    const policy = resolveExecutionPolicy({
      SAFE_TEST_MODE: 'true',
      LIVE_SIDE_EFFECTS: 'true',
    });
    expect(policy.mode).toBe('dry_run');
    expect(policy.liveSideEffects).toBe(false);
    expect(policy.configError).toContain('cannot both be enabled');
  });

  it('refuses live side effects in CI even when explicitly requested', () => {
    const policy = resolveExecutionPolicy({
      CI: 'true',
      SAFE_TEST_MODE: 'false',
      LIVE_SIDE_EFFECTS: 'true',
    });
    expect(policy.mode).toBe('dry_run');
    expect(policy.configError).toContain('CI');
  });

  it('reaches live mode only with an explicit opt-out of safe test mode', () => {
    const policy = resolveExecutionPolicy({
      SAFE_TEST_MODE: 'false',
      LIVE_SIDE_EFFECTS: 'true',
    });
    expect(policy.mode).toBe('live');
    expect(policy.liveSideEffects).toBe(true);
  });

  it('treats an unparseable flag as safe', () => {
    const policy = resolveExecutionPolicy({ SAFE_TEST_MODE: 'banana' });
    expect(policy.mode).toBe('dry_run');
  });

  it('never leaves sandbox mode via a path traversal', () => {
    expect(() => resolveSandboxPath('/tmp/sandbox-root', '../../etc/passwd')).toThrow(/escapes/);
    expect(resolveSandboxPath('/tmp/sandbox-root', 'notes.txt')).toBe('/tmp/sandbox-root/notes.txt');
  });
});

describe('Safe testing — side-effect gate sits below the LLM', () => {
  it('simulates every non-none tool while in dry run', () => {
    const registry = new ToolRegistry();
    for (const tool of registry.list()) {
      const safety = getToolSafety(tool.safety);
      if (safety.sideEffect === 'none') continue;
      expect(shouldSimulate(DRY_RUN, tool.safety)).toBe(true);
    }
  });

  it('lets every tool through only in live mode', () => {
    const registry = new ToolRegistry();
    for (const tool of registry.list()) {
      expect(shouldSimulate(LIVE, tool.safety)).toBe(false);
    }
  });

  it('executes sandbox-capable tools in sandbox mode but not destructive ones', () => {
    const sandbox: ExecutionPolicy = { ...DRY_RUN, mode: 'sandbox' };
    expect(shouldSimulate(sandbox, { sideEffect: 'reversible', supportsDryRun: true, supportsSandbox: true })).toBe(false);
    expect(shouldSimulate(sandbox, { sideEffect: 'destructive', supportsDryRun: true, supportsSandbox: false })).toBe(true);
  });

  it('treats a tool with no declared safety as external', () => {
    expect(getToolSafety(undefined).sideEffect).toBe('external');
    expect(shouldSimulate(DRY_RUN, undefined)).toBe(true);
  });

  it('marks every simulated result with mode and executed=false', () => {
    const result = buildDryRunResult({
      toolName: 'send_whatsapp_message',
      parameters: { recipient: 'Reja Agung', message: 'Yuli bubur' },
      policy: DRY_RUN,
    });
    expect(result.success).toBe(true);
    expect(result.metadata?.dryRun).toBe(true);
    expect(result.metadata?.executed).toBe(false);
    expect(result.metadata?.mode).toBe('dry_run');
  });
});

describe('Safe testing — WhatsApp never reaches a real person (PRD §10, §11, §12)', () => {
  let runtime: AgentRuntime;
  let executor: ToolExecutor;

  beforeEach(() => {
    executor = newExecutor();
    runtime = new AgentRuntime({
      llmProvider: new MockLLMProvider([{ content: 'Siap bos.' }]),
      toolExecutor: executor,
      ttsProvider: new MockTTSProvider(),
    });
  });

  it('extracts recipient and message verbatim without sending', async () => {
    const result = await runtime.run('WhatsApp Reja Agung bilang Yuli bubur');

    const call = result.steps[0].toolResults?.[0];
    expect(call).toBeDefined();
    expect(call?.name).toBe('send_whatsapp_message');
    expect(call?.parameters.recipient).toBe('Reja Agung');
    expect(call?.parameters.message).toBe('Yuli bubur');

    const data = call?.result.data as { recipient: string; text: string; sent: boolean; dryRun: boolean };
    expect(data.recipient).toBe('Reja Agung');
    expect(data.text).toBe('Yuli bubur');
    expect(data.sent).toBe(false);
    expect(data.dryRun).toBe(true);
    expect(call?.result.metadata?.executed).toBe(false);
  });

  it('never sends when the message is missing, only opens the chat', async () => {
    const result = await runtime.run('WhatsApp Reja Agung');

    const names = result.steps[0].toolCalls?.map((c) => c.name);
    expect(names).not.toContain('send_whatsapp_message');

    const chat = result.steps[0].toolResults?.find((r) => r.name === 'open_whatsapp_chat');
    expect(chat?.result.metadata?.executed).toBe(false);
    expect(chat?.parameters.contact).toBe('Reja Agung');
  });

  it('asks for the missing message when a send is clearly intended but empty', async () => {
    const clarificationRuntime = new AgentRuntime({
      llmProvider: new MockLLMProvider([{ content: 'Siap bos.' }]),
      toolExecutor: newExecutor(),
      ttsProvider: new MockTTSProvider(),
    });

    const result = await clarificationRuntime.run('WhatsApp Reja Agung terus bilang');

    expect(result.text).toContain('Mau kirim pesan apa');
    expect(result.text).toContain('Reja Agung');
  });

  it('resolves a message action plus a following app action', async () => {
    const result = await runtime.run('WhatsApp Reja Agung bilang Yuli bubur terus buka Spotify');

    const names = result.steps[0].toolCalls?.map((c) => c.name);
    expect(names).toContain('send_whatsapp_message');
    expect(names).toContain('open_app');

    const wa = result.steps[0].toolResults?.find((r) => r.name === 'send_whatsapp_message');
    expect(wa?.result.metadata?.executed).toBe(false);
  });

  it('routes a send through the mock executor, never the live one', async () => {
    const mock = new MockWhatsAppExecutor();
    const result = await mock.sendMessage('Reja Agung', 'Yuli bubur');

    expect(result.sent).toBe(false);
    expect(result.executed).toBe(false);
    expect(result.mode).toBe('dry_run');
    expect(mock.recordedActions).toHaveLength(1);
    expect(mock.recordedActions[0].parameters).toEqual({
      recipient: 'Reja Agung',
      message: 'Yuli bubur',
    });
  });

  it('selects the mock executor from the controller in dry run', async () => {
    const controller = new WhatsAppController(undefined, DRY_RUN);
    expect(controller.isLive()).toBe(false);
    const result = await controller.sendMessage('Reja Agung', 'Yuli bubur');
    expect(result.sent).toBe(false);
    expect(result.mode).toBe('dry_run');
  });

  it('exposes a distinct live executor for deliberate production use', () => {
    expect(new LiveWhatsAppExecutor().mode).toBe('live');
    expect(new WhatsAppController(undefined, LIVE).isLive()).toBe(true);
  });
});

describe('Safe testing — other side effects are blocked by default', () => {
  it('never deletes a real file in dry run', async () => {
    const result = await newExecutor().execute('delete_file', { path: '/Users/dyn/Documents/important.txt' });

    expect(result.result.success).toBe(true);
    expect(result.result.metadata?.executed).toBe(false);
    const data = result.result.data as { deleted: boolean };
    expect(data.deleted).toBe(false);
  });

  it('never spawns a shell in dry run', async () => {
    const result = await newExecutor().execute('run_command', { command: 'echo pwned > /tmp/should-not-exist' });

    expect(result.result.metadata?.executed).toBe(false);
    const data = result.result.data as { exitCode: number | null; stdout: string };
    expect(data.exitCode).toBeNull();
    expect(data.stdout).toBe('');
  });

  it('never types into the focused application in dry run', async () => {
    const result = await newExecutor().execute('type_text', { text: 'Bruno Mars' });

    expect(result.result.metadata?.executed).toBe(false);
    const data = result.result.data as { typed: boolean };
    expect(data.typed).toBe(false);
  });

  it('still executes read-only observation in dry run', async () => {
    const registry = new ToolRegistry();
    expect(getToolSafety(registry.get('screenshot')?.safety).sideEffect).toBe('none');
    expect(shouldSimulate(DRY_RUN, registry.get('screenshot')?.safety)).toBe(false);
  });
});
