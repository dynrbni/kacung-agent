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

// ----------------------------------------------------------------------------
// Right Click Tool
// ----------------------------------------------------------------------------
export interface RightClickParams {
  x: number;
  y: number;
}

export const rightClickTool: ToolDefinition<RightClickParams, { x: number; y: number; message: string }> = {
  name: 'right_click',
  description: 'Simulates a mouse right-click (secondary click) at specific (x, y) screen coordinates.',
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
  async execute(params: RightClickParams, context: ToolExecutionContext): Promise<ToolResult<{ x: number; y: number; message: string }>> {
    const { x, y } = params;
    context.logger.info(`Right clicking at (${x}, ${y})`);

    const swiftCode = `
import CoreGraphics
import Foundation

let point = CGPoint(x: ${x}, y: ${y})
let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .right)
move?.post(tap: .cghidEventTap)

usleep(15000)

let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right)
down?.post(tap: .cghidEventTap)

usleep(30000)

let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right)
up?.post(tap: .cghidEventTap)

print("SUCCESS")
`;

    try {
      await runSwiftSnippet(swiftCode);
      return {
        success: true,
        data: { x, y, message: `Right clicked at (${x}, ${y})` },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Right click failed: ${msg}`);
      return { success: false, error: `Right click failed: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Drag Tool
// ----------------------------------------------------------------------------
export interface DragParams {
  startX: number;
  startY: number;
  endX: number;
  endY: number;
}

export const dragTool: ToolDefinition<DragParams, { startX: number; startY: number; endX: number; endY: number; message: string }> = {
  name: 'drag',
  description: 'Simulates clicking and dragging the mouse from a start point (startX, startY) to an end point (endX, endY).',
  permissionLevel: 'SENSITIVE',
  parameters: {
    type: 'object',
    properties: {
      startX: { type: 'number', description: 'Starting horizontal coordinate' },
      startY: { type: 'number', description: 'Starting vertical coordinate' },
      endX: { type: 'number', description: 'Ending horizontal coordinate' },
      endY: { type: 'number', description: 'Ending vertical coordinate' },
    },
    required: ['startX', 'startY', 'endX', 'endY'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    const required = ['startX', 'startY', 'endX', 'endY'];
    for (const f of required) {
      if (typeof p[f] !== 'number' || isNaN(p[f] as number)) {
        return { valid: false, error: `${f} must be a valid number` };
      }
    }
    return { valid: true };
  },
  async execute(params: DragParams, context: ToolExecutionContext): Promise<ToolResult<{ startX: number; startY: number; endX: number; endY: number; message: string }>> {
    const { startX, startY, endX, endY } = params;
    context.logger.info(`Dragging from (${startX}, ${startY}) to (${endX}, ${endY})`);

    const swiftCode = `
import CoreGraphics
import Foundation

let startPoint = CGPoint(x: ${startX}, y: ${startY})
let endPoint = CGPoint(x: ${endX}, y: ${endY})

let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: startPoint, mouseButton: .left)
move?.post(tap: .cghidEventTap)
usleep(20000)

let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left)
down?.post(tap: .cghidEventTap)
usleep(30000)

// Interpolate steps
let steps = 10
for i in 1...steps {
    let t = Double(i) / Double(steps)
    let currentX = Double(${startX}) + Double(${endX} - ${startX}) * t
    let currentY = Double(${startY}) + Double(${endY} - ${startY}) * t
    let p = CGPoint(x: currentX, y: currentY)
    let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: p, mouseButton: .left)
    drag?.post(tap: .cghidEventTap)
    usleep(15000)
}

let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left)
up?.post(tap: .cghidEventTap)

print("SUCCESS")
`;

    try {
      await runSwiftSnippet(swiftCode);
      return {
        success: true,
        data: { startX, startY, endX, endY, message: `Dragged from (${startX}, ${startY}) to (${endX}, ${endY})` },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Drag failed: ${msg}`);
      return { success: false, error: `Drag failed: ${msg}` };
    }
  },
};
