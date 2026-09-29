/**
 * Kacung — Core Types & Contracts
 */

// ============================================================================
// Assistant States & Lifecycle
// ============================================================================

export type AssistantState =
  | 'idle'
  | 'listening'
  | 'thinking'
  | 'executing'
  | 'speaking'
  | 'error';

export interface StateChangeEvent {
  previousState: AssistantState;
  newState: AssistantState;
  timestamp: number;
  metadata?: Record<string, unknown>;
}

// ============================================================================
// Security & Permission Levels
// ============================================================================

/**
 * SAFE: Read-only operations, screenshots, searches, safe app opening.
 * SENSITIVE: File modifications, standard terminal commands, message sending.
 * DANGEROUS: System configuration, file deletions, destructive terminal commands.
 */
export const PermissionLevel = {
  SAFE: 'SAFE',
  SENSITIVE: 'SENSITIVE',
  DANGEROUS: 'DANGEROUS',
} as const;

export type PermissionLevel = (typeof PermissionLevel)[keyof typeof PermissionLevel];

export type Tool<TArgs = unknown, TResult = unknown> = {
  name: string;
  description: string;
  inputSchema: unknown;
  permission: PermissionLevel;
  execute(args: TArgs): Promise<ToolResult<TResult>>;
};

export interface ConfirmationRequest {
  id: string;
  toolName: string;
  parameters: Record<string, unknown>;
  permissionLevel: PermissionLevel;
  description: string;
  timestamp: number;
}

export interface ConfirmationResponse {
  id: string;
  approved: boolean;
  reason?: string;
  timestamp: number;
}

// ============================================================================
// Tool System Definitions
// ============================================================================

export type JSONSchemaType = 'string' | 'number' | 'integer' | 'boolean' | 'object' | 'array' | 'null';

export interface ToolParameterProperty {
  type: JSONSchemaType;
  description: string;
  enum?: string[];
  default?: unknown;
  items?: ToolParameterProperty;
}

export interface ToolParametersSchema {
  type: 'object';
  properties: Record<string, ToolParameterProperty>;
  required?: string[];
}

export interface ToolDefinition<TParams = Record<string, unknown>, TResult = unknown> {
  name: string;
  description: string;
  parameters: ToolParametersSchema;
  permissionLevel: PermissionLevel;
  execute: (params: TParams, context: ToolExecutionContext) => Promise<ToolResult<TResult>>;
  validate?: (params: unknown) => { valid: boolean; error?: string };
}

export interface ToolExecutionContext {
  requestId: string;
  requestConfirmation?: (req: Omit<ConfirmationRequest, 'id' | 'timestamp'>) => Promise<boolean>;
  logger: Logger;
}

export interface ToolCallRequest {
  id: string;
  name: string;
  parameters: Record<string, unknown>;
}

export interface ToolResult<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  metadata?: Record<string, unknown>;
}

export interface ExecutedToolCall {
  id: string;
  name: string;
  parameters: Record<string, unknown>;
  result: ToolResult;
  durationMs: number;
}

// ============================================================================
// Agent & Conversation
// ============================================================================

export type MessageRole = 'system' | 'user' | 'assistant' | 'tool';

export interface ChatMessageToolCall {
  id: string;
  type: 'function';
  function: {
    name: string;
    arguments: string; // JSON encoded string
  };
}

export interface ChatMessage {
  role: MessageRole;
  content: string | null;
  name?: string;
  tool_call_id?: string;
  tool_calls?: ChatMessageToolCall[];
}

export interface AgentStep {
  stepIndex: number;
  thought?: string;
  toolCalls?: ToolCallRequest[];
  toolResults?: ExecutedToolCall[];
  response?: string;
}

export interface AgentRunOptions {
  maxSteps?: number;
  temperature?: number;
  context?: Record<string, unknown>;
}

export interface AgentRunResult {
  text: string;
  steps: AgentStep[];
  completed: boolean;
  error?: string;
}

// ============================================================================
// Provider Interfaces
// ============================================================================

export interface LLMCompletionOptions {
  messages: ChatMessage[];
  tools?: ToolDefinition[];
  temperature?: number;
  maxTokens?: number;
}

export interface LLMCompletionResponse {
  content: string | null;
  toolCalls?: ToolCallRequest[];
  rawResponse?: unknown;
}

export interface LLMProvider {
  name: string;
  complete: (options: LLMCompletionOptions) => Promise<LLMCompletionResponse>;
}

export interface STTOptions {
  language?: string; // e.g. "id-ID" or "en-US"
  sampleRate?: number;
}

export interface STTResult {
  text: string;
  confidence?: number;
  language?: string;
}

export interface SpeechToTextProvider {
  name: string;
  transcribe: (audioBuffer: Buffer | ArrayBuffer, options?: STTOptions) => Promise<STTResult>;
}

export interface TTSOptions {
  voice?: string;
  language?: string;
  speed?: number;
}

export interface TextToSpeechProvider {
  name: string;
  synthesize: (text: string, options?: TTSOptions) => Promise<Buffer | null>;
  speak?: (text: string, options?: TTSOptions) => Promise<void>;
}

export interface WakeWordDetector {
  name: string;
  start: (onWake: () => void) => Promise<void> | void;
  stop: () => Promise<void> | void;
  isListening: () => boolean;
}

// ============================================================================
// Memory & Persistence
// ============================================================================

export interface MemoryItem {
  id: string;
  category: 'preference' | 'fact' | 'project' | 'instruction';
  content: string;
  createdAt: number;
  updatedAt: number;
  metadata?: Record<string, unknown>;
}

export interface MemoryStore {
  save: (item: Omit<MemoryItem, 'id' | 'createdAt' | 'updatedAt'>) => Promise<MemoryItem>;
  get: (id: string) => Promise<MemoryItem | null>;
  search: (query: string, category?: string) => Promise<MemoryItem[]>;
  delete: (id: string) => Promise<boolean>;
  list: () => Promise<MemoryItem[]>;
}

// ============================================================================
// Logging
// ============================================================================

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export interface Logger {
  debug: (message: string, meta?: Record<string, unknown>) => void;
  info: (message: string, meta?: Record<string, unknown>) => void;
  warn: (message: string, meta?: Record<string, unknown>) => void;
  error: (message: string, meta?: Record<string, unknown>) => void;
}

// ============================================================================
// Real-time Event Stream (WebSocket / IPC)
// ============================================================================

export type AssistantEventType =
  | 'state_change'
  | 'wake_word'
  | 'transcription'
  | 'thought'
  | 'tool_start'
  | 'tool_end'
  | 'confirmation_required'
  | 'confirmation_received'
  | 'speech_start'
  | 'speech_end'
  | 'error';

export interface AssistantEvent<T = unknown> {
  type: AssistantEventType;
  payload: T;
  timestamp: number;
}
