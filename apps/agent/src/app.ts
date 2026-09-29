import http from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import type {
  AssistantEvent,
  ConfirmationRequest,
  ConfirmationResponse,
  LLMProvider,
  TextToSpeechProvider,
} from '@kacung/types';
import { getConfig, type KacungConfig } from '@kacung/config';
import { ToolExecutor } from '@kacung/tools';
import {
  AgentRuntime,
  StructuredLogger,
  NineRouterProvider,
  GeminiLLMProvider,
  OpenAILLMProvider,
  MockLLMProvider,
  MacOSSayTTSProvider,
  MockTTSProvider,
} from '@kacung/core';

export interface KacungAppOptions {
  config?: KacungConfig;
  llmProvider?: LLMProvider;
  ttsProvider?: TextToSpeechProvider;
}

export class KacungAgentApp {
  public config: KacungConfig;
  public logger: StructuredLogger;
  public runtime: AgentRuntime;
  public executor: ToolExecutor;
  public httpServer: http.Server;
  public wss: WebSocketServer;

  private pendingConfirmations = new Map<
    string,
    {
      request: ConfirmationRequest;
      resolve: (approved: boolean) => void;
      timeoutId: NodeJS.Timeout;
    }
  >();

  constructor(options: KacungAppOptions = {}) {
    this.config = options.config || getConfig();
    this.logger = new StructuredLogger(this.config.logging.level, 'AgentServer');

    // 1. Configure LLM Provider
    const llmProvider = options.llmProvider || this.resolveLLMProvider();

    // 2. Configure TTS Provider
    const ttsProvider = options.ttsProvider || this.resolveTTSProvider();

    // 3. Configure Tool Executor with Confirmation Hook
    this.executor = new ToolExecutor({
      logger: this.logger,
      confirmSensitive: this.config.security.confirmSensitiveActions,
      confirmDangerous: this.config.security.confirmDangerousActions,
      requestConfirmation: (req) => this.handleConfirmationRequest(req),
    });

    // 4. Configure Agent Runtime (restricted to Milestone 1 initial tools)
    this.runtime = new AgentRuntime({
      llmProvider,
      toolExecutor: this.executor,
      ttsProvider,
      logger: this.logger,
      assistantName: this.config.assistant.name,
      allowedToolNames: ['open_app', 'close_app', 'screenshot'],
    });

    // 5. Create HTTP & WebSocket Servers
    this.httpServer = http.createServer((req, res) => this.handleHttpRequest(req, res));
    this.wss = new WebSocketServer({ server: this.httpServer, path: '/ws' });

    this.setupWebSocket();
    this.setupRuntimeEvents();
  }

  private resolveLLMProvider(): LLMProvider {
    const {
      provider,
      model,
      nineRouterBaseUrl,
      nineRouterApiKey,
      nineRouterModel,
      geminiApiKey,
      openAiApiKey,
      ollamaBaseUrl,
    } = this.config.llm;

    if (
      provider === 'ninerouter' ||
      (nineRouterBaseUrl && provider !== 'gemini' && provider !== 'openai' && provider !== 'ollama')
    ) {
      const activeModel = nineRouterModel || model || 'ag/gemini-3.8-flash-high';
      this.logger.info(`Using 9Router LLM Provider at ${nineRouterBaseUrl} (model: ${activeModel})`);
      return new NineRouterProvider({
        baseUrl: nineRouterBaseUrl,
        apiKey: nineRouterApiKey,
        model: activeModel,
        logger: this.logger,
      });
    }

    if (provider === 'gemini' && geminiApiKey) {
      this.logger.info(`Using Gemini LLM Provider (model: ${model})`);
      return new GeminiLLMProvider({ apiKey: geminiApiKey, model });
    }

    if (provider === 'openai' && openAiApiKey) {
      this.logger.info(`Using OpenAI LLM Provider (model: ${model})`);
      return new OpenAILLMProvider({ apiKey: openAiApiKey, model });
    }

    if (provider === 'ollama') {
      this.logger.info(`Using Ollama LLM Provider at ${ollamaBaseUrl}`);
      return new OpenAILLMProvider({
        baseUrl: `${ollamaBaseUrl}/v1`,
        model: this.config.llm.ollamaModel,
      });
    }

    this.logger.warn('No LLM API key configured. Falling back to MockLLMProvider for offline execution.');
    return new MockLLMProvider();
  }

