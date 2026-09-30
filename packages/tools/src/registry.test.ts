import { describe, it, expect } from 'vitest';
import { ToolRegistry } from './registry.js';

describe('ToolRegistry', () => {
  it('should initialize with all default computer-use tools', () => {
    const registry = new ToolRegistry();
    expect(registry.count()).toBe(39);

    const expectedTools = [
      'open_app',
      'close_app',
      'focus_app',
      'is_app_running',
      'screenshot',
      'screenshot_app',
      'inspect_ui',
      'click',
      'double_click',
      'right_click',
      'move_mouse',
      'drag',
      'scroll',
      'type_text',
      'press_key',
      'hotkey',
      'wait',
      'wait_for_app',
      'verify_state',
      'read_file',
      'write_file',
      'find_file',
      'list_directory',
      'create_directory',
      'copy_file',
      'move_file',
      'delete_file',
      'run_command',
      'open_url',
      'web_search',
      'read_web_page',
      'play_music',
      'search_music',
      'open_whatsapp',
      'search_whatsapp_contact',
      'open_whatsapp_chat',
      'send_whatsapp_message',
      'set_volume',
      'write_word_document',
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

  it('should export LLM function declarations properly for all tools', () => {
    const registry = new ToolRegistry();
    const llmTools = registry.toLLMTools();

    expect(llmTools.length).toBe(39);
    for (const item of llmTools) {
      expect(item.type).toBe('function');
      expect(item.function.name).toBeTypeOf('string');
      expect(item.function.description).toBeTypeOf('string');
      expect(item.function.parameters).toBeDefined();
    }
  });
});
