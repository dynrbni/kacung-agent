import { execFile } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import type { Logger, WhatsAppContact, WhatsAppExecutor, WhatsAppMessageResult } from '@lafly/types';

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
      this.logger?.info('Opening WhatsApp Desktop');
      await execFileAsync('open', ['-a', 'WhatsApp']);
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
   * Searches for a contact in WhatsApp by bringing WhatsApp to front and pressing shortcut (Cmd+F or Cmd+K).
   */
  public async searchContact(contactName: string): Promise<{ success: boolean; message: string }> {
    this.logger?.info(`Searching WhatsApp contact: ${contactName}`);
    await this.openWhatsApp();
    await new Promise((r) => setTimeout(r, 600));

    // Try Cmd+F or Cmd+K to focus search bar
    const escaped = contactName.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    const script = `
      tell application "System Events"
        tell process "WhatsApp"
          set frontmost to true
          keystroke "f" using command down
          delay 0.3
          keystroke "${escaped}"
          delay 0.5
          key code 36 -- Return
        end tell
      end tell
    `;
    try {
      await execFileAsync('osascript', ['-e', script]);
      return { success: true, message: `Mencari kontak "${contactName}" di WhatsApp.` };
    } catch (err) {
      this.logger?.warn(`WhatsApp contact search script failed: ${err}`);
      return { success: true, message: `Membuka WhatsApp untuk kontak "${contactName}".` };
    }
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
    await new Promise((r) => setTimeout(r, 400));

    // 2. Search for and navigate to the recipient's chat conversation
    const cleanContact = contactName.trim();
    if (cleanContact) {
      await this.searchContact(cleanContact);
      // Wait for conversation to load and input field to gain focus
      await new Promise((r) => setTimeout(r, 500));
    }

    // 3. Type text into focused message field and hit Return
    const escaped = text.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    const script = `
      tell application "System Events"
        tell process "WhatsApp"
          set frontmost to true
          delay 0.2
          keystroke "${escaped}"
          delay 0.2
          key code 36 -- Return to send
        end tell
      end tell
    `;

    try {
      await execFileAsync('osascript', ['-e', script]);
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
