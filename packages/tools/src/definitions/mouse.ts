import { spawn } from 'child_process';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@kacung/types';

function runSwiftSnippet(code: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const proc = spawn('swift', ['-'], { stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (d) => {
      stdout += d.toString();
    });
    proc.stderr.on('data', (d) => {
      stderr += d.toString();
    });

    proc.on('close', (code) => {
      if (code === 0) {
        resolve(stdout.trim());
      } else {
        reject(new Error(`Swift process failed (code ${code}): ${stderr || stdout}`));
      }
    });

    proc.stdin.write(code);
    proc.stdin.end();
  });
}

// ----------------------------------------------------------------------------
// Click Tool
// ----------------------------------------------------------------------------
export interface ClickParams {
  x: number;
  y: number;
}

export const clickTool: ToolDefinition<ClickParams, { x: number; y: number; message: string }> = {
  name: 'click',
  description: 'Simulates a mouse click at specific (x, y) screen coordinates.',
  permissionLevel: 'SENSITIVE',
  parameters: {
    type: 'object',
    properties: {
      x: { type: 'number', description: 'Horizontal coordinate on screen in pixels' },
      y: { type: 'number', description: 'Vertical coordinate on screen in pixels' },
    },
    required: ['x', 'y'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (typeof p.x !== 'number' || typeof p.y !== 'number' || isNaN(p.x) || isNaN(p.y)) {
      return { valid: false, error: 'x and y must be valid numbers' };
    }
    return { valid: true };
  },
  async execute(params: ClickParams, context: ToolExecutionContext): Promise<ToolResult<{ x: number; y: number; message: string }>> {
    const { x, y } = params;
    context.logger.info(`Clicking at (${x}, ${y})`);

    const swiftCode = `
import CoreGraphics
import Foundation

let point = CGPoint(x: ${x}, y: ${y})
let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
move?.post(tap: .cghidEventTap)

usleep(15000)

let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
down?.post(tap: .cghidEventTap)

usleep(30000)

let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
up?.post(tap: .cghidEventTap)

print("SUCCESS")
`;

    try {
      await runSwiftSnippet(swiftCode);
      return {
        success: true,
        data: { x, y, message: `Clicked at (${x}, ${y})` },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Click failed: ${msg}`);
      return { success: false, error: `Click failed: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Double Click Tool
// ----------------------------------------------------------------------------
export const doubleClickTool: ToolDefinition<ClickParams, { x: number; y: number; message: string }> = {
  name: 'double_click',
  description: 'Simulates a double-click at specific (x, y) screen coordinates.',
  permissionLevel: 'SENSITIVE',
  parameters: {
    type: 'object',
    properties: {
      x: { type: 'number', description: 'Horizontal coordinate on screen in pixels' },
      y: { type: 'number', description: 'Vertical coordinate on screen in pixels' },
    },
    required: ['x', 'y'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (typeof p.x !== 'number' || typeof p.y !== 'number' || isNaN(p.x) || isNaN(p.y)) {
      return { valid: false, error: 'x and y must be valid numbers' };
    }
    return { valid: true };
  },
  async execute(params: ClickParams, context: ToolExecutionContext): Promise<ToolResult<{ x: number; y: number; message: string }>> {
    const { x, y } = params;
    context.logger.info(`Double-clicking at (${x}, ${y})`);

    const swiftCode = `
import CoreGraphics
import Foundation

let point = CGPoint(x: ${x}, y: ${y})
let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
move?.post(tap: .cghidEventTap)

usleep(15000)

let down1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
down1?.setIntegerValueField(.mouseEventClickState, value: 1)
down1?.post(tap: .cghidEventTap)

let up1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
up1?.setIntegerValueField(.mouseEventClickState, value: 1)
up1?.post(tap: .cghidEventTap)

usleep(50000)

let down2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
down2?.setIntegerValueField(.mouseEventClickState, value: 2)
down2?.post(tap: .cghidEventTap)

let up2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
up2?.setIntegerValueField(.mouseEventClickState, value: 2)
up2?.post(tap: .cghidEventTap)

print("SUCCESS")
`;

    try {
      await runSwiftSnippet(swiftCode);
      return {
        success: true,
        data: { x, y, message: `Double-clicked at (${x}, ${y})` },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Double click failed: ${msg}`);
      return { success: false, error: `Double click failed: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Move Mouse Tool
// ----------------------------------------------------------------------------
export const moveMouseTool: ToolDefinition<ClickParams, { x: number; y: number; message: string }> = {
  name: 'move_mouse',
  description: 'Moves the mouse cursor to specific (x, y) coordinates without clicking.',
  permissionLevel: 'SAFE',
  parameters: {
    type: 'object',
    properties: {
      x: { type: 'number', description: 'Horizontal coordinate on screen in pixels' },
      y: { type: 'number', description: 'Vertical coordinate on screen in pixels' },
    },
    required: ['x', 'y'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (typeof p.x !== 'number' || typeof p.y !== 'number' || isNaN(p.x) || isNaN(p.y)) {
      return { valid: false, error: 'x and y must be valid numbers' };
    }
    return { valid: true };
  },
  async execute(params: ClickParams, context: ToolExecutionContext): Promise<ToolResult<{ x: number; y: number; message: string }>> {
    const { x, y } = params;
    context.logger.info(`Moving mouse to (${x}, ${y})`);

    const swiftCode = `
import CoreGraphics
import Foundation

let point = CGPoint(x: ${x}, y: ${y})
let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
move?.post(tap: .cghidEventTap)
print("SUCCESS")
`;

    try {
      await runSwiftSnippet(swiftCode);
      return {
        success: true,
        data: { x, y, message: `Mouse moved to (${x}, ${y})` },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Move mouse failed: ${msg}`);
      return { success: false, error: `Move mouse failed: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Scroll Tool
// ----------------------------------------------------------------------------
export interface ScrollParams {
  direction: 'up' | 'down' | 'left' | 'right';
  amount?: number;
}

export const scrollTool: ToolDefinition<ScrollParams, { direction: string; amount: number; message: string }> = {
  name: 'scroll',
  description: 'Scrolls the mouse wheel in a specified direction ("up", "down", "left", "right").',
  permissionLevel: 'SAFE',
  parameters: {
    type: 'object',
    properties: {
      direction: {
        type: 'string',
        enum: ['up', 'down', 'left', 'right'],
        description: 'Direction to scroll',
      },
      amount: {
        type: 'number',
        description: 'Number of scroll lines/units (default: 5)',
      },
    },
    required: ['direction'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.direction || !['up', 'down', 'left', 'right'].includes(String(p.direction))) {
      return { valid: false, error: 'direction must be one of "up", "down", "left", "right"' };
    }
    return { valid: true };
  },
  async execute(params: ScrollParams, context: ToolExecutionContext): Promise<ToolResult<{ direction: string; amount: number; message: string }>> {
    const direction = params.direction;
    const amount = typeof params.amount === 'number' && !isNaN(params.amount) ? params.amount : 5;
    context.logger.info(`Scrolling ${direction} by ${amount}`);

    const deltaY = direction === 'up' ? amount : direction === 'down' ? -amount : 0;
    const deltaX = direction === 'left' ? amount : direction === 'right' ? -amount : 0;

    const swiftCode = `
import CoreGraphics
import Foundation

if let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: Int32(${deltaY}), wheel2: Int32(${deltaX}), wheel3: 0) {
    event.post(tap: .cghidEventTap)
}
print("SUCCESS")
`;

    try {
      await runSwiftSnippet(swiftCode);
      return {
        success: true,
        data: { direction, amount, message: `Scrolled ${direction} by ${amount}` },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Scroll failed: ${msg}`);
      return { success: false, error: `Scroll failed: ${msg}` };
    }
  },
};
