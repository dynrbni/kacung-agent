import { describe, it, expect } from 'vitest';
import { loadConfig } from './index.js';

describe('Config Loader', () => {
  it('should load default configuration values', () => {
    const config = loadConfig();
    expect(config).toBeDefined();
    expect(config.server.port).toBeTypeOf('number');
    expect(config.assistant.name).toBe('Kacung');
    expect(config.assistant.wakePhrase).toBe('Woi Kacung');
    expect(config.assistant.languages).toContain('id');
    expect(config.assistant.languages).toContain('en');
    expect(config.security.confirmSensitiveActions).toBe(true);
    expect(config.security.confirmDangerousActions).toBe(true);
  });
});
