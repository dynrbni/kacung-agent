import fs from 'fs';
import path from 'path';
import os from 'os';
import type {
  ActivityEntry,
  ActivityStatus,
  TaskSnapshot,
  TaskStatus,
  TaskStep,
} from '@lafly/types';
import { ACTIVE_TASK_STATUSES, TERMINAL_TASK_STATUSES } from '@lafly/types';

/**
 * Authoritative task state.
 *
 * The notch and the desktop app both render whatever this reports, so a task
 * cannot look "executing" in one surface and "idle" in the other.
 */
export class TaskManager {
  private tasks = new Map<string, TaskSnapshot>();
  private listeners = new Set<(task: TaskSnapshot) => void>();

  public subscribe(listener: (task: TaskSnapshot) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private emit(task: TaskSnapshot): void {
    for (const listener of this.listeners) {
      try {
        listener(task);
      } catch {
        // A broken listener must not take down task tracking.
      }
    }
  }

  public start(id: string, conversationId: string, title: string): TaskSnapshot {
    const now = Date.now();
    const task: TaskSnapshot = {
      id,
      conversationId,
      title,
      status: 'planning',
      steps: [],
      createdAt: now,
      updatedAt: now,
    };
    this.tasks.set(id, task);
    this.emit(task);
    return task;
  }

  public setStatus(id: string, status: TaskStatus): TaskSnapshot | null {
    const task = this.tasks.get(id);
    if (!task) return null;
    task.status = status;
    task.updatedAt = Date.now();
    this.emit(task);
    return task;
  }

  /**
   * Records one high-level step, keyed by the tool call id so a start and its
   * matching end always land on the same step.
   *
   * Ids can legitimately repeat: the fast router announces a batch and then the
   * first call again with the same id, so a duplicate id is ignored rather than
   * producing a phantom in-flight step.
   */
  public addStep(id: string, step: TaskStep): TaskSnapshot | null {
    const task = this.tasks.get(id);
    if (!task) return null;

    if (task.steps.some((s) => s.id === step.id)) {
      return task;
    }

    task.steps.push(step);
    task.status = 'executing';
    task.updatedAt = Date.now();
    this.emit(task);
    return task;
  }

  /**
   * Closes out any step still marked running once a run finishes. Guarantees the
   * task panel never shows phantom in-flight work after the agent is done.
   */
  public settleOpenSteps(id: string, outcome: 'completed' | 'failed' | 'cancelled'): TaskSnapshot | null {
    const task = this.tasks.get(id);
    if (!task) return null;

    let changed = false;
    for (const step of task.steps) {
      if (step.state === 'running' || step.state === 'pending') {
        step.state = outcome === 'completed' ? 'completed' : outcome;
        changed = true;
      }
    }
    if (changed) {
      task.updatedAt = Date.now();
      this.emit(task);
    }
    return task;
  }

  public updateStep(id: string, stepId: string, state: TaskStep['state'], error?: string): TaskSnapshot | null {
    const task = this.tasks.get(id);
    if (!task) return null;
    const step = task.steps.find((s) => s.id === stepId);
    if (!step) return null;
    step.state = state;
    if (error) step.error = error;
    task.updatedAt = Date.now();
    this.emit(task);
    return task;
  }

  public get(id: string): TaskSnapshot | null {
    return this.tasks.get(id) || null;
  }

  public list(): TaskSnapshot[] {
    return Array.from(this.tasks.values()).sort((a, b) => b.createdAt - a.createdAt);
  }

  /** The most recent task that has not reached a terminal state. */
  public active(): TaskSnapshot | null {
    return this.list().find((t) => ACTIVE_TASK_STATUSES.includes(t.status)) || null;
  }

  public cancel(id: string): TaskSnapshot | null {
    const task = this.tasks.get(id);
    if (!task) return null;
    // Anything not finished is abandoned rather than marked complete, so the
    // UI never claims work succeeded that was actually stopped.
    for (const step of task.steps) {
      if (step.state === 'running' || step.state === 'pending') {
        step.state = 'skipped';
      }
    }
    task.status = 'cancelled';
    task.updatedAt = Date.now();
    this.emit(task);
    return task;
  }

  /** Drops terminal tasks older than the retention window. */
  public prune(maxAgeMs = 24 * 60 * 60 * 1000): number {
    const cutoff = Date.now() - maxAgeMs;
    let removed = 0;
    for (const [id, task] of this.tasks) {
      if (TERMINAL_TASK_STATUSES.includes(task.status) && task.updatedAt < cutoff) {
        this.tasks.delete(id);
        removed++;
      }
    }
    return removed;
  }
}

/**
 * Append-only activity history.
 *
 * Records what actually happened, including whether the execution policy
 * simulated the action. A simulated entry is never stored as a success.
 */
export class ActivityLog {
  private entries: ActivityEntry[] = [];
  private filePath: string;
  private maxEntries: number;

