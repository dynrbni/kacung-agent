import { describe, it, expect } from 'vitest';
import { loadConfig } from './index.js';

describe('Config Loader', () => {
  it('should load default configuration values', () => {
    const config = loadConfig();
    expect(config).toBeDefined();
    expect(config.server.port).toBeTypeOf('number');
    expect(config.assistant.name).toBe('Lofly');
    expect(config.assistant.wakePhrase).toBe('Woi Lofly');
    expect(config.assistant.languages).toContain('id');
    expect(config.assistant.languages).toContain('en');
    expect(config.security.confirmSensitiveActions).toBe(false);
    expect(config.security.confirmDangerousActions).toBe(false);
    expect(config.llm.nineRouterBaseUrl).toBe('http://localhost:20128/v1');
    expect(config.llm.nineRouterModel).toBe('ag/gemini-3.8-flash-high');
  });

  it('should read custom 9Router environment variables', () => {
    process.env.NINEROUTER_BASE_URL = 'http://127.0.0.1:20128/v1';
    process.env.NINEROUTER_API_KEY = 'test-key';
    process.env.NINEROUTER_MODEL = 'ag/gemini-3.8-flash-high';

    const config = loadConfig('/non-existent-path');
    expect(config.llm.provider).toBe('ninerouter');
    expect(config.llm.nineRouterBaseUrl).toBe('http://127.0.0.1:20128/v1');
    expect(config.llm.nineRouterApiKey).toBe('test-key');
    expect(config.llm.nineRouterModel).toBe('ag/gemini-3.8-flash-high');
    expect(config.llm.model).toBe('ag/gemini-3.8-flash-high');

    delete process.env.NINEROUTER_BASE_URL;
    delete process.env.NINEROUTER_API_KEY;
    delete process.env.NINEROUTER_MODEL;
  });
});
