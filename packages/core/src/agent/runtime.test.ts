import { describe, it, expect, vi } from 'vitest';
import type { AssistantEvent } from '@kacung/types';
import { AgentRuntime } from './runtime.js';
import { MockLLMProvider } from '../providers/llm/mock.js';
import { MockTTSProvider } from '../providers/tts/mock.js';
import { ToolExecutor } from '@kacung/tools';

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

  it('handles tool execution and feeds observation back to model', async () => {
    const mockLLM = new MockLLMProvider([
      {
        content: 'Membuka Spotify...',
        toolCalls: [
          {
            id: 'call_1',
            name: 'run_command',
            parameters: { command: 'pwd' },
          },
        ],
      },
      {
        content: 'Spotify sudah berhasil dibuka!',
      },
    ]);

    const executor = new ToolExecutor({
      confirmSensitive: false,
    });

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    const result = await runtime.run('Buka Spotify');

    expect(result.completed).toBe(true);
    expect(result.steps.length).toBe(2);
    expect(result.steps[0].toolCalls?.length).toBe(1);
    expect(result.steps[0].toolResults?.length).toBe(1);
    expect(result.text).toBe('Spotify sudah berhasil dibuka!');
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
            parameters: { path: '/tmp/kacung-step.txt', content: 'done' },
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

    const result = await runtime.run('Buka terminal dan buat file');

    expect(result.completed).toBe(true);
    expect(result.steps.length).toBe(3);
    expect(result.text).toContain('Semua langkah tugas selesai');
  });
});
