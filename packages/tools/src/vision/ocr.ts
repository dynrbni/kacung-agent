import { execFile } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const execFileAsync = promisify(execFile);

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export interface DetectedText {
  text: string;
  confidence: number;
  x: number;
  y: number;
  width: number;
  height: number;
  centerX: number;
  centerY: number;
}

export interface WindowInfo {
  windowId: number;
  ownerName: string;
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface VisionResult {
  window?: WindowInfo;
  scale: number;
  texts: DetectedText[];
}

/**
 * Resolves the path to the compiled vision_ocr binary.
 */
function getVisionBinaryPath(): string {
  // In source tree: packages/tools/bin/vision_ocr
  // In compiled dist: dist/../bin/vision_ocr
  const possiblePaths = [
    path.resolve(__dirname, '../../bin/vision_ocr'),
    path.resolve(__dirname, '../../../bin/vision_ocr'),
    path.resolve(process.cwd(), 'packages/tools/bin/vision_ocr'),
    '/Users/dyn/Documents/Coding/Project/lofly/packages/tools/bin/vision_ocr',
  ];

  for (const p of possiblePaths) {
    if (fs.existsSync(p)) return p;
  }
  return 'vision_ocr';
}

/**
 * Locates text and UI elements on screen or inside a specific application window using Apple Vision OCR.
 */
export async function locateOnScreen(appName = 'WhatsApp', query = ''): Promise<VisionResult> {
  const binary = getVisionBinaryPath();
  try {
    const { stdout } = await execFileAsync(binary, [appName, query]);
    const parsed = JSON.parse(stdout.trim() || '{"texts":[],"scale":2}') as VisionResult;
    return parsed;
  } catch (err) {
    return {
      window: undefined,
      scale: 2,
      texts: [],
    };
  }
}

/**
 * Finds the first or best matching text item on the screen.
 */
export async function findTextOnScreen(appName: string, query: string): Promise<DetectedText | undefined> {
  const res = await locateOnScreen(appName, query);
  const q = query.toLowerCase().trim();
  // Exact match first
  const exact = res.texts.find((t) => t.text.toLowerCase().trim() === q);
  if (exact) return exact;
  // Substring match
  return res.texts.find((t) => t.text.toLowerCase().includes(q));
}

/**
 * Clicks a text element on screen by locating it through Apple Vision OCR.
 */
export async function clickTextOnScreen(appName: string, query: string): Promise<{ clicked: boolean; x?: number; y?: number }> {
  const found = await findTextOnScreen(appName, query);
  if (!found) {
    return { clicked: false };
  }

  const script = `
    import CoreGraphics
    import Foundation

    let point = CGPoint(x: ${found.centerX}, y: ${found.centerY})
    let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    down?.post(tap: .cghidEventTap)
    usleep(40000)
    let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    up?.post(tap: .cghidEventTap)
  `;

  await execFileAsync('swift', ['-e', script]);
  return {
    clicked: true,
    x: found.centerX,
    y: found.centerY,
  };
}
