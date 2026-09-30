import { describe, it, expect } from 'vitest';
import { setVolumeTool } from './volume.js';

describe('Volume Tool', () => {
  it('should have correct name and parameters definition', () => {
    expect(setVolumeTool.name).toBe('set_volume');
    expect(setVolumeTool.permissionLevel).toBe('SAFE');
    expect(setVolumeTool.parameters.required).toContain('action');
  });

  it('should query volume successfully', async () => {
    const mockContext = {
      logger: {
        info: () => {},
        warn: () => {},
        error: () => {},
        debug: () => {},
      },
      runtime: {} as any,
    };

    const res = await setVolumeTool.execute({ action: 'get' }, mockContext as any);
    expect(res.success).toBe(true);
    if (res.success) {
      expect(typeof res.data.currentVolume).toBe('number');
      expect(res.data.currentVolume).toBeGreaterThanOrEqual(0);
      expect(res.data.currentVolume).toBeLessThanOrEqual(100);
      expect(typeof res.data.isMuted).toBe('boolean');
    }
  });
});
