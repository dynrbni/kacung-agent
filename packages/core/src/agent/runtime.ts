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
}

export type AssistantEventListener = (event: AssistantEvent) => void;

export class AgentRuntime {
  private state: AssistantState = 'idle';
  private llmProvider: LLMProvider;
  private toolExecutor: ToolExecutor;
  private ttsProvider?: TextToSpeechProvider;
  private logger: Logger;
  private assistantName: string;
  private eventListeners: Set<AssistantEventListener> = new Set();
  private messages: ChatMessage[] = [];

  constructor(options: AgentRuntimeOptions) {
    this.llmProvider = options.llmProvider;
    this.toolExecutor = options.toolExecutor || new ToolExecutor();
    this.ttsProvider = options.ttsProvider;
    this.logger = options.logger || new StructuredLogger('info');
    this.assistantName = options.assistantName || 'Kacung';

    this.resetConversation();
  }

  public getState(): AssistantState {
    return this.state;
  }

  public getMessages(): ChatMessage[] {
    return [...this.messages];
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

  public async run(userInput: string, options: AgentRunOptions = {}): Promise<AgentRunResult> {
    const maxSteps = options.maxSteps || 8;
    const steps: AgentStep[] = [];
    const query = userInput.trim();

    this.logger.info(`Agent query received: "${query}"`);
    this.setState('thinking');

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

        this.logger.debug(`Step ${stepIndex}/${maxSteps} starting`);
        const tools = this.toolExecutor.getRegistry().list();

        // 1. LLM completion
        const completion = await this.llmProvider.complete({
          messages: this.messages,
          tools,
          temperature: options.temperature,
        });

        // Check if LLM requested tool calls
        if (completion.toolCalls && completion.toolCalls.length > 0) {
          currentStep.toolCalls = completion.toolCalls;
          this.setState('executing');

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

          // 2. Execute tools sequentially
          for (const tc of completion.toolCalls) {
            this.emitEvent('tool_start', { toolName: tc.name, parameters: tc.parameters });
            const executed = await this.toolExecutor.execute(tc.name, tc.parameters, tc.id);
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
          this.setState('thinking');
          continue;
        }

        // Final answer from LLM reached
        finalResponse = completion.content || 'Siap bos, sudah selesai.';
        currentStep.response = finalResponse;
        steps.push(currentStep);

        this.messages.push({
          role: 'assistant',
          content: finalResponse,
        });

        break;
      }

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
      this.logger.error(`Agent execution failed: ${errorMsg}`);
      this.setState('error', { error: errorMsg });
      this.emitEvent('error', { error: errorMsg });

      // Return to idle after error
      setTimeout(() => {
        if (this.state === 'error') {
          this.setState('idle');
        }
      }, 3000);

      return {
        text: `Maaf bos, terjadi kesalahan: ${errorMsg}`,
        steps,
        completed: false,
        error: errorMsg,
      };
    }
  }
}
