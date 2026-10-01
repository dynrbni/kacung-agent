import fs from 'fs';
import path from 'path';
import os from 'os';
import type { Conversation, ConversationMessage } from '@lofly/types';

/**
 * Persistent conversation history.
 *
 * The desktop app and the notch share this store, so a conversation started by
 * voice can be reopened, continued, and searched from the desktop app without
 * either surface owning its own copy.
 */
export interface ConversationStore {
  list(): Promise<Conversation[]>;
  get(id: string): Promise<Conversation | null>;
  create(title?: string): Promise<Conversation>;
  appendMessage(conversationId: string, message: Omit<ConversationMessage, 'id' | 'createdAt'>): Promise<ConversationMessage>;
  updateTitle(id: string, title: string): Promise<Conversation | null>;
  delete(id: string): Promise<boolean>;
  search(query: string): Promise<Conversation[]>;
}

const DEFAULT_TITLE = 'New Chat';
const MAX_TITLE_LENGTH = 80;

/**
 * Derives a readable title from the first user message so the sidebar is not a
 * wall of "New Chat" entries.
 */
export function deriveTitle(text: string): string {
  const cleaned = text.replace(/\s+/g, ' ').trim();
  if (!cleaned) return DEFAULT_TITLE;
  const cut = cleaned.length > MAX_TITLE_LENGTH ? `${cleaned.slice(0, MAX_TITLE_LENGTH - 1)}…` : cleaned;
  return cut;
}

export class FileConversationStore implements ConversationStore {
  private filePath: string;
  private conversations = new Map<string, Conversation>();
  private writeScheduled = false;
  private nextSeq = 1;

  constructor(customPath?: string) {
    const dir = path.join(os.homedir(), '.lofly');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    this.filePath = customPath || path.join(dir, 'conversations.json');
    this.load();
  }

  private load(): void {
    if (!fs.existsSync(this.filePath)) return;
    try {
      const raw = fs.readFileSync(this.filePath, 'utf-8');
      const list = JSON.parse(raw) as Conversation[];
      this.conversations.clear();
      let prunedAny = false;
      for (const conversation of list) {
        // Prune empty conversations (0 messages) that have the default title
        if (conversation.title === DEFAULT_TITLE && (!conversation.messages || conversation.messages.length === 0)) {
          prunedAny = true;
          continue;
        }
        // Tolerate records written before the sequence counter existed.
        this.conversations.set(conversation.id, { ...conversation, seq: conversation.seq ?? 0 });
        this.nextSeq = Math.max(this.nextSeq, (conversation.seq ?? 0) + 1);
      }
      if (prunedAny) {
        this.persist();
      }
    } catch {
      this.conversations.clear();
    }
  }

  /** Coalesces bursts of writes so a chatty run does not thrash the disk. */
  private persist(): void {
    if (this.writeScheduled) return;
    this.writeScheduled = true;
    setTimeout(() => {
      this.writeScheduled = false;
      try {
        const list = Array.from(this.conversations.values());
        fs.writeFileSync(this.filePath, JSON.stringify(list, null, 2), 'utf-8');
      } catch {
        // Persistence is best-effort; losing history must not break the agent.
      }
    }, 250).unref?.();
  }

  public async list(): Promise<Conversation[]> {
    return this.sorted();
  }

  /** Newest first, with the sequence number breaking millisecond ties. */
  private sorted(): Conversation[] {
    return Array.from(this.conversations.values()).sort(
      (a, b) => b.updatedAt - a.updatedAt || b.seq - a.seq
    );
  }

  public async get(id: string): Promise<Conversation | null> {
    return this.conversations.get(id) || null;
  }

  public async create(title: string = DEFAULT_TITLE): Promise<Conversation> {
    const now = Date.now();
    const conversation: Conversation = {
      id: `conv_${now}_${Math.random().toString(36).substring(2, 7)}`,
      title,
      createdAt: now,
      updatedAt: now,
      seq: this.nextSeq++,
      messages: [],
      taskReferences: [],
    };
    this.conversations.set(conversation.id, conversation);
    this.persist();
    return conversation;
  }

  public async appendMessage(
    conversationId: string,
    message: Omit<ConversationMessage, 'id' | 'createdAt'>
  ): Promise<ConversationMessage> {
    const conversation = this.conversations.get(conversationId);
    if (!conversation) {
      throw new Error(`Conversation "${conversationId}" not found.`);
    }

    const stored: ConversationMessage = {
      ...message,
      id: `msg_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      createdAt: Date.now(),
    };

    conversation.messages.push(stored);
    conversation.updatedAt = stored.createdAt;

    // Give a brand new conversation a meaningful title from its first message.
    if (conversation.title === DEFAULT_TITLE && message.role === 'user') {
      conversation.title = deriveTitle(message.text);
    }

    this.persist();
    return stored;
  }

  public async updateTitle(id: string, title: string): Promise<Conversation | null> {
    const conversation = this.conversations.get(id);
    if (!conversation) return null;
    conversation.title = title.trim() || DEFAULT_TITLE;
    conversation.updatedAt = Date.now();
    this.persist();
    return conversation;
  }

  public async delete(id: string): Promise<boolean> {
    const deleted = this.conversations.delete(id);
    if (deleted) this.persist();
    return deleted;
  }

  public async search(query: string): Promise<Conversation[]> {
    const q = query.toLowerCase().trim();
    if (!q) return this.list();

    const results = Array.from(this.conversations.values()).filter(
      (c) => c.title.toLowerCase().includes(q) || c.messages.some((m) => m.text.toLowerCase().includes(q))
    );
    return results.sort((a, b) => b.updatedAt - a.updatedAt || b.seq - a.seq);
  }
}
