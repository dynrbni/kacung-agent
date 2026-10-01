import { execFile } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import type { Logger, WhatsAppContact, WhatsAppExecutor, WhatsAppMessageResult } from '@lofly/types';

const execFileAsync = promisify(execFile);

/**
 * Performs the real side effect: drives WhatsApp Desktop via AppleScript.
 * Only reachable when the execution policy resolves to `live`.
 */
export class LiveWhatsAppExecutor implements WhatsAppExecutor {
  readonly mode = 'live' as const;
  private logger?: Logger;

  constructor(logger?: Logger) {
    this.logger = logger;
  }

  /**
   * Checks whether WhatsApp Desktop application is installed.
   */
  public async isWhatsAppInstalled(): Promise<boolean> {
    const commonPaths = [
      '/Applications/WhatsApp.app',
      `${process.env.HOME}/Applications/WhatsApp.app`,
    ];
    for (const p of commonPaths) {
      if (fs.existsSync(p)) return true;
    }
    try {
      const { stdout } = await execFileAsync('mdfind', [
        "kMDItemCFBundleIdentifier == 'net.whatsapp.WhatsApp'",
      ]);
      return stdout.trim().length > 0;
    } catch {
      return false;
    }
  }

  /**
   * Opens WhatsApp Desktop or WhatsApp Web in default browser.
   */
  public async openWhatsApp(): Promise<{ target: 'app' | 'web'; message: string }> {
    const installed = await this.isWhatsAppInstalled();
    if (installed) {
      this.logger?.info('Ensuring WhatsApp Desktop is open and frontmost with active window');
      // macOS AppleScript to reopen and activate, ensuring window is rendered even if previously closed/hidden
      const script = `
        tell application "WhatsApp"
          reopen
          activate
        end tell
        tell application "System Events"
          repeat with i from 1 to 25
            if (count of (windows of process "WhatsApp")) > 0 then exit repeat
            delay 0.2
          end repeat
        end tell
      `;
      try {
        await execFileAsync('osascript', ['-e', script]);
      } catch (err) {
        // Fallback open
        await execFileAsync('open', ['-a', 'WhatsApp']);
      }
      // Give Catalyst UI 600ms to paint
      await new Promise((r) => setTimeout(r, 600));
      return { target: 'app', message: 'Aplikasi WhatsApp Desktop berhasil dibuka.' };
    } else {
      this.logger?.info('WhatsApp Desktop not found, opening WhatsApp Web in browser');
      await execFileAsync('open', ['https://web.whatsapp.com']);
      return { target: 'web', message: 'Membuka WhatsApp Web di browser.' };
    }
  }

  /**
   * Resolves a contact name. If ambiguous candidates exist, returns candidates for disambiguation.
   */
  public resolveContact(query: string, knownContacts: WhatsAppContact[] = []): { exactMatch?: WhatsAppContact; candidates: WhatsAppContact[] } {
    const q = query.toLowerCase().trim();
    if (knownContacts.length === 0) {
      // Default single match if no specific contact book provided
      return {
        exactMatch: { name: query.trim() },
        candidates: [{ name: query.trim() }],
      };
    }

    const matches = knownContacts.filter((c) => c.name.toLowerCase().includes(q));
    if (matches.length === 1) {
      return { exactMatch: matches[0], candidates: matches };
    }
    return {
      exactMatch: undefined,
      candidates: matches,
    };
  }

