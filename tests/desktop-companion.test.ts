import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import http from 'http';
import type { AddressInfo } from 'net';
import os from 'os';
import path from 'path';
import fs from 'fs';
import {
  FileConversationStore,
  FileMemoryStore,
  TaskManager,
  ActivityLog,
  SettingsStore,
  AccountStore,
  deriveTitle,
  humanizeToolName,
} from '@lafly/core';
import { LaflyAgentApp } from '../apps/agent/src/app.js';

// Isolated stores so tests never touch the developer's real ~/.lafly data.
function tmpPath(name: string): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'lafly-desktop-test-'));
  return path.join(dir, name);
}

function isolatedStores() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'lafly-desktop-app-'));
  return {
    conversations: new FileConversationStore(path.join(dir, 'conversations.json')),
    memory: new FileMemoryStore(path.join(dir, 'memory.json')),
    tasks: new TaskManager(),
    activity: new ActivityLog({ filePath: path.join(dir, 'activity.json') }),
    settings: new SettingsStore(path.join(dir, 'settings.json')),
    account: new AccountStore(path.join(dir, 'account.json')),
  };
}

function testConfig() {
  return {
    server: { port: 0, host: '127.0.0.1' },
    llm: {
      provider: 'mock' as const,
      model: 'test-model',
      nineRouterBaseUrl: 'http://localhost:1/v1',
      nineRouterModel: 'test',
      ollamaBaseUrl: '',
      ollamaModel: '',
    },
    stt: { provider: 'mock' as const },
    tts: { provider: 'mock' as const, voice: '', speed: 1 },
    assistant: { name: 'Lafly', wakePhrase: 'Woi Lafly', languages: ['id'], hotkeyFallback: 'Control+Option' },
    security: { confirmSensitiveActions: true, confirmDangerousActions: true },
    logging: { level: 'error' as const },
  };
}

describe('Desktop — conversation history', () => {
  let store: FileConversationStore;

  beforeEach(() => {
    store = new FileConversationStore(tmpPath('conversations.json'));
  });

  it('creates a conversation with a placeholder title', async () => {
    const conversation = await store.create();
    expect(conversation.title).toBe('New Chat');
    expect(conversation.messages).toHaveLength(0);
    expect(conversation.taskReferences).toEqual([]);
  });

  it('derives a title from the first user message', async () => {
    const conversation = await store.create();
    await store.appendMessage(conversation.id, {
      role: 'user',
      text: 'WhatsApp Reja Agung terus bilang Yuli bubur',
    });

    const reloaded = await store.get(conversation.id);
    expect(reloaded?.title).toBe('WhatsApp Reja Agung terus bilang Yuli bubur');
  });

  it('preserves the assistant message verbatim', async () => {
    const conversation = await store.create();
    await store.appendMessage(conversation.id, { role: 'user', text: 'hi' });
    await store.appendMessage(conversation.id, {
      role: 'assistant',
      text: 'Siap bos, sudah selesai.',
      taskId: 'task_1',
    });

    const reloaded = await store.get(conversation.id);
    expect(reloaded?.messages).toHaveLength(2);
    expect(reloaded?.messages[1].text).toBe('Siap bos, sudah selesai.');
    expect(reloaded?.messages[1].taskId).toBe('task_1');
  });

  it('lists newest first and searches by title and body', async () => {
    const a = await store.create();
    await store.appendMessage(a.id, { role: 'user', text: 'analisis build project' });
    const b = await store.create();
    await store.appendMessage(b.id, { role: 'user', text: 'buka spotify' });

    const list = await store.list();
    expect(list[0].id).toBe(b.id);

    expect((await store.search('spotify'))[0]?.id).toBe(b.id);
    expect((await store.search('build'))[0]?.id).toBe(a.id);
    expect(await store.search('tidak-ada-ini')).toHaveLength(0);
  });

  it('renames and deletes', async () => {
    const conversation = await store.create();
    const renamed = await store.updateTitle(conversation.id, '  Project Backsy  ');
    expect(renamed?.title).toBe('Project Backsy');

    expect(await store.delete(conversation.id)).toBe(true);
    expect(await store.delete(conversation.id)).toBe(false);
    expect(await store.get(conversation.id)).toBeNull();
  });

  it('truncates an over-long derived title', () => {
    const title = deriveTitle('word '.repeat(60));
    expect(title.length).toBeLessThanOrEqual(80);
    expect(title.endsWith('…')).toBe(true);
  });

  it('rejects appending to a conversation that does not exist', async () => {
    await expect(store.appendMessage('conv_missing', { role: 'user', text: 'x' })).rejects.toThrow();
  });
});

