import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { WebSocket } from 'ws';
import { LoflyAgentApp } from './app.js';
import { MockLLMProvider, MockTTSProvider } from '@lofly/core';
import type { LoflyConfig } from '@lofly/config';

describe('LoflyAgentApp Server', () => {
  let app: LoflyAgentApp;
  const testPort = 3991;

  const testConfig: LoflyConfig = {
    server: { port: testPort, host: '127.0.0.1' },
    llm: {
      provider: 'mock',
      model: 'mock',
      nineRouterBaseUrl: 'http://localhost:20128/v1',
      nineRouterModel: 'ag/gemini-3.8-flash-high',
      ollamaBaseUrl: '',
      ollamaModel: '',
    },
    stt: { provider: 'mock' },
    tts: { provider: 'mock', voice: 'Damayanti', speed: 1 },
    assistant: {
      name: 'Lofly',
      wakePhrase: 'Woi Lofly',
      languages: ['id', 'en'],
      hotkeyFallback: 'Option+Space',
    },
    security: {
      confirmSensitiveActions: false, // automatic for unit testing
      confirmDangerousActions: true,
    },
    logging: { level: 'error' },
  };

  beforeAll(async () => {
    app = new LoflyAgentApp({
      config: testConfig,
      llmProvider: new MockLLMProvider(),
      ttsProvider: new MockTTSProvider(),
    });
    await app.listen(testPort);
  });

  afterAll(async () => {
    await app.close();
  });

  it('responds to GET /health', async () => {
    const res = await fetch(`http://127.0.0.1:${testPort}/health`);
    expect(res.status).toBe(200);
    const data = (await res.json()) as { status: string; assistant: string };
    expect(data.status).toBe('ok');
    expect(data.assistant).toBe('Lofly');
  });

  it('responds to GET /config with safe assistant info', async () => {
    const res = await fetch(`http://127.0.0.1:${testPort}/config`);
    expect(res.status).toBe(200);
    const data = (await res.json()) as {
      assistant: { name: string; wakePhrase: string };
      tools: unknown[];
    };
    expect(data.assistant.name).toBe('Lofly');
    expect(data.assistant.wakePhrase).toBe('Woi Lofly');
    expect(data.tools.length).toBeGreaterThanOrEqual(15);
  });

  it('processes queries via POST /query', async () => {
    const res = await fetch(`http://127.0.0.1:${testPort}/query`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: 'What time is it?' }),
    });

    expect(res.status).toBe(200);
    const data = (await res.json()) as { completed: boolean; text: string };
    expect(data.completed).toBe(true);
    expect(data.text).toContain('Sekarang jam');
  });

  it('connects to WebSocket and receives live state events', async () => {
    const ws = new WebSocket(`ws://127.0.0.1:${testPort}/ws`);

    const receivedEvents: Array<{ type: string }> = [];

    await new Promise<void>((resolve, reject) => {
      ws.on('open', () => {
        ws.on('message', (msg) => {
          const parsed = JSON.parse(msg.toString());
          receivedEvents.push(parsed);
          if (receivedEvents.length >= 1) {
            resolve();
          }
        });
      });
      ws.on('error', reject);
    });

    ws.close();
    expect(receivedEvents.length).toBeGreaterThanOrEqual(1);
    expect(receivedEvents[0].type).toBe('state_change');
  });
});
