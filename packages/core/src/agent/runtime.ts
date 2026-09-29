import type {
  AssistantState,
  AssistantEvent,
  ChatMessage,
  AgentRunOptions,
  AgentRunResult,
  AgentStep,
  LLMProvider,
  TextToSpeechProvider,
  Logger,
  ExecutedToolCall,
} from '@kacung/types';
import { ToolExecutor } from '@kacung/tools';
import { buildSystemPrompt } from './prompt.js';
import { StructuredLogger } from '../logger/index.js';

export interface AgentRuntimeOptions {
  llmProvider: LLMProvider;
  toolExecutor?: ToolExecutor;
  ttsProvider?: TextToSpeechProvider;
  logger?: Logger;
  assistantName?: string;
  debug?: boolean;
}

export type AssistantEventListener = (event: AssistantEvent) => void;

export class AgentRuntime {
  private state: AssistantState = 'idle';
  private llmProvider: LLMProvider;
  private toolExecutor: ToolExecutor;
  private ttsProvider?: TextToSpeechProvider;
  private logger: Logger;
  private assistantName: string;
  private debug: boolean;
  private eventListeners: Set<AssistantEventListener> = new Set();
  private messages: ChatMessage[] = [];

  constructor(options: AgentRuntimeOptions) {
    this.llmProvider = options.llmProvider;
    this.toolExecutor = options.toolExecutor || new ToolExecutor();
    this.ttsProvider = options.ttsProvider;
    this.logger = options.logger || new StructuredLogger('info');
    this.assistantName = options.assistantName || 'Kacung';
    this.debug = options.debug ?? (process.env.DEBUG === 'true' || process.env.NODE_ENV !== 'production');

    this.resetConversation();
  }

  public getState(): AssistantState {
    return this.state;
  }

  public getMessages(): ChatMessage[] {
    return [...this.messages];
  }

  public getModelName(): string {
    return (this.llmProvider as unknown as { model?: string }).model || 'ag/gemini-3.8-flash-high';
  }

  public resetConversation(): void {
    this.messages = [
      {
        role: 'system',
        content: buildSystemPrompt(this.assistantName),
      },
    ];
  }

  public onEvent(listener: AssistantEventListener): () => void {
    this.eventListeners.add(listener);
    return () => {
      this.eventListeners.delete(listener);
    };
  }

  private emitEvent<T = unknown>(type: AssistantEvent['type'], payload: T): void {
    const event: AssistantEvent<T> = {
      type,
      payload,
      timestamp: Date.now(),
    };
    for (const listener of this.eventListeners) {
      try {
        listener(event);
      } catch (err) {
        this.logger.error('Error in event listener', { error: String(err) });
      }
    }
  }

  public setState(newState: AssistantState, metadata?: Record<string, unknown>): void {
    if (this.state === newState) return;
    const previousState = this.state;
    this.state = newState;
    this.logger.info(`State changed: ${previousState} -> ${newState}`, metadata);
    this.emitEvent('state_change', {
      previousState,
      newState,
      metadata,
    });
  }

  /**
   * Primary entry point for speech transcripts from the voice/STT pipeline.
   */
  public async handleTranscript(transcript: string, options: AgentRunOptions = {}): Promise<AgentRunResult> {
    const trimmed = (transcript || '').trim();
    if (!trimmed) {
      this.logger.warn('handleTranscript received empty transcript');
      return {
        text: 'Maaf, suara tidak terdeteksi. Bisa diulang kembali?',
        steps: [],
        completed: false,
        error: 'empty transcript',
      };
    }
    return this.run(trimmed, options);
  }