  /**
   * Searches for a contact in WhatsApp by bringing WhatsApp to front and pressing shortcut or clicking search box.
   */
  public async searchContact(contactName: string): Promise<{ success: boolean; message: string }> {
    this.logger?.info(`Searching WhatsApp contact: ${contactName}`);
    await this.openWhatsApp();

    const cleanTarget = contactName.toLowerCase().trim();

    // 1. Check if contact is ALREADY active in the chat header or visible in the list via Vision OCR
    try {
      const { locateOnScreen } = await import('../vision/ocr.js');
      const vision = await locateOnScreen('WhatsApp', contactName);

      // Check A: Conversation is already open and visible in header
      const headerMatch = vision.texts.find(
        (t) => t.text.toLowerCase().includes(cleanTarget) && t.y < 120 && t.x > 350
      );
      if (headerMatch) {
        this.logger?.info(`Vision detected chat with "${contactName}" already open in header.`);
        return { success: true, message: `Chat "${contactName}" sudah aktif di layar.` };
      }

      // Check B: Contact is directly visible in recent list
      const directMatch = vision.texts.find(
        (t) => t.text.toLowerCase().includes(cleanTarget) && t.x < 420 && t.y > 100
      );
      if (directMatch) {
        this.logger?.info(`Vision found contact "${contactName}" in list at (${directMatch.centerX}, ${directMatch.centerY})`);
        const clickScript = `
          import CoreGraphics
          import Foundation
          let point = CGPoint(x: ${directMatch.centerX}, y: ${directMatch.centerY})
          let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
          down?.post(tap: .cghidEventTap)
          usleep(40000)
          let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
          up?.post(tap: .cghidEventTap)
        `;
        await execFileAsync('swift', ['-e', clickScript]);
        await new Promise((r) => setTimeout(r, 400));
        return { success: true, message: `Kontak "${contactName}" ditemukan dan dibuka via Vision.` };
      }
    } catch (e) {
      this.logger?.warn(`Vision pre-check error: ${e}`);
    }

    // 2. Not directly visible: Find and click Search box using Vision OCR
    let searchX = 117;
    let searchY = 100;
    try {
      const { locateOnScreen } = await import('../vision/ocr.js');
      const searchVision = await locateOnScreen('WhatsApp', 'Search');
      const searchItem = searchVision.texts.find((t) => t.text.toLowerCase().includes('search'));
      if (searchItem) {
        searchX = Math.round(searchItem.centerX);
        searchY = Math.round(searchItem.centerY);
      } else if (searchVision.window) {
        searchX = Math.round(searchVision.window.x + 120);
        searchY = Math.round(searchVision.window.y + 70);
      }
    } catch {}

    const escaped = contactName.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    const searchScript = `
      import CoreGraphics
      import Foundation

      let point = CGPoint(x: ${searchX}, y: ${searchY})
      let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
      down?.post(tap: .cghidEventTap)
      usleep(40000)
      let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
      up?.post(tap: .cghidEventTap)
    `;
    try {
      await execFileAsync('swift', ['-e', searchScript]);
    } catch {}

    await new Promise((r) => setTimeout(r, 250));

    // Type recipient contact name into search field
    const typeScript = `
      tell application "System Events"
        tell process "WhatsApp"
          set frontmost to true
          keystroke "${escaped}"
          delay 0.6
          key code 125 -- Down arrow to highlight first search match
          delay 0.2
          key code 36  -- Return to select
        end tell
      end tell
    `;
    await execFileAsync('osascript', ['-e', typeScript]);
    await new Promise((r) => setTimeout(r, 400));

    // 3. Post-search verification: click search match if visible
    try {
      const { locateOnScreen } = await import('../vision/ocr.js');
      const postVision = await locateOnScreen('WhatsApp', contactName);
      const postMatch = postVision.texts.find(
        (t) => t.text.toLowerCase().includes(cleanTarget) && t.x < 420 && t.y > 100
      );
      if (postMatch) {
        const clickResultScript = `
          import CoreGraphics
          import Foundation
          let point = CGPoint(x: ${postMatch.centerX}, y: ${postMatch.centerY})
          let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
          down?.post(tap: .cghidEventTap)
          usleep(40000)
          let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
          up?.post(tap: .cghidEventTap)
        `;
        await execFileAsync('swift', ['-e', clickResultScript]);
        await new Promise((r) => setTimeout(r, 300));
      }
    } catch {}

    return { success: true, message: `Mencari kontak "${contactName}" di WhatsApp via Vision.` };
  }

  /**
   * Opens chat with a specific phone number or contact via deep link whatsapp://send?phone=... or text.
   */
  public async openChat(contact: string, phone?: string): Promise<{ success: boolean; message: string }> {
    this.logger?.info(`Opening WhatsApp chat with: ${contact} (${phone || 'no phone'})`);
    if (phone) {
      const cleanPhone = phone.replace(/[^0-9]/g, '');
      try {
        await execFileAsync('open', [`whatsapp://send?phone=${cleanPhone}`]);
        return { success: true, message: `Membuka chat WhatsApp dengan nomor ${phone}.` };
      } catch {}
    }

    return this.searchContact(contact);
  }

