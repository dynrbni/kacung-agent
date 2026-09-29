import { describe, it, expect } from 'vitest';
import { ComputerUseEngine } from './engine.js';

describe('ComputerUseEngine', () => {
  it('should initialize successfully', () => {
    const engine = new ComputerUseEngine();
    expect(engine).toBeDefined();
    expect(typeof engine.openApp).toBe('function');
    expect(typeof engine.closeApp).toBe('function');
    expect(typeof engine.click).toBe('function');
    expect(typeof engine.typeText).toBe('function');
    expect(typeof engine.pressKey).toBe('function');
    expect(typeof engine.hotkey).toBe('function');
    expect(typeof engine.screenshot).toBe('function');
    expect(typeof engine.inspectUI).toBe('function');
    expect(typeof engine.wait).toBe('function');
    expect(typeof engine.verifyState).toBe('function');
  });

  it('should execute wait tool successfully', async () => {
    const engine = new ComputerUseEngine();
    const res = await engine.wait(100);
    expect(res.success).toBe(true);
    expect((res.data as { waitedMs: number })?.waitedMs).toBe(100);
  });

  it('should verify file_exists correctly', async () => {
    const engine = new ComputerUseEngine();
    const res = await engine.verifyState('file_exists', 'package.json');
    expect(res.success).toBe(true);
    expect((res.data as { verified: boolean })?.verified).toBe(true);
  });
});