describe('Desktop — authoritative task state', () => {
  let tasks: TaskManager;

  beforeEach(() => {
    tasks = new TaskManager();
  });

  it('starts in planning and records steps', () => {
    tasks.start('t1', 'c1', 'Fix build');
    expect(tasks.get('t1')?.status).toBe('planning');

    tasks.addStep('t1', { id: 's1', label: 'Opened project', state: 'running', toolName: 'open_app' });
    expect(tasks.get('t1')?.status).toBe('executing');
    expect(tasks.active()?.id).toBe('t1');
  });

  it('ignores a duplicate step id from the fast router batch announcement', () => {
    tasks.start('t1', 'c1', 'Open Spotify');
    tasks.addStep('t1', { id: 'fast_open_1', label: 'Opened Spotify', state: 'running', toolName: 'open_app' });
    tasks.addStep('t1', { id: 'fast_open_1', label: 'Opened Spotify', state: 'running', toolName: 'open_app' });

    expect(tasks.get('t1')?.steps).toHaveLength(1);
  });

  it('records parallel calls to the same tool as separate steps', () => {
    tasks.start('t1', 'c1', 'Open Spotify and Safari');
    tasks.addStep('t1', { id: 'call_a', label: 'Opened Spotify', state: 'running', toolName: 'open_app' });
    tasks.addStep('t1', { id: 'call_b', label: 'Opened Safari', state: 'running', toolName: 'open_app' });

    expect(tasks.get('t1')?.steps).toHaveLength(2);

    tasks.updateStep('t1', 'call_b', 'completed');
    const steps = tasks.get('t1')!.steps;
    expect(steps.find((s) => s.id === 'call_a')?.state).toBe('running');
    expect(steps.find((s) => s.id === 'call_b')?.state).toBe('completed');
  });

  it('settles steps the runtime never explicitly ended', () => {
    tasks.start('t1', 'c1', 'Parallel batch');
    tasks.addStep('t1', { id: 'call_a', label: 'Opened Spotify', state: 'running', toolName: 'open_app' });
    tasks.addStep('t1', { id: 'call_b', label: 'Opened Safari', state: 'running', toolName: 'open_app' });

    tasks.settleOpenSteps('t1', 'completed');
    expect(tasks.get('t1')?.steps.every((s) => s.state === 'completed')).toBe(true);
  });

  it('marks a cancelled task cancelled and abandons unfinished steps', () => {
    tasks.start('t1', 'c1', 'Long task');
    tasks.addStep('t1', { id: 's1', label: 'Reading package.json', state: 'running' });
    tasks.addStep('t1', { id: 's2', label: 'Running build', state: 'pending' });

    const cancelled = tasks.cancel('t1');
    expect(cancelled?.status).toBe('cancelled');
    expect(cancelled?.steps.every((s) => s.state === 'skipped')).toBe(true);
    expect(tasks.active()).toBeNull();
  });

  it('never marks a cancelled task as completed', () => {
    tasks.start('t1', 'c1', 'x');
    tasks.cancel('t1');
    expect(['completed', 'failed']).not.toContain(tasks.get('t1')?.status);
  });

  it('notifies subscribers so both surfaces stay in sync', () => {
    const seen: string[] = [];
    const unsubscribe = tasks.subscribe((task) => seen.push(task.status));

    tasks.start('t1', 'c1', 'x');
    tasks.setStatus('t1', 'completed');
    unsubscribe();
    tasks.setStatus('t1', 'failed');

    expect(seen).toContain('planning');
    expect(seen).toContain('completed');
    expect(seen).not.toContain('failed');
  });

  it('prunes only terminal tasks past the retention window', () => {
    tasks.start('t1', 'c1', 'old done');
    tasks.setStatus('t1', 'completed');
    tasks.start('t2', 'c1', 'still running');

    tasks.prune(-1);
    expect(tasks.get('t1')).toBeNull();
    expect(tasks.get('t2')).not.toBeNull();
  });
});

describe('Desktop — activity history', () => {
  let log: ActivityLog;

  beforeEach(() => {
    log = new ActivityLog({ filePath: tmpPath('activity.json') });
  });

  it('records a simulated action as simulated, never as success', () => {
    const entry = log.record({ label: 'Sent WhatsApp message', status: 'simulated', dryRun: true });
    expect(entry.status).toBe('simulated');
    expect(entry.dryRun).toBe(true);
    expect(entry.status).not.toBe('success');
  });

  it('lists newest first', () => {
    log.record({ label: 'first', status: 'success' });
    log.record({ label: 'second', status: 'success' });
    expect(log.list()[0].label).toBe('second');
  });

  it('bounds retained history', () => {
    for (let i = 0; i < 20; i++) log.record({ label: `item-${i}`, status: 'success' });
    expect(log.list()).toHaveLength(20);
  });

  it('clears on request', () => {
    log.record({ label: 'x', status: 'success' });
    log.clear();
    expect(log.list()).toHaveLength(0);
  });
});