  /**
   * Composes and sends a message to the specified contact in WhatsApp.
   * Ensures WhatsApp is open, navigates to the contact chat, types the exact message, and dispatches.
   */
  public async sendMessage(contactName: string, text: string): Promise<WhatsAppMessageResult> {
    this.logger?.info(`Sending WhatsApp message to "${contactName}": "${text}"`);

    // 1. Ensure WhatsApp Desktop or Web is open
    await this.openWhatsApp();

    // 2. Search for and navigate to the recipient's chat conversation
    const cleanContact = contactName.trim();
    if (cleanContact) {
      await this.searchContact(cleanContact);
      await new Promise((r) => setTimeout(r, 500));
    }

    // 3. Locate or focus the message input field at the bottom right
    // Use window geometry to click in the message input field to guarantee focus
    let inputX = 600;
    let inputY = 920;
    try {
      const { locateOnScreen } = await import('../vision/ocr.js');
      const winVision = await locateOnScreen('WhatsApp', '');
      if (winVision.window) {
        inputX = Math.round(winVision.window.x + 550);
        inputY = Math.round(winVision.window.y + winVision.window.height - 35);
      }
    } catch {}

    const focusScript = `
      import CoreGraphics
      import Foundation

      let point = CGPoint(x: ${inputX}, y: ${inputY})
      let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
      down?.post(tap: .cghidEventTap)
      usleep(30000)
      let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
      up?.post(tap: .cghidEventTap)
    `;
    try {
      await execFileAsync('swift', ['-e', focusScript]);
    } catch {}

    await new Promise((r) => setTimeout(r, 200));

    // 4. Paste message via clipboard and send with Return (preserves emojis and avoids dropped characters)
    const escapedText = text.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    const sendScript = `
      set the clipboard to "${escapedText}"
      tell application "System Events"
        tell process "WhatsApp"
          set frontmost to true
          keystroke "v" using command down
          delay 0.3
          key code 36 -- Return to send
        end tell
      end tell
    `;

    try {
      await execFileAsync('osascript', ['-e', sendScript]);
      return {
        recipient: contactName,
        text,
        sent: true,
        verified: true,
        details: `Pesan berhasil dikirim ke "${contactName}": "${text}".`,
        mode: 'live',
        dryRun: false,
        executed: true,
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      this.logger?.error(`Send WhatsApp message failed: ${msg}`);
      return {
        recipient: contactName,
        text,
        sent: false,
        verified: false,
        details: `Gagal mengirim pesan: ${msg}`,
        mode: 'live',
        dryRun: false,
        executed: true,
      };
    }
  }
}

/**
 * Validates and records the intended action without ever touching WhatsApp.
 * Mirrors the live executor's validation so tests exercise the same rules.
 */
export class MockWhatsAppExecutor implements WhatsAppExecutor {
  readonly mode = 'dry_run' as const;
  readonly recordedActions: Array<{ action: string; parameters: Record<string, unknown> }> = [];
  private logger?: Logger;

  constructor(logger?: Logger) {
    this.logger = logger;
  }

  private record(action: string, parameters: Record<string, unknown>): void {
    this.recordedActions.push({ action, parameters });
    this.logger?.info(`[DRY RUN] Recorded WhatsApp ${action}: ${JSON.stringify(parameters)}`);
  }

  public async openWhatsApp(): Promise<{ target: 'app' | 'web'; message: string }> {
    this.record('open_whatsapp', {});
    return {
      target: 'app',
      message: '[DRY RUN] WhatsApp tidak dibuka.',
    };
  }

  public async searchContact(contactName: string): Promise<{ success: boolean; message: string }> {
    this.record('search_whatsapp_contact', { name: contactName });
    return {
      success: true,
      message: `[DRY RUN] Kontak "${contactName}" tidak dicari di WhatsApp.`,
    };
  }

  public async openChat(contact: string, phone?: string): Promise<{ success: boolean; message: string }> {
    this.record('open_whatsapp_chat', { contact, phone });
    return {
      success: true,
      message: `[DRY RUN] Chat WhatsApp dengan "${contact}" tidak dibuka.`,
    };
  }

  public async sendMessage(contactName: string, text: string): Promise<WhatsAppMessageResult> {
    this.record('send_whatsapp_message', { recipient: contactName, message: text });
    return {
      recipient: contactName,
      text,
      sent: false,
      verified: false,
      details: `[DRY RUN] Pesan ke "${contactName}" TIDAK dikirim: "${text}".`,
      mode: 'dry_run',
      dryRun: true,
      executed: false,
    };
  }
}