  constructor(options: { filePath?: string; maxEntries?: number } = {}) {
    const dir = path.join(os.homedir(), '.lafly');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    this.filePath = options.filePath || path.join(dir, 'activity.json');
    this.maxEntries = options.maxEntries ?? 500;
    this.load();
  }

  private load(): void {
    if (!fs.existsSync(this.filePath)) return;
    try {
      const raw = fs.readFileSync(this.filePath, 'utf-8');
      const list = JSON.parse(raw) as ActivityEntry[];
      this.entries = list.slice(-this.maxEntries);
    } catch {
      this.entries = [];
    }
  }

  private persist(): void {
    try {
      fs.writeFileSync(this.filePath, JSON.stringify(this.entries, null, 2), 'utf-8');
    } catch {
      // Best-effort; never let logging break a tool run.
    }
  }

  public record(entry: {
    label: string;
    status: ActivityStatus;
    toolName?: string;
    taskId?: string;
    conversationId?: string;
    detail?: string;
    dryRun?: boolean;
  }): ActivityEntry {
    const stored: ActivityEntry = {
      id: `act_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      timestamp: Date.now(),
      label: entry.label,
      toolName: entry.toolName,
      taskId: entry.taskId,
      conversationId: entry.conversationId,
      detail: entry.detail,
      status: entry.status,
      dryRun: entry.dryRun ?? false,
    };
    this.entries.push(stored);
    if (this.entries.length > this.maxEntries) {
      this.entries = this.entries.slice(-this.maxEntries);
    }
    this.persist();
    return stored;
  }

  public list(options: { limit?: number; since?: number } = {}): ActivityEntry[] {
    let result = this.entries;
    if (options.since) {
      result = result.filter((e) => e.timestamp >= (options.since as number));
    }
    // Newest first is what the Activity screen renders.
    return result.slice().reverse().slice(0, options.limit ?? this.maxEntries);
  }

  public clear(): void {
    this.entries = [];
    this.persist();
  }
}

/**
 * Turns a tool name into a short human phrase. The desktop app shows this
 * instead of raw identifiers, keeping tool noise out of the normal UI.
 */
export function humanizeToolName(toolName: string, parameters: Record<string, unknown> = {}): string {
  const target =
    (parameters.appName as string) ??
    (parameters.query as string) ??
    (parameters.recipient as string) ??
    (parameters.contact as string) ??
    (parameters.path as string) ??
    (parameters.name as string) ??
    (parameters.url as string) ??
    (parameters.command as string) ??
    '';

  const label = target ? ` ${truncate(String(target), 40)}` : '';

  switch (toolName) {
    case 'open_app':
      return `Opened${label || ' application'}`;
    case 'close_app':
      return `Closed${label || ' application'}`;
    case 'focus_app':
      return `Focused${label || ' application'}`;
    case 'screenshot':
    case 'screenshot_app':
      return 'Captured screen';
    case 'send_whatsapp_message':
      return `Sent WhatsApp message${label ? ` to ${truncate(String(target), 24)}` : ''}`;
    case 'open_whatsapp_chat':
      return `Opened WhatsApp chat${label}`;
    case 'search_whatsapp_contact':
      return `Searched WhatsApp contact${label}`;
    case 'play_music':
    case 'search_music':
      return `Played${label}`;
    case 'set_volume':
      return 'Changed volume';
    case 'run_command':
      return `Ran shell command${label}`;
    case 'write_file':
      return `Wrote file${label}`;
    case 'read_file':
      return `Read file${label}`;
    case 'delete_file':
      return `Deleted file${label}`;
    case 'web_search':
      return `Searched the web${label}`;
    case 'open_url':
      return `Opened link${label}`;
    case 'write_word_document':
      return 'Wrote a Word document';
    case 'type_text':
      return 'Typed text';
    case 'press_key':
      return 'Pressed a key';
    default:
      return toolName.replace(/_/g, ' ').replace(/^\w/, (c) => c.toUpperCase());
  }
}

function truncate(value: string, max: number): string {
  return value.length > max ? `${value.slice(0, max - 1)}…` : value;
}
