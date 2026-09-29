import { describe, it, expect, vi } from 'vitest';
import { StructuredLogger } from './index.js';

describe('StructuredLogger', () => {
  it('redacts API keys and secrets from log messages and metadata', () => {
    const logger = new StructuredLogger('info');
    const consoleSpy = vi.spyOn(console, 'info').mockImplementation(() => {});

    logger.info('Calling API with key AIzaSyA12345678901234567890123456789012', {
      apiKey: 'secret-key-value',
      user: 'dyn',
    });

    expect(consoleSpy).toHaveBeenCalled();
    const loggedMessage = consoleSpy.mock.calls[0][0];
    expect(loggedMessage).toContain('[REDACTED_API_KEY]');
    expect(loggedMessage).toContain('[REDACTED]');
    expect(loggedMessage).not.toContain('secret-key-value');

    consoleSpy.mockRestore();
  });
});
