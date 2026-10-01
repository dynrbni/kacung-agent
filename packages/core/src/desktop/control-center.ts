import fs from 'fs';
import path from 'path';
import os from 'os';
import type { AccountSession, IntegrationDescriptor, IntegrationStatus } from '@lofly/types';

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

export interface LoflySettings {
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

const LATENCY_PREFERENCES: readonly LatencyPreference[] = ['fast', 'balanced', 'advanced'];

/**
 * Keeps only the fields this record declares, with the types it declares.
 *
 * A patch arrives from the network and is written straight to disk, and the
 * desktop app decodes the stored record into typed values. One write of the
 * wrong type — `logRetentionDays: "abc"`, an enum the app has never heard of —
 * would make the whole Settings screen fail to load and leave every toggle
 * silently doing nothing until the file was repaired by hand. Unknown keys are
 * dropped for the same reason: the file is a contract, not a scratchpad.
 */
export function sanitizeSettingsPatch(patch: Record<string, unknown>): Partial<LoflySettings> {
  const clean: Partial<LoflySettings> = {};

  if (typeof patch.hotkeyEnabled === 'boolean') clean.hotkeyEnabled = patch.hotkeyEnabled;
  if (typeof patch.hotkeyFallback === 'string' && patch.hotkeyFallback.trim()) {
    clean.hotkeyFallback = patch.hotkeyFallback.trim();
  }
  if (Array.isArray(patch.languages) && patch.languages.every((l) => typeof l === 'string')) {
    clean.languages = patch.languages as string[];
  }
  if (
    typeof patch.latencyPreference === 'string' &&
    (LATENCY_PREFERENCES as readonly string[]).includes(patch.latencyPreference)
  ) {
    clean.latencyPreference = patch.latencyPreference as LatencyPreference;
  }
  if (typeof patch.confirmSensitiveActions === 'boolean') {
    clean.confirmSensitiveActions = patch.confirmSensitiveActions;
  }
  if (typeof patch.confirmDangerousActions === 'boolean') {
    clean.confirmDangerousActions = patch.confirmDangerousActions;
  }
  if (typeof patch.backgroundExecution === 'boolean') {
    clean.backgroundExecution = patch.backgroundExecution;
  }
  if (typeof patch.notificationsEnabled === 'boolean') {
    clean.notificationsEnabled = patch.notificationsEnabled;
  }
  if (
    typeof patch.logRetentionDays === 'number' &&
    Number.isFinite(patch.logRetentionDays) &&
    patch.logRetentionDays > 0
  ) {
    clean.logRetentionDays = Math.floor(patch.logRetentionDays);
  }
  if (typeof patch.debugMode === 'boolean') clean.debugMode = patch.debugMode;

  return clean;
}

export const DEFAULT_SETTINGS: LoflySettings = {
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
  private settings: LoflySettings;

  constructor(customPath?: string) {
    const dir = path.join(os.homedir(), '.lofly');
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
      const raw = JSON.parse(fs.readFileSync(this.filePath, 'utf-8')) as Partial<LoflySettings>;
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

  public get(): LoflySettings {
    return { ...this.settings };
  }

  public update(patch: Partial<LoflySettings>): LoflySettings {
    // Sanitized before it can reach disk: see sanitizeSettingsPatch.
    this.settings = {
      ...this.settings,
      ...sanitizeSettingsPatch(patch as Record<string, unknown>),
    };
    this.persist();
    return this.get();
  }

  public reset(): LoflySettings {
    this.settings = { ...DEFAULT_SETTINGS };
    this.persist();
    return this.get();
  }
}

/**
 * Local account session.
 *
 * There is no identity provider behind Lofly yet, so this records local sign-in
 * state only. The token, if one is ever added, belongs in the OS keychain and
 * must never be written to disk or returned over the wire.
 */
export class AccountStore {
  private filePath: string;
  private session: AccountSession;

  constructor(customPath?: string) {
    const dir = path.join(os.homedir(), '.lofly');
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
