import fs from 'fs';
import path from 'path';
import os from 'os';
import type { MemoryItem, MemoryStore } from '@lofly/types';

export class FileMemoryStore implements MemoryStore {
  private filePath: string;
  private items = new Map<string, MemoryItem>();

  constructor(customPath?: string) {
    const dir = path.join(os.homedir(), '.lofly');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    this.filePath = customPath || path.join(dir, 'memory.json');
    this.load();
  }

  private load(): void {
    if (fs.existsSync(this.filePath)) {
      try {
        const raw = fs.readFileSync(this.filePath, 'utf-8');
        const list = JSON.parse(raw) as MemoryItem[];
        this.items.clear();
        for (const item of list) {
          this.items.set(item.id, item);
        }
      } catch {
        this.items.clear();
      }
    }
  }

  private persist(): void {
    try {
      const list = Array.from(this.items.values());
      fs.writeFileSync(this.filePath, JSON.stringify(list, null, 2), 'utf-8');
    } catch {
      // Ignore write errors in memory persistence
    }
  }

  public async save(item: Omit<MemoryItem, 'id' | 'createdAt' | 'updatedAt'>): Promise<MemoryItem> {
    const id = `mem_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const now = Date.now();
    const fullItem: MemoryItem = {
      ...item,
      id,
      createdAt: now,
      updatedAt: now,
    };
    this.items.set(id, fullItem);
    this.persist();
    return fullItem;
  }

  public async get(id: string): Promise<MemoryItem | null> {
    return this.items.get(id) || null;
  }

  public async search(query: string, category?: string): Promise<MemoryItem[]> {
    const q = query.toLowerCase();
    return Array.from(this.items.values()).filter((item) => {
      if (category && item.category !== category) return false;
      return item.content.toLowerCase().includes(q);
    });
  }

  /**
   * Edits an item in place. The id and createdAt are preserved so references
   * held elsewhere stay valid across an edit.
   */
  public async update(
    id: string,
    patch: Partial<Pick<MemoryItem, 'content' | 'category' | 'metadata'>>
  ): Promise<MemoryItem | null> {
    const existing = this.items.get(id);
    if (!existing) return null;

    const updated: MemoryItem = {
      ...existing,
      ...patch,
      id: existing.id,
      createdAt: existing.createdAt,
      updatedAt: Date.now(),
    };
    this.items.set(id, updated);
    this.persist();
    return updated;
  }

  public async delete(id: string): Promise<boolean> {
    const existed = this.items.delete(id);
    if (existed) {
      this.persist();
    }
    return existed;
  }

  public async list(): Promise<MemoryItem[]> {
    return Array.from(this.items.values());
  }
}
