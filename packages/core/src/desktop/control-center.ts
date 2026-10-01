import fs from 'fs';
import path from 'path';
import os from 'os';
import type { AccountSession, IntegrationDescriptor, IntegrationStatus } from '@lafly/types';

/**
 * Read-only view over which integrations are usable right now.
 *
 * Status is derived from real runtime state (configured model, resolved tool
 * registry, OS capabilities) rather than stored separately, so the screen can
 * never claim a connection that does not exist. No credential ever passes
 * through here.
 */
export interface IntegrationProbeContext {
  llmConfigured: boolean;
  llmProvider: string;
  hasWhatsApp: boolean;
  hasMusic: boolean;
  hasSpotify: boolean;
  hasWord: boolean;
  hasChrome: boolean;
}

export function describeIntegrations(ctx: IntegrationProbeContext): IntegrationDescriptor[] {
  return [
    {
      id: 'ninerouter',
      name: '9Router',
      category: 'developer',
      status: ctx.llmConfigured ? 'connected' : 'needs_authentication',
      detail: ctx.llmConfigured
        ? `Model provider "${ctx.llmProvider}" is configured.`
        : 'No model provider configured. Set NINEROUTER_API_KEY in .env.',
    },
    {
      id: 'whatsapp',
      name: 'WhatsApp',
      category: 'messaging',
      status: ctx.hasWhatsApp ? 'connected' : 'needs_permission',
      detail: ctx.hasWhatsApp
        ? 'WhatsApp Desktop automation is available.'
        : 'Requires Accessibility permission to drive WhatsApp.',
    },
    {
      id: 'apple_music',
      name: 'Apple Music',
      category: 'music',
      status: ctx.hasMusic ? 'connected' : 'not_connected',
      detail: ctx.hasMusic ? 'Control via AppleScript.' : 'Apple Music was not found on this Mac.',
    },
    {
      id: 'spotify',
      name: 'Spotify',
      category: 'music',
      status: ctx.hasSpotify ? 'connected' : 'not_connected',
      detail: ctx.hasSpotify ? 'Control via AppleScript.' : 'Spotify was not found on this Mac.',
    },
    {
      id: 'microsoft_word',
      name: 'Microsoft Word',
      category: 'developer',
      status: ctx.hasWord ? 'connected' : 'not_connected',
      detail: ctx.hasWord ? 'Document authoring is available.' : 'Microsoft Word was not found on this Mac.',
    },
    {
      id: 'chrome',
      name: 'Google Chrome',
      category: 'browser',
      status: ctx.hasChrome ? 'connected' : 'not_connected',
      detail: ctx.hasChrome ? 'Available for web control.' : 'Google Chrome was not found on this Mac.',
    },
    {
      id: 'safari',
      name: 'Safari',
      category: 'browser',
      status: 'connected',
      detail: 'Always available on macOS.',
    },
  ];
}

/** Maps a tool-registry side-effect class onto an integration status. */
export function statusForSideEffect(sideEffect: string): IntegrationStatus {
  if (sideEffect === 'destructive') return 'needs_permission';
  return 'connected';
}

export type LatencyPreference = 'fast' | 'balanced' | 'advanced';

export interface LaflySettings {
  hotkeyEnabled: boolean;
  hotkeyFallback: string;
  languages: string[];
  latencyPreference: LatencyPreference;
  confirmSensitiveActions: boolean;
  confirmDangerousActions: boolean;
  backgroundExecution: boolean;
  notificationsEnabled: boolean;
  logRetentionDays: number;
  debugMode: boolean;
}

export const DEFAULT_SETTINGS: LaflySettings = {
  hotkeyEnabled: true,
  hotkeyFallback: 'Control+Option',
  languages: ['id', 'en'],
  latencyPreference: 'balanced',
  confirmSensitiveActions: true,
  confirmDangerousActions: true,
  backgroundExecution: true,
  notificationsEnabled: true,
  logRetentionDays: 7,
  debugMode: false,
};

/**
 * User-facing settings, persisted separately from .env so the desktop app can
 * change them without the developer editing a dotfile. Secrets are never part
 * of this record.
 */
export class SettingsStore {
  private filePath: string;
  private settings: LaflySettings;

  constructor(customPath?: string) {
    const dir = path.join(os.homedir(), '.lafly');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    this.filePath = customPath || path.join(dir, 'settings.json');
    this.settings = { ...DEFAULT_SETTINGS };
    this.load();
  }

  private load(): void {
    if (!fs.existsSync(this.filePath)) return;
    try {
      const raw = JSON.parse(fs.readFileSync(this.filePath, 'utf-8')) as Partial<LaflySettings>;
      this.settings = { ...DEFAULT_SETTINGS, ...raw };
    } catch {
      this.settings = { ...DEFAULT_SETTINGS };
    }
  }

  private persist(): void {
    try {
      fs.writeFileSync(this.filePath, JSON.stringify(this.settings, null, 2), 'utf-8');
    } catch {
      // Best-effort persistence.
    }
  }

  public get(): LaflySettings {
    return { ...this.settings };
  }

  public update(patch: Partial<LaflySettings>): LaflySettings {
    this.settings = { ...this.settings, ...patch };
    this.persist();
    return this.get();
  }

  public reset(): LaflySettings {
    this.settings = { ...DEFAULT_SETTINGS };
    this.persist();
    return this.get();
  }
}

/**
 * Local account session.
 *
 * There is no identity provider behind Lafly yet, so this records local sign-in
 * state only. The token, if one is ever added, belongs in the OS keychain and
 * must never be written to disk or returned over the wire.
 */
export class AccountStore {
  private filePath: string;
  private session: AccountSession;

  constructor(customPath?: string) {
    const dir = path.join(os.homedir(), '.lafly');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    this.filePath = customPath || path.join(dir, 'account.json');
    this.session = { signedIn: false, storage: 'none' };
    this.load();
  }

  private load(): void {
    if (!fs.existsSync(this.filePath)) return;
    try {
      const raw = JSON.parse(fs.readFileSync(this.filePath, 'utf-8')) as AccountSession;
      this.session = { ...raw, storage: 'keychain' };
    } catch {
      this.session = { signedIn: false, storage: 'none' };
    }
  }

  private persist(): void {
    try {
      fs.writeFileSync(this.filePath, JSON.stringify(this.session, null, 2), 'utf-8');
    } catch {
      // Best-effort persistence.
    }
  }

  public get(): AccountSession {
    return { ...this.session };
  }

  public signIn(displayName: string): AccountSession {
    this.session = {
      signedIn: true,
      displayName: displayName.trim() || 'Local User',
      storage: 'keychain',
      updatedAt: Date.now(),
    };
    this.persist();
    return this.get();
  }

  public signOut(): AccountSession {
    this.session = { signedIn: false, storage: 'none' };
    this.persist();
    return this.get();
  }
}
