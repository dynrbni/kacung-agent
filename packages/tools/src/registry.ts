import type { ToolDefinition } from '@lafly/types';
import { openAppTool, closeAppTool, focusAppTool, isAppRunningTool } from './definitions/apps.js';
import { screenshotTool, screenshotAppTool } from './definitions/screen.js';
import { clickTool, doubleClickTool, rightClickTool, moveMouseTool, dragTool, scrollTool } from './definitions/mouse.js';
import { typeTextTool, pressKeyTool, hotkeyTool } from './definitions/keyboard.js';
import {
  readFileTool,
  writeFileTool,
  findFileTool,
  listDirectoryTool,
  createDirectoryTool,
  copyFileTool,
  moveFileTool,
  deleteFileTool,
} from './definitions/filesystem.js';
import { runCommandTool } from './definitions/terminal.js';
import { openUrlTool, webSearchTool, readWebPageTool } from './definitions/web.js';
import { playMusicTool, searchMusicTool } from './definitions/music.js';
import { inspectUITool } from './definitions/ui.js';
import { waitTool, waitForAppTool } from './definitions/timing.js';
import { verifyStateTool } from './definitions/verification.js';
import {
  openWhatsAppTool,
  searchWhatsAppContactTool,
  openWhatsAppChatTool,
  sendWhatsAppMessageTool,
} from './definitions/whatsapp.js';
import { setVolumeTool } from './definitions/volume.js';
import { writeWordDocumentTool } from './definitions/word.js';

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
      // App control
      openAppTool as unknown as ToolDefinition,
      closeAppTool as unknown as ToolDefinition,
      focusAppTool as unknown as ToolDefinition,
      isAppRunningTool as unknown as ToolDefinition,

      // Screen & UI
      screenshotTool as unknown as ToolDefinition,
      screenshotAppTool as unknown as ToolDefinition,
      inspectUITool as unknown as ToolDefinition,

      // Mouse
      clickTool as unknown as ToolDefinition,
      doubleClickTool as unknown as ToolDefinition,
      rightClickTool as unknown as ToolDefinition,
      moveMouseTool as unknown as ToolDefinition,
      dragTool as unknown as ToolDefinition,
      scrollTool as unknown as ToolDefinition,

      // Keyboard
      typeTextTool as unknown as ToolDefinition,
      pressKeyTool as unknown as ToolDefinition,
      hotkeyTool as unknown as ToolDefinition,

      // Timing & Wait
      waitTool as unknown as ToolDefinition,
      waitForAppTool as unknown as ToolDefinition,

      // Verification
      verifyStateTool as unknown as ToolDefinition,

      // Filesystem
      readFileTool as unknown as ToolDefinition,
      writeFileTool as unknown as ToolDefinition,
      findFileTool as unknown as ToolDefinition,
      listDirectoryTool as unknown as ToolDefinition,
      createDirectoryTool as unknown as ToolDefinition,
      copyFileTool as unknown as ToolDefinition,
      moveFileTool as unknown as ToolDefinition,
      deleteFileTool as unknown as ToolDefinition,

      // Terminal & Web
      runCommandTool as unknown as ToolDefinition,
      openUrlTool as unknown as ToolDefinition,
      webSearchTool as unknown as ToolDefinition,
      readWebPageTool as unknown as ToolDefinition,

      // Music
      playMusicTool as unknown as ToolDefinition,
      searchMusicTool as unknown as ToolDefinition,

      // WhatsApp
      openWhatsAppTool as unknown as ToolDefinition,
      searchWhatsAppContactTool as unknown as ToolDefinition,
      openWhatsAppChatTool as unknown as ToolDefinition,
      sendWhatsAppMessageTool as unknown as ToolDefinition,

      // System Volume
      setVolumeTool as unknown as ToolDefinition,

      // Document & Word Processing
      writeWordDocumentTool as unknown as ToolDefinition,
    ];

    for (const tool of defaults) {
      this.tools.set(tool.name, tool);
    }
  }
}