describe('Desktop — tool label humanisation', () => {
  it('produces short phrases rather than raw identifiers', () => {
    expect(humanizeToolName('send_whatsapp_message', { recipient: 'Reja Agung' })).toContain('Reja Agung');
    expect(humanizeToolName('open_app', { appName: 'Spotify' })).toBe('Opened Spotify');
    expect(humanizeToolName('screenshot')).toBe('Captured screen');
  });

  it('never leaks raw JSON into the label', () => {
    const label = humanizeToolName('open_app', { appName: 'Spotify', extra: { a: 1 } });
    expect(label).not.toContain('{');
  });

  it('truncates very long targets', () => {
    const label = humanizeToolName('open_app', { appName: 'x'.repeat(200) });
    expect(label.length).toBeLessThan(60);
  });
});

describe('Desktop — settings and account', () => {
  it('starts from defaults and merges a partial patch', () => {
    const settings = new SettingsStore(tmpPath('settings.json'));
    expect(settings.get()).toEqual(LaflySettingsDefaults);

    const updated = settings.update({ debugMode: true });
    expect(updated.debugMode).toBe(true);
    expect(updated.notificationsEnabled).toBe(true);

    expect(settings.reset().debugMode).toBe(false);
  });

  it('tracks local sign-in state without persisting a token', () => {
    const account = new AccountStore(tmpPath('account.json'));
    expect(account.get().signedIn).toBe(false);

    const signedIn = account.signIn('  Dyn  ');
    expect(signedIn.signedIn).toBe(true);
    expect(signedIn.displayName).toBe('Dyn');
    expect(signedIn.storage).toBe('keychain');
    expect(JSON.stringify(signedIn)).not.toMatch(/token|password|secret/i);

    expect(account.signOut().signedIn).toBe(false);
  });
});

// Mirrors LaflySettings.default on the Swift side.
const LaflySettingsDefaults = {
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

describe('Desktop — control center HTTP surface', () => {
  let app: LaflyAgentApp;
  let baseUrl: string;
  let port: number;

  beforeEach(async () => {
    app = new LaflyAgentApp({ config: testConfig(), ...isolatedStores() });

    await app.listen(0, '127.0.0.1');
    port = (app.httpServer.address() as AddressInfo).port;
    baseUrl = `http://127.0.0.1:${port}`;
  });

  afterEach(async () => {
    await app.close();
  });

  const get = async (path: string) => {
    const res = await fetch(`${baseUrl}${path}`);
    return { status: res.status, body: await res.json() };
  };

  const send = async (method: string, path: string, payload?: unknown) => {
    const res = await fetch(`${baseUrl}${path}`, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: payload === undefined ? undefined : JSON.stringify(payload),
    });
    return { status: res.status, body: await res.json() };
  };

  it('exposes health and the active agent', async () => {
    const { status, body } = await get('/health');
    expect(status).toBe(200);
    expect(body.assistant).toBe('Lafly');
  });

  it('creates, lists, loads, renames and deletes a conversation', async () => {
    const created = await send('POST', '/conversations', {});
    const id = created.body.conversation.id;

    const listed = await get('/conversations');
    expect(listed.body.conversations[0].id).toBe(id);
    // The sidebar payload must stay small.
    expect(listed.body.conversations[0]).not.toHaveProperty('messages');

    const loaded = await get(`/conversations/${id}`);
    expect(loaded.body.conversation.id).toBe(id);

    const renamed = await send('PATCH', `/conversations/${id}`, { title: 'Project Backsy' });
    expect(renamed.body.conversation.title).toBe('Project Backsy');

    expect((await send('DELETE', `/conversations/${id}`)).body.success).toBe(true);
    expect((await get(`/conversations/${id}`)).status).toBe(404);
  });

  it('returns 404 for an unknown conversation', async () => {
    expect((await get('/conversations/conv_nope')).status).toBe(404);
  });

  it('reports tasks and an empty active task initially', async () => {
    const { status, body } = await get('/tasks');
    expect(status).toBe(200);
    expect(Array.isArray(body.tasks)).toBe(true);
  });

  it('lists, edits and deletes memory', async () => {
    const created = await send('POST', '/memory', { category: 'project', content: 'Backsy is in ~/Projects/Backsy' });
    const id = created.body.memory.id;
    expect(created.body.memory.category).toBe('project');

    const listed = await get('/memory');
    expect(listed.body.memory).toHaveLength(1);

    const edited = await send('PATCH', `/memory/${id}`, { content: 'Backsy moved' });
    expect(edited.body.memory.content).toBe('Backsy moved');

    expect((await send('DELETE', `/memory/${id}`)).body.success).toBe(true);
  });

  it('rejects memory without content', async () => {
    expect((await send('POST', '/memory', { category: 'fact' })).status).toBe(400);
  });

  it('lists and clears activity', async () => {
    expect((await get('/activity')).status).toBe(200);
    expect((await send('DELETE', '/activity')).body.success).toBe(true);
  });

  it('reports integrations without exposing a credential value', async () => {
    const { body } = await get('/integrations');
    expect(body.integrations.length).toBeGreaterThan(0);

    const serialized = JSON.stringify(body);

    // Guidance may name the setting to configure, but no credential value may
    // appear in the payload.
    expect(serialized).not.toMatch(/sk-[A-Za-z0-9]{16,}/);
    expect(serialized).not.toMatch(/AIza[0-9A-Za-z_-]{20,}/);
    expect(serialized).not.toMatch(/Bearer\s+\S/);

    // Only the documented fields are exposed, never a raw config dump.
    for (const item of body.integrations) {
      expect(Object.keys(item).sort()).toEqual(['category', 'detail', 'id', 'name', 'status']);
    }
  });

  it('reads and updates settings', async () => {
    const initial = await get('/settings');
    expect(initial.body.settings.hotkeyEnabled).toBe(true);

    const updated = await send('PATCH', '/settings', { debugMode: true });
    expect(updated.body.settings.debugMode).toBe(true);
  });

  it('manages the local account session', async () => {
    expect((await get('/account')).body.account.signedIn).toBe(false);
    const signedIn = await send('POST', '/account/sign-in', { displayName: 'Dyn' });
    expect(signedIn.body.account.signedIn).toBe(true);
    expect((await send('POST', '/account/sign-out', {})).body.account.signedIn).toBe(false);
  });
});

