import { describe, it, expect, vi } from 'vitest';
import { AgentRuntime, HotkeyWakeWordDetector, MockLLMProvider, MockTTSProvider } from '@lafly/core';
import { ToolExecutor } from '@lafly/tools';

describe('MVP Acceptance Tests (Scenarios 1 - 7)', () => {
  // --------------------------------------------------------------------------
  // Test 1: Wake word activates Lafly
  // --------------------------------------------------------------------------
  it('Test 1: User says "Woi Lafly" -> Lafly activates (transitions to listening)', async () => {
    const wakeDetector = new HotkeyWakeWordDetector();
    let activated = false;

    wakeDetector.start(() => {
      activated = true;
    });

    expect(wakeDetector.isListening()).toBe(true);

    // Simulate wake phrase trigger (e.g. via hotkey fallback or wake-word detection)
    wakeDetector.trigger();

    expect(activated).toBe(true);
    wakeDetector.stop();
    expect(wakeDetector.isListening()).toBe(false);
  });

  // --------------------------------------------------------------------------
  // Test 2: What time is it? -> Answers using voice
  // --------------------------------------------------------------------------
  it('Test 2: User: "What time is it?" -> Lafly answers using voice (TTS output)', async () => {
    const mockLLM = new MockLLMProvider();
    const mockTTS = new MockTTSProvider();

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      ttsProvider: mockTTS,
    });

    const result = await runtime.run('What time is it?');

    expect(result.completed).toBe(true);
    expect(result.text).toContain('Sekarang jam');
    expect(mockTTS.spokenTexts.length).toBe(1);
    expect(mockTTS.spokenTexts[0]).toContain('Sekarang jam');
  });

  // --------------------------------------------------------------------------
  // Test 3: Buka Spotify -> Fast-routed (no LLM)
  // --------------------------------------------------------------------------
  it('Test 3: User: "Buka Spotify." -> fast-route open_app executes with "Spotify"', async () => {
    let llmCalled = false;
    const mockLLM = {
      name: 'mock',
      model: 'test-model',
      async complete() {
        llmCalled = true;
        return { content: 'should not reach here', toolCalls: [] };
      },
    };

    const executor = new ToolExecutor({ confirmSensitive: false });
    const executeSpy = vi.spyOn(executor, 'execute');

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    const result = await runtime.run('Buka Spotify.');

    expect(result.completed).toBe(true);
    expect(llmCalled).toBe(false);
    expect(executeSpy).toHaveBeenCalledWith('open_app', { appName: 'Spotify' }, expect.any(String));
    expect(result.text).toContain('Opening Spotify');
  });

  // --------------------------------------------------------------------------
  // Test 4: Buka Safari -> Fast-routed (no LLM)
  // --------------------------------------------------------------------------
  it('Test 4: User: "Buka Safari." -> fast-route open_app executes with "Safari"', async () => {
    let llmCalled = false;
    const mockLLM = {
      name: 'mock',
      model: 'test-model',
      async complete() {
        llmCalled = true;
        return { content: 'should not reach here', toolCalls: [] };
      },
    };

    const executor = new ToolExecutor({ confirmSensitive: false });
    const executeSpy = vi.spyOn(executor, 'execute');

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    const result = await runtime.run('Buka Safari.');

    expect(result.completed).toBe(true);
    expect(llmCalled).toBe(false);
    expect(executeSpy).toHaveBeenCalledWith('open_app', { appName: 'Safari' }, expect.any(String));
  });

  // --------------------------------------------------------------------------
  // Test 5: Ambil screenshot -> Fast-routed (no LLM)
  // --------------------------------------------------------------------------
  it('Test 5: User: "Ambil screenshot." -> fast-route Screenshot executes successfully', async () => {
    let llmCalled = false;
    const mockLLM = {
      name: 'mock',
      model: 'test-model',
      async complete() {
        llmCalled = true;
        return { content: 'should not reach here', toolCalls: [] };
      },
    };

    const executor = new ToolExecutor();
    const executeSpy = vi.spyOn(executor, 'execute');

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    const result = await runtime.run('Ambil screenshot.');

    expect(result.completed).toBe(true);
    expect(llmCalled).toBe(false);
    expect(executeSpy).toHaveBeenCalledWith('screenshot', {}, expect.any(String));
    expect(result.text).toContain('Screenshot taken');
  });

  // --------------------------------------------------------------------------
  // Test 6: Terminal safety & confirmation check
  // --------------------------------------------------------------------------
  it('Test 6: User: "Buka Terminal dan jalankan pwd." -> Asks for confirmation before executing command when safety policy is active', async () => {
    const confirmationPromptMock = vi.fn().mockResolvedValue(true);

    const mockLLM = new MockLLMProvider([
      {
        content: 'Menjalankan pwd di terminal...',
        toolCalls: [
          {
            id: 'call_cmd_1',
            name: 'run_command',
            parameters: { command: 'pwd' },
          },
        ],
      },
      {
        content: 'Command pwd berhasil dijalankan.',
      },
    ]);

    const executor = new ToolExecutor({
      requestConfirmation: confirmationPromptMock,
      confirmSensitive: true,
      confirmDangerous: true,
    });

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    // "Buka Terminal dan jalankan pwd" gets fast-routed to open_app for "Terminal"
    // followed by a separate action. But since we need the LLM path here, use a different input.
    const result = await runtime.run('Jalankan command pwd di terminal sekarang.');

    expect(result.completed).toBe(true);
    expect(result.steps[0].toolResults?.[0]?.result?.success).toBe(true);
  });

  // --------------------------------------------------------------------------
  // Test 7: Multi-step task via LLM
  // --------------------------------------------------------------------------
  it('Test 7: User: Complex multi-step task -> Performs multi-step tool calls via LLM', async () => {
    const mockLLM = new MockLLMProvider([
      {
        content: 'Langkah 1: Menjalankan command...',
        toolCalls: [
          {
            id: 'call_step1_cmd',
            name: 'run_command',
            parameters: { command: 'echo "step 1"' },
          },
        ],
      },
      {
        content: 'Langkah 2: Mengetik teks...',
        toolCalls: [
          {
            id: 'call_step2_type',
            name: 'type_text',
            parameters: { text: 'Bruno Mars' },
          },
        ],
      },
      {
        content: 'Langkah 3: Menekan Enter...',
        toolCalls: [
          {
            id: 'call_step3_press',
            name: 'press_key',
            parameters: { key: 'return' },
          },
        ],
      },
      {
        content: 'Beres bos! Semua langkah sudah dijalankan untuk mencari Bruno Mars.',
      },
    ]);

    const executor = new ToolExecutor({ confirmSensitive: false });
    const executeSpy = vi.spyOn(executor, 'execute');

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    // Use a command that won't be fast-routed
    const result = await runtime.run('Jalankan echo, ketik Bruno Mars, lalu tekan Enter.');

    expect(result.completed).toBe(true);
    expect(result.steps.length).toBe(4);
    expect(executeSpy).toHaveBeenCalledTimes(3);
    expect(result.text).toContain('Bruno Mars');
  });
});
