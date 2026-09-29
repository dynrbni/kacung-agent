import { describe, it, expect } from 'vitest';
import { ToolRegistry } from './registry.js';

describe('ToolRegistry', () => {
  it('should initialize with all 17 default tools', () => {
    const registry = new ToolRegistry();
    expect(registry.count()).toBe(17);

    const expectedTools = [
      'open_app',
      'close_app',
      'screenshot',
      'click',
      'double_click',
      'move_mouse',
      'scroll',
      'type_text',
      'press_key',
      'read_file',
      'write_file',
      'run_command',
      'open_url',
      'web_search',
      'read_web_page',
      'play_music',
      'search_music',
    ];

    for (const toolName of expectedTools) {
      expect(registry.has(toolName)).toBe(true);
      const tool = registry.get(toolName);
      expect(tool).toBeDefined();
      expect(tool?.name).toBe(toolName);
      expect(tool?.description).toBeTypeOf('string');
      expect(tool?.parameters.type).toBe('object');
    }
  });

  it('should export LLM function declarations properly', () => {
    const registry = new ToolRegistry();
    const llmTools = registry.toLLMTools();

    expect(llmTools.length).toBe(17);
    for (const item of llmTools) {
      expect(item.type).toBe('function');
      expect(item.function.name).toBeTypeOf('string');
      expect(item.function.description).toBeTypeOf('string');
      expect(item.function.parameters).toBeDefined();
    }
  });
});