  private resolveTTSProvider(): TextToSpeechProvider {
    if (this.config.tts.provider === 'macos') {
      return new MacOSSayTTSProvider({
        defaultVoice: this.config.tts.voice,
        defaultSpeed: this.config.tts.speed,
      });
    }
    return new MockTTSProvider();
  }

  private handleConfirmationRequest(
    req: Omit<ConfirmationRequest, 'id' | 'timestamp'>
  ): Promise<boolean> {
    const id = `conf_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    const fullRequest: ConfirmationRequest = {
      ...req,
      id,
      timestamp: Date.now(),
    };

    return new Promise<boolean>((resolve) => {
      // Auto-timeout after 60 seconds -> denies by default
      const timeoutId = setTimeout(() => {
        if (this.pendingConfirmations.has(id)) {
          this.logger.warn(`Confirmation request timed out: ${id}`);
          this.pendingConfirmations.delete(id);
          resolve(false);
        }
      }, 60_000);

      this.pendingConfirmations.set(id, {
        request: fullRequest,
        resolve,
        timeoutId,
      });

      // Broadcast confirmation request to all connected UI clients
      this.broadcast({
        type: 'confirmation_required',
        payload: fullRequest,
        timestamp: Date.now(),
      });
    });
  }

  public resolveConfirmation(response: ConfirmationResponse): boolean {
    const pending = this.pendingConfirmations.get(response.id);
    if (!pending) {
      return false;
    }

    clearTimeout(pending.timeoutId);
    this.pendingConfirmations.delete(response.id);
    pending.resolve(response.approved);

    this.broadcast({
      type: 'confirmation_received',
      payload: response,
      timestamp: Date.now(),
    });

    return true;
  }

  private setupRuntimeEvents(): void {
    this.runtime.onEvent((event) => {
      this.broadcast(event);
    });
  }

  private setupWebSocket(): void {
    this.wss.on('connection', (ws: WebSocket) => {
      this.logger.info('WebSocket client connected');

      // Send initial handshake state
      ws.send(
        JSON.stringify({
          type: 'state_change',
          payload: {
            previousState: 'idle',
            newState: this.runtime.getState(),
          },
          timestamp: Date.now(),
        })
      );

      ws.on('message', async (data) => {
        try {
          const msg = JSON.parse(data.toString());
          await this.handleClientMessage(msg, ws);
        } catch (err) {
          this.logger.error('Failed to parse WebSocket message', { error: String(err) });
        }
      });

      ws.on('close', () => {
        this.logger.info('WebSocket client disconnected');
      });
    });
  }

  public broadcast(event: AssistantEvent): void {
    const data = JSON.stringify(event);
    for (const client of this.wss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data);
      }
    }
  }

  private async handleClientMessage(msg: Record<string, unknown>, ws: WebSocket): Promise<void> {
    if (msg.type === 'query' && typeof msg.text === 'string') {
      const result = await this.runtime.run(msg.text);
      ws.send(JSON.stringify({ type: 'query_result', payload: result, timestamp: Date.now() }));
    } else if (msg.type === 'confirm' && typeof msg.id === 'string' && typeof msg.approved === 'boolean') {
      const resolved = this.resolveConfirmation({
        id: msg.id,
        approved: msg.approved,
        reason: typeof msg.reason === 'string' ? msg.reason : undefined,
        timestamp: Date.now(),
      });
      ws.send(JSON.stringify({ type: 'confirm_ack', payload: { id: msg.id, resolved }, timestamp: Date.now() }));
    } else if (msg.type === 'wake') {
      this.runtime.setState('listening');
    } else if (msg.type === 'reset') {
      this.runtime.resetConversation();
      this.runtime.setState('idle');
    }
  }

  private async handleHttpRequest(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
    // CORS headers for local UI
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }

    const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
    const pathname = url.pathname;

    // Helper to send JSON
    const sendJson = (statusCode: number, data: unknown) => {
      res.writeHead(statusCode, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(data));
    };

    // 1. GET /health
    if (req.method === 'GET' && pathname === '/health') {
      sendJson(200, {
        status: 'ok',
        assistant: this.config.assistant.name,
        state: this.runtime.getState(),
        timestamp: Date.now(),
      });
      return;
    }

    // 2. GET /state
    if (req.method === 'GET' && pathname === '/state') {
      sendJson(200, {
        state: this.runtime.getState(),
        pendingConfirmations: Array.from(this.pendingConfirmations.values()).map((p) => p.request),
      });
      return;
    }

    // 3. GET /config
    if (req.method === 'GET' && pathname === '/config') {
      sendJson(200, {
        assistant: this.config.assistant,
        security: this.config.security,
        tools: this.executor.getRegistry().list().map((t) => ({
          name: t.name,
          description: t.description,
          permissionLevel: t.permissionLevel,
        })),
      });
      return;
    }

    // Helper to read JSON body
    const readBody = async (): Promise<Record<string, unknown>> => {
      return new Promise((resolve, reject) => {
        let body = '';
        req.on('data', (chunk) => {
          body += chunk.toString();
        });
        req.on('end', () => {
          try {
            resolve(body ? JSON.parse(body) : {});
          } catch (err) {
            reject(err);
          }
        });
        req.on('error', reject);
      });
    };

    // 4. POST /query
    if (req.method === 'POST' && pathname === '/query') {
      try {
        const body = await readBody();
        const text = typeof body.text === 'string' ? body.text : '';
        if (!text.trim()) {
          sendJson(400, { error: 'Missing or empty "text" parameter in query request.' });
          return;
        }

        const result = await this.runtime.handleTranscript(text);
        sendJson(200, result);
      } catch (err) {
        sendJson(500, { error: String(err) });
      }
      return;
    }

    // 5. POST /confirm
    if (req.method === 'POST' && pathname === '/confirm') {
      try {
        const body = await readBody();
        const id = String(body.id || '');
        const approved = Boolean(body.approved);
        const reason = typeof body.reason === 'string' ? body.reason : undefined;

        const resolved = this.resolveConfirmation({
          id,
          approved,
          reason,
          timestamp: Date.now(),
        });

        if (resolved) {
          sendJson(200, { success: true, message: `Confirmation ${id} resolved: ${approved ? 'APPROVED' : 'DENIED'}` });
        } else {
          sendJson(404, { success: false, error: `Confirmation request "${id}" not found or already resolved.` });
        }
      } catch (err) {
        sendJson(500, { error: String(err) });
      }
      return;
    }

    // 6. POST /wake
    if (req.method === 'POST' && pathname === '/wake') {
      this.runtime.setState('listening');
      sendJson(200, { success: true, state: 'listening' });
      return;
    }

    // 7. POST /audio (Audio buffer transcription & execution)
    if (req.method === 'POST' && pathname === '/audio') {
      try {
        const chunks: Buffer[] = [];
        req.on('data', (c) => chunks.push(c));
        await new Promise((resolve) => req.on('end', resolve));
        const audioBuffer = Buffer.concat(chunks);
        this.logger.info(`Received audio recording for transcription (${audioBuffer.length} bytes)`);

        let transcript = '';
        if (this.config.stt.groqApiKey) {
          try {
            const form = new FormData();
            const blob = new Blob([audioBuffer], { type: 'audio/wav' });
            form.append('file', blob, 'audio.wav');
            form.append('model', 'whisper-large-v3-turbo');
            const groqRes = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
              method: 'POST',
              headers: { Authorization: `Bearer ${this.config.stt.groqApiKey}` },
              body: form,
            });
            if (groqRes.ok) {
              const groqData = (await groqRes.json()) as { text: string };
              transcript = groqData.text;
            }
          } catch (e) {
            this.logger.warn(`Groq STT error: ${e}`);
          }
        }

        if (!transcript.trim()) {
          this.logger.warn('Audio could not be transcribed (no STT provider returned a transcript)');
          sendJson(400, {
            error: 'Suara tidak terdengar atau tidak dapat ditranskripsikan. Pastikan berbicara lebih jelas atau ketik langsung di kolom input.',
          });
          return;
        }

        this.logger.info(`Audio transcribed to: "${transcript}"`);
        const agentResult = await this.runtime.handleTranscript(transcript);
        sendJson(200, agentResult);
      } catch (err) {
        sendJson(500, { error: String(err) });
      }
      return;
    }

    // 8. POST /reset
    if (req.method === 'POST' && pathname === '/reset') {
      this.runtime.resetConversation();
      this.runtime.setState('idle');
      sendJson(200, { success: true, state: 'idle' });
      return;
    }

    sendJson(404, { error: `Route not found: ${req.method} ${pathname}` });
  }

  public listen(port: number, host: string = '127.0.0.1'): Promise<void> {
    return new Promise((resolve) => {
      this.httpServer.listen(port, host, () => {
        this.logger.info(`Kacung Agent Server listening on http://${host}:${port} (ws://${host}:${port}/ws)`);
        resolve();
      });
    });
  }

  public close(): Promise<void> {
    return new Promise((resolve) => {
      this.wss.close(() => {
        this.httpServer.close(() => {
          resolve();
        });
      });
    });
  }
}