describe('Desktop — shares one agent and cannot bypass safety', () => {
  let app: LaflyAgentApp;
  let baseUrl: string;

  beforeEach(async () => {
    app = new LaflyAgentApp({ config: testConfig(), ...isolatedStores() });
    await app.listen(0, '127.0.0.1');
    baseUrl = `http://127.0.0.1:${(app.httpServer.address() as AddressInfo).port}`;
  });

  afterEach(async () => {
    await app.close();
  });

  it('routes a desktop chat through the same runtime and stays in dry run', async () => {
    const res = await fetch(`${baseUrl}/query`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: 'WhatsApp Reja Agung terus bilang Yuli bubur' }),
    });
    const body = await res.json();

    // Same agent runtime as voice: the call is planned and executed.
    expect(body.taskId).toMatch(/^task_/);
    expect(body.completed).toBe(true);

    const call = body.steps[0].toolResults[0];
    expect(call.name).toBe('send_whatsapp_message');
    expect(call.parameters.recipient).toBe('Reja Agung');
    expect(call.parameters.message).toBe('Yuli bubur');

    // The desktop surface cannot bypass the safety policy.
    expect(call.result.metadata.executed).toBe(false);
    expect(call.result.metadata.dryRun).toBe(true);
    expect(call.result.data.sent).toBe(false);
  });

  it('records the simulated action in activity as simulated', async () => {
    await fetch(`${baseUrl}/query`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: 'WhatsApp Reja Agung terus bilang Yuli bubur' }),
    });

    const activity = await (await fetch(`${baseUrl}/activity`)).json();
    const entry = activity.activity.find((a: { toolName?: string }) => a.toolName === 'send_whatsapp_message');

    expect(entry).toBeDefined();
    expect(entry.status).toBe('simulated');
    expect(entry.dryRun).toBe(true);
  });

  it('persists a desktop chat into shared conversation history', async () => {
    await fetch(`${baseUrl}/query`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: 'Buka Spotify' }),
    });

    const conversations = await (await fetch(`${baseUrl}/conversations`)).json();
    expect(conversations.conversations.length).toBeGreaterThan(0);
    expect(conversations.activeConversationId).toBeTruthy();
  });

  it('leaves no step stuck running after a run finishes', async () => {
    await fetch(`${baseUrl}/query`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: 'Buka Spotify terus buka Safari' }),
    });

    const tasks = await (await fetch(`${baseUrl}/tasks`)).json();
    const stuck = tasks.tasks.flatMap((t: { steps: Array<{ state: string }> }) =>
      t.steps.filter((s) => s.state === 'running')
    );
    expect(stuck).toHaveLength(0);
  });
});
