import type { Logger, UIElement, ToolResult } from '@lafly/types';
import { openAppTool, closeAppTool, focusAppTool, isAppRunningTool } from '../definitions/apps.js';
import { clickTool, doubleClickTool, rightClickTool, moveMouseTool, dragTool, scrollTool } from '../definitions/mouse.js';
import { typeTextTool, pressKeyTool, hotkeyTool } from '../definitions/keyboard.js';
import { screenshotTool, screenshotAppTool } from '../definitions/screen.js';
import { inspectUITool } from '../definitions/ui.js';
import { waitTool, waitForAppTool } from '../definitions/timing.js';
import { verifyStateTool } from '../definitions/verification.js';
import { getExecutionPolicy } from '../safety/policy.js';

export interface ComputerUseEngineOptions {
  logger?: Logger;
}

export class ComputerUseEngine {
  private logger?: Logger;

  constructor(options: ComputerUseEngineOptions = {}) {
    this.logger = options.logger;
  }

  private getContext(actionName: string) {
    return {
      requestId: `engine_${Date.now()}_${actionName}`,
      logger: this.logger || {
        debug: () => {},
        info: () => {},
        warn: () => {},
        error: () => {},
      },
      policy: getExecutionPolicy(),
    };
  }

  // --------------------------------------------------------------------------
  // Application Control
  // --------------------------------------------------------------------------
  public async openApp(appName: string): Promise<ToolResult> {
    return openAppTool.execute({ appName }, this.getContext('open_app'));
  }

  public async closeApp(appName: string): Promise<ToolResult> {
    return closeAppTool.execute({ appName }, this.getContext('close_app'));
  }

  public async focusApp(appName: string): Promise<ToolResult> {
    return focusAppTool.execute({ appName }, this.getContext('focus_app'));
  }

  public async isAppRunning(appName: string): Promise<boolean> {
    const res = await isAppRunningTool.execute({ appName }, this.getContext('is_app_running'));
    return Boolean(res.data?.running);
  }

  // --------------------------------------------------------------------------
  // Screen Observation & Capture
  // --------------------------------------------------------------------------
  public async observeScreen(includeBase64 = false): Promise<ToolResult> {
    return screenshotTool.execute({ includeBase64 }, this.getContext('observe_screen'));
  }

  public async screenshot(includeBase64 = false): Promise<ToolResult> {
    return this.observeScreen(includeBase64);
  }

  public async screenshotApp(appName: string, includeBase64 = false): Promise<ToolResult> {
    return screenshotAppTool.execute({ appName, includeBase64 }, this.getContext('screenshot_app'));
  }

  // --------------------------------------------------------------------------
  // UI Inspection & Semantic Control
  // --------------------------------------------------------------------------
  public async inspectUI(appName?: string, maxElements?: number): Promise<ToolResult<{ application: string; windowTitle?: string; elements: UIElement[]; totalFound: number }>> {
    return inspectUITool.execute({ appName, maxElements }, this.getContext('inspect_ui'));
  }

  public async findUIElement(query: string, appName?: string): Promise<UIElement | undefined> {
    const res = await this.inspectUI(appName, 50);
    if (!res.success || !res.data?.elements) return undefined;

    const q = query.toLowerCase();
    return res.data.elements.find((el) => {
      const titleMatch = el.title?.toLowerCase().includes(q);
      const valueMatch = el.value?.toLowerCase().includes(q);
      const descMatch = el.description?.toLowerCase().includes(q);
      return titleMatch || valueMatch || descMatch;
    });
  }

  // --------------------------------------------------------------------------
  // Mouse Control
  // --------------------------------------------------------------------------
  public async click(x: number, y: number): Promise<ToolResult> {
    return clickTool.execute({ x, y }, this.getContext('click'));
  }

  public async doubleClick(x: number, y: number): Promise<ToolResult> {
    return doubleClickTool.execute({ x, y }, this.getContext('double_click'));
  }

  public async rightClick(x: number, y: number): Promise<ToolResult> {
    return rightClickTool.execute({ x, y }, this.getContext('right_click'));
  }

  public async moveMouse(x: number, y: number): Promise<ToolResult> {
    return moveMouseTool.execute({ x, y }, this.getContext('move_mouse'));
  }

  public async drag(startX: number, startY: number, endX: number, endY: number): Promise<ToolResult> {
    return dragTool.execute({ startX, startY, endX, endY }, this.getContext('drag'));
  }

  public async scroll(direction: 'up' | 'down' | 'left' | 'right', amount = 5): Promise<ToolResult> {
    return scrollTool.execute({ direction, amount }, this.getContext('scroll'));
  }

  // --------------------------------------------------------------------------
  // Keyboard Control
  // --------------------------------------------------------------------------
  public async typeText(text: string): Promise<ToolResult> {
    return typeTextTool.execute({ text }, this.getContext('type_text'));
  }

  public async pressKey(key: string, modifiers?: Array<'command' | 'control' | 'option' | 'shift'>): Promise<ToolResult> {
    return pressKeyTool.execute({ key, modifiers }, this.getContext('press_key'));
  }

  public async hotkey(keys: string[]): Promise<ToolResult> {
    return hotkeyTool.execute({ keys }, this.getContext('hotkey'));
  }

  // --------------------------------------------------------------------------
  // Timing & Waiting
  // --------------------------------------------------------------------------
  public async wait(ms: number): Promise<ToolResult> {
    return waitTool.execute({ ms }, this.getContext('wait'));
  }

  public async waitForApp(appName: string, timeoutMs = 5000): Promise<ToolResult> {
    return waitForAppTool.execute({ appName, timeoutMs }, this.getContext('wait_for_app'));
  }

  // --------------------------------------------------------------------------
  // Verification
  // --------------------------------------------------------------------------
  public async verifyState(
    action: 'app_running' | 'app_frontmost' | 'file_exists' | 'music_playing' | 'custom_check',
    target: string
  ): Promise<ToolResult> {
    return verifyStateTool.execute({ action, target }, this.getContext('verify_state'));
  }
}
