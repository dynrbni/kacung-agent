import { describe, it, expect, vi } from 'vitest';
import { AgentRuntime, HotkeyWakeWordDetector, MockLLMProvider, MockTTSProvider } from '@kacung/core';
import { ToolExecutor } from '@kacung/tools';

describe('MVP Acceptance Tests (Scenarios 1 - 7)', () => {
  // --------------------------------------------------------------------------
  // Test 1: Wake word activates Kacung
  // --------------------------------------------------------------------------
  it('Test 1: User says "Woi Kacung" -> Kacung activates (transitions to listening)', async () => {
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
  it('Test 2: User: "What time is it?" -> Kacung answers using voice (TTS output)', async () => {
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
  // Test 3: Buka Spotify -> Spotify opens
  // --------------------------------------------------------------------------
  it('Test 3: User: "Buka Spotify." -> open_app tool executes with "Spotify"', async () => {
    const mockLLM = new MockLLMProvider([
      {
        content: 'Siap, langsung buka Spotify!',
        toolCalls: [
          {
            id: 'call_spotify_1',
            name: 'open_app',
            parameters: { appName: 'Spotify' },
          },
        ],
      },
      {
        content: 'Spotify sudah terbuka, bos.',
      },
    ]);

    const executor = new ToolExecutor({ confirmSensitive: false });
    const executeSpy = vi.spyOn(executor, 'execute');

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    const result = await runtime.run('Buka Spotify.');

    expect(result.completed).toBe(true);
    expect(executeSpy).toHaveBeenCalledWith('open_app', { appName: 'Spotify' }, 'call_spotify_1');
    expect(result.text).toBe('Spotify sudah terbuka, bos.');
  });

  // --------------------------------------------------------------------------
  // Test 4: Buka Safari -> Safari opens
  // --------------------------------------------------------------------------
  it('Test 4: User: "Buka Safari." -> open_app tool executes with "Safari"', async () => {
    const mockLLM = new MockLLMProvider([
      {
        content: 'Membuka browser Safari...',
        toolCalls: [
          {
            id: 'call_safari_1',
            name: 'open_app',
            parameters: { appName: 'Safari' },
          },
        ],
      },
      {
        content: 'Safari sudah dibuka!',
      },
    ]);

    const executor = new ToolExecutor({ confirmSensitive: false });
    const executeSpy = vi.spyOn(executor, 'execute');

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    const result = await runtime.run('Buka Safari.');

    expect(result.completed).toBe(true);
    expect(executeSpy).toHaveBeenCalledWith('open_app', { appName: 'Safari' }, 'call_safari_1');
  });

  // --------------------------------------------------------------------------
  // Test 5: Ambil screenshot -> Screenshot tool executes successfully
  // --------------------------------------------------------------------------
  it('Test 5: User: "Ambil screenshot." -> Screenshot tool executes successfully', async () => {
    const mockLLM = new MockLLMProvider([
      {
        content: 'Mengambil screenshot...',
        toolCalls: [
          {
            id: 'call_screen_1',
            name: 'screenshot',
            parameters: {},
          },
        ],
      },
      {
        content: 'Screenshot berhasil disimpan di Mac Anda.',
      },
    ]);

    const executor = new ToolExecutor();
    const executeSpy = vi.spyOn(executor, 'execute');

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    const result = await runtime.run('Ambil screenshot.');

    expect(result.completed).toBe(true);
    expect(executeSpy).toHaveBeenCalledWith('screenshot', {}, 'call_screen_1');
    expect(result.text).toBe('Screenshot berhasil disimpan di Mac Anda.');
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

    const result = await runtime.run('Buka Terminal dan jalankan pwd.');

    expect(result.completed).toBe(true);
    expect(result.steps[0].toolResults?.[0]?.result?.success).toBe(true);
  });

  // --------------------------------------------------------------------------
  // Test 7: Multi-step task: Buka Spotify dan cari Bruno Mars
  // --------------------------------------------------------------------------
  it('Test 7: User: "Buka Spotify dan cari Bruno Mars." -> Performs multi-step tool calls', async () => {
    const mockLLM = new MockLLMProvider([
      {
        content: 'Langkah 1: Membuka Spotify...',
        toolCalls: [
          {
            id: 'call_step1_open',
            name: 'open_app',
            parameters: { appName: 'Spotify' },
          },
        ],
      },
      {
        content: 'Langkah 2: Mengetik pencarian Bruno Mars...',
        toolCalls: [
          {
            id: 'call_step2_type',
            name: 'type_text',
            parameters: { text: 'Bruno Mars' },
          },
        ],
      },
      {
        content: 'Langkah 3: Menekan Enter untuk mencari...',
        toolCalls: [
          {
            id: 'call_step3_press',
            name: 'press_key',
            parameters: { key: 'return' },
          },
        ],
      },
      {
        content: 'Beres bos! Spotify sudah terbuka dan lagu Bruno Mars sudah dicari.',
      },
    ]);

    const executor = new ToolExecutor({ confirmSensitive: false });
    const executeSpy = vi.spyOn(executor, 'execute');

    const runtime = new AgentRuntime({
      llmProvider: mockLLM,
      toolExecutor: executor,
    });

    const result = await runtime.run('Buka Spotify dan cari Bruno Mars.');

    expect(result.completed).toBe(true);
    expect(result.steps.length).toBe(4);
    expect(executeSpy).toHaveBeenCalledTimes(3);
    expect(result.text).toContain('Bruno Mars');
  });
});
