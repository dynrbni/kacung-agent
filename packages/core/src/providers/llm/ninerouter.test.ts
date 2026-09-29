import { describe, it, expect, vi, beforeEach } from 'vitest';
import { NineRouterProvider } from './ninerouter.js';

// Mock openai
vi.mock('openai', () => {
  return {
    default: class MockOpenAI {
      public chat = {
        completions: {
          create: vi.fn(),
        },
      };
      constructor(public options: unknown) {}
    },
  };
});

describe('NineRouterProvider', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should initialize with default 9Router values', () => {
    delete process.env.NINEROUTER_BASE_URL;
    delete process.env.NINEROUTER_API_KEY;
    delete process.env.NINEROUTER_MODEL;

    const provider = new NineRouterProvider();
    expect(provider.name).toBe('ninerouter');
    expect(provider.baseUrl).toBe('http://localhost:20128/v1');
    expect(provider.model).toBe('ag/gemini-3.8-flash-high');
  });

  it('should initialize with custom options', () => {
    const provider = new NineRouterProvider({
      baseUrl: 'http://custom-host:20128/v1/',
      apiKey: 'test-key',
      model: 'ag/gemini-3.8-flash-high',
    });

    expect(provider.baseUrl).toBe('http://custom-host:20128/v1');
    expect(provider.model).toBe('ag/gemini-3.8-flash-high');
  });

  it('should complete conversation without tool calls', async () => {
    const provider = new NineRouterProvider();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (provider as any).client.chat.completions.create.mockResolvedValueOnce({
      choices: [
        {
          message: {
            role: 'assistant',
            content: 'Ibukota Indonesia adalah Nusantara (sebelumnya Jakarta).',
          },
        },
      ],
    });

    const result = await provider.complete({
      messages: [{ role: 'user', content: 'What is the capital of Indonesia?' }],
    });

    expect(result.content).toBe('Ibukota Indonesia adalah Nusantara (sebelumnya Jakarta).');
    expect(result.toolCalls).toBeUndefined();
  });

  it('should parse tool calls returned by 9Router', async () => {
    const provider = new NineRouterProvider();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (provider as any).client.chat.completions.create.mockResolvedValueOnce({
      choices: [
        {
          message: {
            role: 'assistant',
            content: null,
            tool_calls: [
              {
                id: 'call_spotify_1',
                type: 'function',
                function: {
                  name: 'open_app',
                  arguments: JSON.stringify({ appName: 'Spotify' }),
                },
              },
            ],
          },
        },
      ],
    });

    const result = await provider.complete({
      messages: [{ role: 'user', content: 'Buka Spotify' }],
    });

    expect(result.toolCalls).toBeDefined();
    expect(result.toolCalls?.length).toBe(1);
    expect(result.toolCalls?.[0]).toEqual({
      id: 'call_spotify_1',
      name: 'open_app',
      parameters: { appName: 'Spotify' },
    });
  });

  it('should throw friendly error when 9Router connection fails (ECONNREFUSED)', async () => {
    const provider = new NineRouterProvider({ baseUrl: 'http://localhost:20128/v1' });
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (provider as any).client.chat.completions.create.mockRejectedValueOnce(
      new Error('connect ECONNREFUSED 127.0.0.1:20128')
    );

    await expect(
      provider.complete({ messages: [{ role: 'user', content: 'test' }] })
    ).rejects.toThrow('Gue nggak bisa terhubung ke 9Router di http://localhost:20128/v1. Pastikan 9Router sedang berjalan.');
  });

  it('should throw friendly error when 9Router authentication fails', async () => {
    const provider = new NineRouterProvider();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (provider as any).client.chat.completions.create.mockRejectedValueOnce(
      new Error('401 Unauthorized: Incorrect API key')
    );

    await expect(
      provider.complete({ messages: [{ role: 'user', content: 'test' }] })
    ).rejects.toThrow('Autentikasi 9Router gagal. Periksa kembali NINEROUTER_API_KEY di file .env Anda.');
  });
});
