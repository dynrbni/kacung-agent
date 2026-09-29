import { describe, it, expect, vi } from 'vitest';
import { KacungAgent } from './agent.js';
import type { LLMProvider, LLMCompletionOptions, LLMCompletionResponse } from '@kacung/types';
import { ToolExecutor } from '@kacung/tools';

describe('Kacung Agent & 9Router Acceptance Tests', () => {
  it('Acceptance Test 1: "Buka Spotify" -> open_app("Spotify") tool execution -> final response', async () => {
    let callCount = 0;
    const mock9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      baseUrl: 'http://localhost:20128/v1',
      async complete(options: LLMCompletionOptions): Promise<LLMCompletionResponse> {
        callCount++;
        if (callCount === 1) {
          // Model decides to call open_app tool
          return {
            content: null,
            toolCalls: [
              {
                id: 'call_spotify_1',
                name: 'open_app',
                parameters: { appName: 'Spotify' },
              },
            ],
          };
        }
        // Model receives tool result and provides final response
        return {
          content: 'Siap bos, aplikasi Spotify sudah berhasil dibuka!',
          toolCalls: [],
        };
      },
    };

    const executor = new ToolExecutor();
    // Spy on tool execution
    const executeSpy = vi.spyOn(executor, 'execute');

    const agent = new KacungAgent({
      llmProvider: mock9RouterLLM,
      toolExecutor: executor,
      assistantName: 'Kacung',
      debug: false,
    });

    const result = await agent.handleTranscript('Buka Spotify');

    expect(result.completed).toBe(true);
    expect(result.steps.length).toBe(2);
    expect(executeSpy).toHaveBeenCalledWith('open_app', { appName: 'Spotify' }, 'call_spotify_1');
    expect(result.steps[0].toolCalls?.[0].name).toBe('open_app');
    expect(result.steps[0].toolCalls?.[0].parameters).toEqual({ appName: 'Spotify' });
    expect(result.text).toBe('Siap bos, aplikasi Spotify sudah berhasil dibuka!');
  });

  it('Acceptance Test 2: "Buka Safari" -> open_app("Safari") tool execution -> final response', async () => {
    let callCount = 0;
    const mock9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      baseUrl: 'http://localhost:20128/v1',
      async complete(options: LLMCompletionOptions): Promise<LLMCompletionResponse> {
        callCount++;
        if (callCount === 1) {
          return {
            content: null,
            toolCalls: [
              {
                id: 'call_safari_1',
                name: 'open_app',
                parameters: { appName: 'Safari' },
              },
            ],
          };
        }
        return {
          content: 'Safari sudah terbuka, silakan browsing!',
          toolCalls: [],
        };
      },
    };

    const executor = new ToolExecutor();
    const executeSpy = vi.spyOn(executor, 'execute');

    const agent = new KacungAgent({
      llmProvider: mock9RouterLLM,
      toolExecutor: executor,
      assistantName: 'Kacung',
      debug: false,
    });

    const result = await agent.handleTranscript('Buka Safari');

    expect(result.completed).toBe(true);
    expect(executeSpy).toHaveBeenCalledWith('open_app', { appName: 'Safari' }, 'call_safari_1');
    expect(result.text).toBe('Safari sudah terbuka, silakan browsing!');
  });

  it('Acceptance Test 3: "What is the capital of Indonesia?" -> Direct response without tool call', async () => {
    let toolExecutionOccurred = false;
    const mock9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      baseUrl: 'http://localhost:20128/v1',
      async complete(options: LLMCompletionOptions): Promise<LLMCompletionResponse> {
        // Model distinguishes conversation from action: no tool call returned
        return {
          content: 'The capital of Indonesia is Jakarta (with Nusantara planned as the future capital).',
          toolCalls: [],
        };
      },
    };

    const executor = new ToolExecutor();
    vi.spyOn(executor, 'execute').mockImplementation(async () => {
      toolExecutionOccurred = true;
      return {
        id: 'mock',
        name: 'mock',
        parameters: {},
        durationMs: 0,
        result: { success: false },
      };
    });

    const agent = new KacungAgent({
      llmProvider: mock9RouterLLM,
      toolExecutor: executor,
      assistantName: 'Kacung',
      debug: false,
    });

    const result = await agent.handleTranscript('What is the capital of Indonesia?');

    expect(result.completed).toBe(true);
    expect(toolExecutionOccurred).toBe(false);
    expect(result.steps.length).toBe(1);
    expect(result.steps[0].toolCalls).toBeUndefined();
    expect(result.text).toContain('Jakarta');
  });

  it('Error handling: Clean message when 9Router connection is unavailable', async () => {
    const broken9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      baseUrl: 'http://localhost:20128/v1',
      async complete(): Promise<LLMCompletionResponse> {
        throw new Error('9Router unavailable: ECONNREFUSED http://localhost:20128/v1');
      },
    };

    const agent = new KacungAgent({
      llmProvider: broken9RouterLLM,
      assistantName: 'Kacung',
      debug: false,
    });

    const result = await agent.handleTranscript('Buka Spotify');

    expect(result.completed).toBe(false);
    expect(result.error).toContain('ECONNREFUSED');
    expect(result.text).toBe('Gue nggak bisa terhubung ke AI sekarang. Pastikan 9Router sudah berjalan di localhost:20128.');
  });

  it('Error handling: Clean message when 9Router API key is unauthorized (401)', async () => {
    const unauthorized9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      baseUrl: 'http://localhost:20128/v1',
      async complete(): Promise<LLMCompletionResponse> {
        throw new Error('9Router authentication failure: 401 Unauthorized - Invalid API key');
      },
    };

    const agent = new KacungAgent({
      llmProvider: unauthorized9RouterLLM,
      assistantName: 'Kacung',
      debug: false,
    });

    const result = await agent.handleTranscript('Buka Spotify');

    expect(result.completed).toBe(false);
    expect(result.text).toBe('Gue nggak bisa terhubung ke AI karena API key 9Router belum dikonfigurasi dengan benar di file .env.');
  });

  it('Error handling: Gracefully handles empty speech transcript', async () => {
    const mock9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      baseUrl: 'http://localhost:20128/v1',
      async complete(): Promise<LLMCompletionResponse> {
        return { content: 'test', toolCalls: [] };
      },
    };

    const agent = new KacungAgent({
      llmProvider: mock9RouterLLM,
      assistantName: 'Kacung',
      debug: false,
    });

    const result = await agent.handleTranscript('   ');

    expect(result.completed).toBe(false);
    expect(result.error).toBe('empty transcript');
    expect(result.text).toBe('Maaf, suara tidak terdeteksi. Bisa diulang kembali?');
  });
});
