import { describe, it, expect } from 'vitest';
import path from 'path';
import os from 'os';
import fs from 'fs';
import { FileMemoryStore } from './store.js';

describe('FileMemoryStore', () => {
  it('saves, searches, and deletes memories', async () => {
    const testFile = path.join(os.tmpdir(), `lofly-mem-${Date.now()}.json`);
    const store = new FileMemoryStore(testFile);

    const item = await store.save({
      category: 'preference',
      content: 'User prefers VS Code for coding',
    });

    expect(item.id).toBeDefined();
    expect(item.content).toBe('User prefers VS Code for coding');

    const searchRes = await store.search('VS Code');
    expect(searchRes.length).toBe(1);
    expect(searchRes[0].id).toBe(item.id);

    const deleted = await store.delete(item.id);
    expect(deleted).toBe(true);

    const searchAfter = await store.search('VS Code');
    expect(searchAfter.length).toBe(0);

    // Cleanup
    if (fs.existsSync(testFile)) {
      fs.unlinkSync(testFile);
    }
  });
});
