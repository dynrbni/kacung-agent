import { describe, it, expect, vi } from 'vitest';
import type { AssistantEvent } from '@lofly/types';
import { AgentRuntime } from './runtime.js';
import { MockLLMProvider } from '../providers/llm/mock.js';
import { MockTTSProvider } from '../providers/tts/mock.js';
import { ToolExecutor } from '@lofly/tools';

describe('AgentRuntime', () => {
  it('handles direct conversational requests and transitions through states', async () => {
    const mockLLM = new MockLLMProvider();
    const mockTTS = new MockTTSProvider();
    const events: AssistantEvent[] = [];

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      ttsProvider: mockTTS,
    });

    runtime.onEvent((e) => events.push(e));

    const result = await runtime.run('What time is it?');

    expect(result.completed).toBe(true);
    expect(result.text).toContain('Sekarang jam');
    expect(mockTTS.spokenTexts.length).toBe(1);
    expect(runtime.getState()).toBe('idle');

    // Check emitted events: state_change (thinking), speech_start, speech_end, state_change (idle)
    const stateEvents = events.filter((e) => e.type === 'state_change');
    expect(stateEvents.length).toBeGreaterThan(0);
  });

  it('fast-routes simple open_app commands without LLM', async () => {
    let llmCalled = false;
    const mockLLM = {
      name: 'mock',
      model: 'test-model',
      async complete() {
        llmCalled = true;
        return { content: 'should not reach here', toolCalls: [] };
      },
    };

    const executor = new ToolExecutor({
      confirmSensitive: false,
    });

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    const result = await runtime.run('Buka Spotify');

    expect(result.completed).toBe(true);
    expect(llmCalled).toBe(false); // LLM should be bypassed
    expect(result.steps.length).toBe(1);
    expect(result.steps[0].toolCalls?.[0].name).toBe('open_app');
    expect(result.text).toContain('Opening Spotify');
  });

  it('handles tool execution via LLM path for complex commands', async () => {
    const mockLLM = new MockLLMProvider([
      {
        content: 'Menjalankan command...',
        toolCalls: [
          {
            id: 'call_1',
            name: 'run_command',
            parameters: { command: 'pwd' },
          },
        ],
      },
      {
        content: 'Command berhasil dijalankan!',
      },
    ]);

    const executor = new ToolExecutor({
      confirmSensitive: false,
    });

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    // Use a command that won't be fast-routed
    const result = await runtime.run('Jalankan command pwd di terminal dan tampilkan hasilnya');

    expect(result.completed).toBe(true);
    expect(result.steps.length).toBe(2);
    expect(result.steps[0].toolCalls?.length).toBe(1);
    expect(result.steps[0].toolResults?.length).toBe(1);
    expect(result.text).toBe('Command berhasil dijalankan!');
  });

  it('supports multi-step workflows gracefully', async () => {
    const mockLLM = new MockLLMProvider([
      {
        content: 'Langkah 1: Menjalankan command...',
        toolCalls: [
          {
            id: 'call_step1',
            name: 'run_command',
            parameters: { command: 'echo "step 1 done"' },
          },
        ],
      },
      {
        content: 'Langkah 2: Menulis file konfigurasi...',
        toolCalls: [
          {
            id: 'call_step2',
            name: 'write_file',
            parameters: { path: '/tmp/lofly-step.txt', content: 'done' },
          },
        ],
      },
      {
        content: 'Semua langkah tugas selesai dengan sukses!',
      },
    ]);

    const executor = new ToolExecutor({
      confirmSensitive: false,
    });

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    // Use a command that won't be fast-routed
    const result = await runtime.run('Jalankan echo step 1 lalu tulis file konfigurasi baru');

    expect(result.completed).toBe(true);
    expect(result.steps.length).toBe(3);
    expect(result.text).toContain('Semua langkah tugas selesai');
  });

  it('automatically recovers from token limit exceeded error by resetting history and retrying', async () => {
    let callCount = 0;
    const overflowLLM = {
      name: 'mock-overflow',
      async complete() {
        callCount++;
        if (callCount === 1) {
          throw new Error('400: The input token count exceeds the maximum number of tokens allowed 1048576.');
        }
        return {
          content: 'Pulih dari token limit dan sukses menjawab!',
          toolCalls: [],
        };
      },
    };

    const runtime = new AgentRuntime({
      llmProvider: overflowLLM,
      debug: false,
    });

    const result = await runtime.run('Pertanyaan setelah history kepenuhan');

    expect(result.completed).toBe(true);
    expect(callCount).toBe(2);
    expect(result.text).toBe('Pulih dari token limit dan sukses menjawab!');
  });

  it('sanitizes tool results by stripping massive base64 payloads and truncating long strings', async () => {
    const mockLLM = new MockLLMProvider([
      {
        content: null,
        toolCalls: [
          {
            id: 'call_screen_1',
            name: 'screenshot',
            parameters: { includeBase64: true },
          },
        ],
      },
      {
        content: 'Screenshot sudah diambil bos.',
        toolCalls: [],
      },
    ]);

    const fakeExecutor = {
      getRegistry() {
        return {
          list() {
            return [];
          },
        };
      },
      async execute() {
        return {
          id: 'call_screen_1',
          name: 'screenshot',
          parameters: {},
          durationMs: 10,
          result: {
            success: true,
            data: {
              filePath: '/tmp/test.png',
              base64: 'A'.repeat(50000), // 50KB base64 string
              stdout: 'B'.repeat(5000), // 5KB string
            },
          },
        };
      },
    };

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: fakeExecutor as unknown as ToolExecutor,
      debug: false,
    });

    // Use a command that won't be fast-routed (screenshot IS fast-routed)
    // so we need to use a non-fast-routable command that triggers LLM
    const res = await runtime.run('Take a full-resolution screenshot of the current window and analyze it');
    expect(res.completed).toBe(true);

    const messages = runtime.getMessages();
    const toolMsg = messages.find((m) => m.role === 'tool');
    expect(toolMsg).toBeDefined();
    // Verify base64 was replaced and string was truncated
    expect(toolMsg?.content).toContain('[base64 image payload: 50000 chars]');
    expect(toolMsg?.content).toContain('[truncated]');
    expect(toolMsg?.content?.length).toBeLessThan(2500);
  });
});