  public async run(userInput: string, options: AgentRunOptions = {}): Promise<AgentRunResult> {
    const requestId = options.requestId || `req_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const startTime = Date.now();
    const query = (userInput || '').trim();
    const model = this.getModelName();
    const maxSteps = options.maxSteps || 8;
    const steps: AgentStep[] = [];

    if (!query) {
      return {
        text: 'Maaf, input kosong.',
        steps: [],
        completed: false,
        error: 'empty transcript',
      };
    }

    this.logger.info(`Agent query received`, {
      timestamp: startTime,
      requestId,
      transcript: query,
      model,
    });
    this.setState('thinking', { requestId, query });

    this.messages.push({
      role: 'user',
      content: query,
    });

    try {
      let stepIndex = 0;
      let finalResponse = '';

      while (stepIndex < maxSteps) {
        stepIndex++;
        const currentStep: AgentStep = { stepIndex };
        const stepStartTime = Date.now();

        this.logger.debug(`Step ${stepIndex}/${maxSteps} starting`, { requestId, stepIndex });
        const tools = this.toolExecutor.getRegistry().list();

        // 1. LLM completion lifecycle
        const llmStartTime = Date.now();
        this.logger.info('LLM request dispatched', {
          timestamp: llmStartTime,
          requestId,
          stepIndex,
          model,
        });

        const completion = await this.llmProvider.complete({
          messages: this.messages,
          tools,
          temperature: options.temperature,
        });

        const llmDurationMs = Date.now() - llmStartTime;
        this.logger.info('LLM response received', {
          timestamp: Date.now(),
          requestId,
          stepIndex,
          model,
          durationMs: llmDurationMs,
          toolCallsCount: completion.toolCalls?.length || 0,
        });

        // 2. Check if LLM requested tool calls
        if (completion.toolCalls && completion.toolCalls.length > 0) {
          currentStep.toolCalls = completion.toolCalls;
          this.setState('executing', { requestId, toolCalls: completion.toolCalls.map((tc) => tc.name) });

          // Record assistant message with tool calls in history
          this.messages.push({
            role: 'assistant',
            content: completion.content,
            tool_calls: completion.toolCalls.map((tc) => ({
              id: tc.id,
              type: 'function',
              function: {
                name: tc.name,
                arguments: JSON.stringify(tc.parameters),
              },
            })),
          });

          const executedCalls: ExecutedToolCall[] = [];

          // 3. Execute tools sequentially
          for (const tc of completion.toolCalls) {
            const toolStartTime = Date.now();

            if (this.debug) {
              console.log('\n========================================');
              console.log('USER:');
              console.log(query);
              console.log('\nMODEL:');
              console.log(model);
              console.log('\nTOOL:');
              console.log(tc.name);
              console.log('\nARGUMENTS:');
              console.log(JSON.stringify(tc.parameters, null, 2));
            }

            this.emitEvent('tool_start', { toolName: tc.name, parameters: tc.parameters });
            const executed = await this.toolExecutor.execute(tc.name, tc.parameters, tc.id);
            const toolDurationMs = Date.now() - toolStartTime;

            if (this.debug) {
              console.log('\nRESULT:');
              console.log(executed.result.success ? 'success' : `failure (${executed.result.error || 'unknown error'})`);
              console.log('========================================\n');
            }

            this.logger.info('Tool execution completed', {
              timestamp: Date.now(),
              requestId,
              tool: tc.name,
              arguments: tc.parameters,
              result: executed.result.success ? 'success' : 'failure',
              durationMs: toolDurationMs,
              error: executed.result.error,
            });

            executedCalls.push(executed);
            this.emitEvent('tool_end', {
              toolName: tc.name,
              success: executed.result.success,
              data: executed.result.data,
              error: executed.result.error,
            });

            // Append tool observation to conversation history
            this.messages.push({
              role: 'tool',
              name: tc.name,
              tool_call_id: tc.id,
              content: JSON.stringify(executed.result),
            });
          }

          currentStep.toolResults = executedCalls;
          steps.push(currentStep);

          // Return to thinking state for next step
          this.setState('thinking', { requestId, stepIndex });
          continue;
        }

        // Final conversational answer from LLM reached
        finalResponse = completion.content || 'Siap bos, sudah selesai.';
        currentStep.response = finalResponse;
        steps.push(currentStep);

        if (this.debug && stepIndex === 1) {
          console.log('\n========================================');
          console.log('USER:');
          console.log(query);
          console.log('\nMODEL:');
          console.log(model);
          console.log('\nTOOL:');
          console.log('none (conversational response)');
          console.log('\nRESULT:');
          console.log(finalResponse);
          console.log('========================================\n');
        }

        this.messages.push({
          role: 'assistant',
          content: finalResponse,
        });

        break;
      }

      const totalDurationMs = Date.now() - startTime;
      this.logger.info('Agent run completed', {
        timestamp: Date.now(),
        requestId,
        model,
        totalSteps: steps.length,
        executionDurationMs: totalDurationMs,
      });

      // Voice output (TTS)
      if (finalResponse && this.ttsProvider) {
        this.setState('speaking');
        this.emitEvent('speech_start', { text: finalResponse });
        try {
          if (this.ttsProvider.speak) {
            await this.ttsProvider.speak(finalResponse);
          } else {
            await this.ttsProvider.synthesize(finalResponse);
          }
        } catch (ttsErr) {
          this.logger.warn('TTS playback error', { error: String(ttsErr) });
        }
        this.emitEvent('speech_end', { text: finalResponse });
      }

      this.setState('idle');
      return {
        text: finalResponse,
        steps,
        completed: true,
      };
    } catch (err: unknown) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      const totalDurationMs = Date.now() - startTime;

      this.logger.error('Agent execution failed', {
        timestamp: Date.now(),
        requestId,
        transcript: query,
        model,
        durationMs: totalDurationMs,
        error: errorMsg,
      });

      this.setState('error', { error: errorMsg, requestId });
      this.emitEvent('error', { error: errorMsg, requestId });

      // Clean, user-friendly responses based on failure category
      let friendlyText = `Maaf bos, terjadi kesalahan: ${errorMsg}`;
      const lower = errorMsg.toLowerCase();

      if (
        lower.includes('ninerouter unavailable') ||
        lower.includes('econnrefused') ||
        lower.includes('connection error') ||
        lower.includes('failed to fetch') ||
        lower.includes('enotfound')
      ) {
        friendlyText = 'Gue nggak bisa terhubung ke AI sekarang. Pastikan 9Router sudah berjalan di localhost:20128.';
      } else if (
        lower.includes('unauthorized') ||
        lower.includes('invalid api key') ||
        lower.includes('401')
      ) {
        friendlyText = 'Gue nggak bisa terhubung ke AI karena API key 9Router belum dikonfigurasi dengan benar di file .env.';
      } else if (lower.includes('model') && (lower.includes('not found') || lower.includes('unavailable') || lower.includes('404'))) {
        friendlyText = `Model AI "${model}" tidak tersedia di 9Router.`;
      } else if (lower.includes('timeout')) {
        friendlyText = 'AI membutuhkan waktu terlalu lama untuk merespons (timeout).';
      }

      // Return to idle after error
      setTimeout(() => {
        if (this.state === 'error') {
          this.setState('idle');
        }
      }, 3000);

      return {
        text: friendlyText,
        steps,
        completed: false,
        error: errorMsg,
      };
    }
  }
}

export { AgentRuntime as KacungAgent };

