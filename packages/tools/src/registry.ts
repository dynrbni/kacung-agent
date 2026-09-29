import type { ToolDefinition } from '@kacung/types';
import { openAppTool, closeAppTool } from './definitions/apps.js';
import { screenshotTool } from './definitions/screen.js';
import { clickTool, doubleClickTool, moveMouseTool, scrollTool } from './definitions/mouse.js';
import { typeTextTool, pressKeyTool } from './definitions/keyboard.js';
import { readFileTool, writeFileTool } from './definitions/filesystem.js';
import { runCommandTool } from './definitions/terminal.js';
import { openUrlTool, webSearchTool, readWebPageTool } from './definitions/web.js';
import { playMusicTool, searchMusicTool } from './definitions/music.js';

export class ToolRegistry {
  private tools = new Map<string, ToolDefinition>();

  constructor() {
    this.registerDefaults();
  }

  public register(tool: ToolDefinition): void {
    if (this.tools.has(tool.name)) {
      throw new Error(`Tool "${tool.name}" is already registered.`);
    }
    this.tools.set(tool.name, tool);
  }

  public get(name: string): ToolDefinition | undefined {
    return this.tools.get(name);
  }

  public has(name: string): boolean {
    return this.tools.has(name);
  }

  public list(): ToolDefinition[] {
    return Array.from(this.tools.values());
  }

  public count(): number {
    return this.tools.size;
  }

  /**
   * Returns function declarations formatted for LLM tool calling (OpenAI / Gemini format).
   */
  public toLLMTools(): Array<{
    type: 'function';
    function: {
      name: string;
      description: string;
      parameters: ToolDefinition['parameters'];
    };
  }> {
    return this.list().map((tool) => ({
      type: 'function',
      function: {
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters,
      },
    }));
  }

  private registerDefaults(): void {
    const defaults: ToolDefinition[] = [
      openAppTool as unknown as ToolDefinition,
      closeAppTool as unknown as ToolDefinition,
      screenshotTool as unknown as ToolDefinition,
      clickTool as unknown as ToolDefinition,
      doubleClickTool as unknown as ToolDefinition,
      moveMouseTool as unknown as ToolDefinition,
      scrollTool as unknown as ToolDefinition,
      typeTextTool as unknown as ToolDefinition,
      pressKeyTool as unknown as ToolDefinition,
      readFileTool as unknown as ToolDefinition,
      writeFileTool as unknown as ToolDefinition,
      runCommandTool as unknown as ToolDefinition,
      openUrlTool as unknown as ToolDefinition,
      webSearchTool as unknown as ToolDefinition,
      readWebPageTool as unknown as ToolDefinition,
      playMusicTool as unknown as ToolDefinition,
      searchMusicTool as unknown as ToolDefinition,
    ];

    for (const tool of defaults) {
      this.tools.set(tool.name, tool);
    }
  }
}
