import type { ExecutionPolicy, Logger, WhatsAppContact, WhatsAppMessageResult } from '@lafly/types';
import { getExecutionPolicy } from '../safety/policy.js';
import { LiveWhatsAppExecutor, MockWhatsAppExecutor } from './executor.js';

/**
 * Policy-aware entry point for every WhatsApp action.
 *
 * The facade owns no behaviour of its own: it selects an executor from the
 * resolved execution policy and forwards to it, so the live and simulated paths
 * stay structurally identical and cannot drift apart.
 */
export class WhatsAppController {
  private logger?: Logger;
  private policy: ExecutionPolicy;

  constructor(logger?: Logger, policy?: ExecutionPolicy) {
    this.logger = logger;
    this.policy = policy ?? getExecutionPolicy();
  }

  private get executor(): LiveWhatsAppExecutor | MockWhatsAppExecutor {
    return this.policy.mode === 'live'
      ? new LiveWhatsAppExecutor(this.logger)
      : new MockWhatsAppExecutor(this.logger);
  }

  public isLive(): boolean {
    return this.policy.mode === 'live';
  }

  public openWhatsApp(): Promise<{ target: 'app' | 'web'; message: string }> {
    return this.executor.openWhatsApp();
  }

  public searchContact(contactName: string): Promise<{ success: boolean; message: string }> {
    return this.executor.searchContact(contactName);
  }

  public openChat(contact: string, phone?: string): Promise<{ success: boolean; message: string }> {
    return this.executor.openChat(contact, phone);
  }

  public sendMessage(contactName: string, text: string): Promise<WhatsAppMessageResult> {
    return this.executor.sendMessage(contactName, text);
  }

  /**
   * Pure name resolution against a known contact book — no I/O, so it is safe
   * in every mode.
   */
  public resolveContact(
    query: string,
    knownContacts: WhatsAppContact[] = []
  ): { exactMatch?: WhatsAppContact; candidates: WhatsAppContact[] } {
    return new LiveWhatsAppExecutor(this.logger).resolveContact(query, knownContacts);
  }
}
