import { describe, it, expect, afterAll, beforeAll } from 'vitest';
import type { AddressInfo } from 'net';
import os from 'os';
import path from 'path';
import fs from 'fs';
import {
  FileConversationStore,
  FileMemoryStore,
  TaskManager,
  ActivityLog,
  SettingsStore,
  AccountStore,
  MockLLMProvider,
  MockTTSProvider,
} from '@lofly/core';
import { LoflyAgentApp } from '../apps/agent/src/app.js';

function isolatedStores() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'lofly-streaming-test-'));
  return {
    conversations: new FileConversationStore(path.join(dir, 'conversations.json')),
    memory: new FileMemoryStore(path.join(dir, 'memory.json')),
    tasks: new TaskManager(),
    activity: new ActivityLog({ filePath: path.join(dir, 'activity.json') }),
    settings: new SettingsStore(path.join(dir, 'settings.json')),
    account: new AccountStore(path.join(dir, 'account.json')),
  };
}

function testConfig() {
  return {
    server: { port: 0, host: '127.0.0.1' },
    llm: {
      provider: 'mock' as const,
      model: 'test-model',
      nineRouterBaseUrl: 'http://localhost:1/v1',
      nineRouterModel: 'test',
      ollamaBaseUrl: '',
      ollamaModel: '',
    },
    stt: { provider: 'mock' as const },
    tts: { provider: 'mock' as const, voice: '', speed: 1 },
    assistant: { name: 'Lofly', wakePhrase: 'Woi Lofly', languages: ['id'], hotkeyFallback: 'Control+Option' },
    security: { confirmSensitiveActions: true, confirmDangerousActions: true },
    logging: { level: 'error' as const },
  };
}

describe('Real-time Streaming Response API', () => {
  let app: LoflyAgentApp;
  let baseUrl: string;

  beforeAll(async () => {
    const mockLLM = new MockLLMProvider([
      {
        content: 'Smoking is dangerous because it can damage the lungs.',
      },
    ]);

    app = new LoflyAgentApp({
      config: testConfig(),
      ...isolatedStores(),
      llmProvider: mockLLM,
      ttsProvider: new MockTTSProvider(),
    });
    await app.listen(0, '127.0.0.1');
    baseUrl = `http://127.0.0.1:${(app.httpServer.address() as AddressInfo).port}`;
  });

  afterAll(async () => {
    await app.close();
  });

  it('streams response incrementally using Server-Sent Events', async () => {
    const res = await fetch(`${baseUrl}/query`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'text/event-stream',
      },
      body: JSON.stringify({
        text: 'What is the danger of smoking?',
        stream: true,
      }),
    });

    expect(res.status).toBe(200);
    expect(res.headers.get('content-type')).toContain('text/event-stream');

    const reader = res.body?.getReader();
    expect(reader).toBeDefined();

    const decoder = new TextDecoder();
    let streamText = '';
    const chunks: string[] = [];
    let sawDone = false;

    while (reader) {
      const { done, value } = await reader.read();
      if (done) break;
      const text = decoder.decode(value);
      streamText += text;

      const lines = text.split('\n');
      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const payload = JSON.parse(line.slice(6));
          if (payload.type === 'chunk') {
            chunks.push(payload.text);
          } else if (payload.type === 'done') {
            sawDone = true;
            expect(payload.text).toContain('Smoking is dangerous');
          }
        }
      }
    }

    expect(chunks.length).toBeGreaterThan(1);
    expect(chunks.join('')).toContain('Smoking is dangerous');
    expect(sawDone).toBe(true);
  });

  it('handles client cancellation during streaming gracefully', async () => {
    const controller = new AbortController();
    const res = await fetch(`${baseUrl}/query`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'text/event-stream',
      },
      body: JSON.stringify({
        text: 'What is the danger of smoking?',
        stream: true,
      }),
      signal: controller.signal,
    });

    expect(res.status).toBe(200);
    const reader = res.body?.getReader();
    expect(reader).toBeDefined();

    // Read the first chunk
    const { value } = (await reader?.read()) || {};
    expect(value).toBeDefined();

    // Abort connection (user clicks stop)
    controller.abort();

    // Also call POST /cancel to confirm endpoint responds cleanly
    const cancelRes = await fetch(`${baseUrl}/cancel`, { method: 'POST' });
    expect(cancelRes.status).toBe(200);
    const cancelJson = await cancelRes.json();
    expect(cancelJson.success).toBe(true);
  });
});
