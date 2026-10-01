import { describe, it, expect, vi } from 'vitest';
import { LoflyAgent } from './agent.js';
import type { LLMProvider, LLMCompletionOptions, LLMCompletionResponse } from '@lofly/types';
import { ToolExecutor } from '@lofly/tools';

describe('Lofly Agent & 9Router Acceptance Tests', () => {
  // ──────────────────────────────────────────────────────────────────────
  // Fast-Route Tests: Simple commands bypass LLM entirely
  // ──────────────────────────────────────────────────────────────────────

  it('Acceptance Test 1: "Buka Spotify" -> fast-route bypasses LLM entirely', async () => {
    let llmCalled = false;
    const mock9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      baseUrl: 'http://localhost:20128/v1',
      async complete(): Promise<LLMCompletionResponse> {
        llmCalled = true;
        return { content: 'should not reach here', toolCalls: [] };
      },
    };

    const executor = new ToolExecutor();
    const executeSpy = vi.spyOn(executor, 'execute');

    const agent = new LoflyAgent({
      llmProvider: mock9RouterLLM,
      toolExecutor: executor,
      assistantName: 'Lofly',
      debug: false,
    });

    const result = await agent.handleTranscript('Buka Spotify');

    expect(result.completed).toBe(true);
    expect(llmCalled).toBe(false); // LLM was never called!
    expect(result.steps.length).toBe(1);
    expect(result.steps[0].toolCalls?.[0].name).toBe('open_app');
    expect(result.steps[0].toolCalls?.[0].parameters).toEqual({ appName: 'Spotify' });
    expect(executeSpy).toHaveBeenCalledWith('open_app', { appName: 'Spotify' }, expect.any(String));
    expect(result.text).toContain('Opening Spotify');
  });

  it('Acceptance Test 2: "Buka Safari" -> fast-route bypasses LLM entirely', async () => {
    let llmCalled = false;
    const mock9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      baseUrl: 'http://localhost:20128/v1',
      async complete(): Promise<LLMCompletionResponse> {
        llmCalled = true;
        return { content: 'should not reach here', toolCalls: [] };
      },
    };

    const executor = new ToolExecutor();
    const executeSpy = vi.spyOn(executor, 'execute');

    const agent = new LoflyAgent({
      llmProvider: mock9RouterLLM,
      toolExecutor: executor,
      assistantName: 'Lofly',
      debug: false,
    });

    const result = await agent.handleTranscript('Buka Safari');

    expect(result.completed).toBe(true);
    expect(llmCalled).toBe(false);
    expect(executeSpy).toHaveBeenCalledWith('open_app', { appName: 'Safari' }, expect.any(String));
    expect(result.text).toContain('Opening Safari');
  });

  // ──────────────────────────────────────────────────────────────────────
  // LLM-Path Tests: Complex commands still use LLM
  // ──────────────────────────────────────────────────────────────────────

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

    const agent = new LoflyAgent({
      llmProvider: mock9RouterLLM,
      toolExecutor: executor,
      assistantName: 'Lofly',
      debug: false,
    });

    const result = await agent.handleTranscript('What is the capital of Indonesia?');

    expect(result.completed).toBe(true);
    expect(toolExecutionOccurred).toBe(false);
    expect(result.steps.length).toBe(1);
    expect(result.steps[0].toolCalls).toBeUndefined();
    expect(result.text).toContain('Jakarta');
  });

  // ──────────────────────────────────────────────────────────────────────
  // Error Handling: Use non-fast-routable commands to test LLM errors
  // ──────────────────────────────────────────────────────────────────────

  it('Error handling: Clean message when 9Router connection is unavailable', async () => {
    const broken9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      baseUrl: 'http://localhost:20128/v1',
      async complete(): Promise<LLMCompletionResponse> {
        throw new Error('9Router unavailable: ECONNREFUSED http://localhost:20128/v1');
      },
    };

    const agent = new LoflyAgent({
      llmProvider: broken9RouterLLM,
      assistantName: 'Lofly',
      debug: false,
    });

    // Use a command that won't be fast-routed
    const result = await agent.handleTranscript('Explain quantum computing to me');

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

    const agent = new LoflyAgent({
      llmProvider: unauthorized9RouterLLM,
      assistantName: 'Lofly',
      debug: false,
    });

    // Use a command that won't be fast-routed
    const result = await agent.handleTranscript('Explain the theory of relativity');

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

    const agent = new LoflyAgent({
      llmProvider: mock9RouterLLM,
      assistantName: 'Lofly',
      debug: false,
    });

    const result = await agent.handleTranscript('   ');

    expect(result.completed).toBe(false);
    expect(result.error).toBe('empty transcript');
    expect(result.text).toBe('Maaf, suara tidak terdeteksi. Bisa diulang kembali?');
  });

  // ──────────────────────────────────────────────────────────────────────
  // Fast-Route: Music and WhatsApp
  // ──────────────────────────────────────────────────────────────────────

  it('Acceptance Test 4: "Putar Bruno Mars di Spotify" -> fast-route play_music', async () => {
    let llmCalled = false;
    const mock9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      async complete(): Promise<LLMCompletionResponse> {
        llmCalled = true;
        return { content: 'should not reach here', toolCalls: [] };
      },
    };

    const executor = new ToolExecutor();
    const executeSpy = vi.spyOn(executor, 'execute');

    const agent = new LoflyAgent({
      llmProvider: mock9RouterLLM,
      toolExecutor: executor,
      assistantName: 'Lofly',
      debug: false,
    });

    const result = await agent.handleTranscript('Putar Bruno Mars di Spotify');

    expect(result.completed).toBe(true);
    expect(llmCalled).toBe(false);
    expect(executeSpy).toHaveBeenCalledWith(
      'play_music',
      { query: 'Bruno Mars', app: 'auto' },
      expect.any(String)
    );
    expect(result.text).toContain('Playing Bruno Mars');
  });

  it('Acceptance Test 5: "Chat Andi di WhatsApp, bilang gue telat 15 menit" -> fast-route send_whatsapp_message', async () => {
    let llmCalled = false;
    const mock9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      async complete(): Promise<LLMCompletionResponse> {
        llmCalled = true;
        return { content: 'should not reach here', toolCalls: [] };
      },
    };

    const executor = new ToolExecutor();
    const executeSpy = vi.spyOn(executor, 'execute');

    const agent = new LoflyAgent({
      llmProvider: mock9RouterLLM,
      toolExecutor: executor,
      assistantName: 'Lofly',
      debug: false,
    });

    const result = await agent.handleTranscript('Chat Andi di WhatsApp, bilang gue telat 15 menit');

    expect(result.completed).toBe(true);
    expect(llmCalled).toBe(false);
    expect(executeSpy).toHaveBeenCalledWith(
      'send_whatsapp_message',
      { recipient: 'Andi', message: 'gue telat 15 menit' },
      expect.any(String)
    );
    expect(result.text).toContain('Sending WhatsApp');
  });

  it('Acceptance Test 6: Cancellation command "Stop" terminates task immediately', async () => {
    const mock9RouterLLM: LLMProvider = {
      name: 'ninerouter',
      model: 'ag/gemini-3.8-flash-high',
      async complete(): Promise<LLMCompletionResponse> {
        return { content: 'test', toolCalls: [] };
      },
    };

    const agent = new LoflyAgent({
      llmProvider: mock9RouterLLM,
      assistantName: 'Lofly',
      debug: false,
    });

    const result = await agent.handleTranscript('Stop');

    expect(result.completed).toBe(true);
    expect(result.text).toBe('Siap bos, perintah dibatalkan.');
    expect(agent.getState()).toBe('idle');
  });
});
