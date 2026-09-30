import type {
  LLMProvider,
  LLMCompletionOptions,
  LLMCompletionResponse,
  ToolCallRequest,
} from '@lafly/types';

export interface MockLLMResponseStep {
  content?: string | null;
  toolCalls?: ToolCallRequest[];
}

export class MockLLMProvider implements LLMProvider {
  public name = 'mock';
  private cannedResponses: MockLLMResponseStep[] = [];
  private stepIndex = 0;

  constructor(responses?: MockLLMResponseStep[]) {
    if (responses) {
      this.cannedResponses = responses;
    }
  }

  public queueResponse(step: MockLLMResponseStep): void {
    this.cannedResponses.push(step);
  }

  public reset(): void {
    this.cannedResponses = [];
    this.stepIndex = 0;
  }

  public async complete(options: LLMCompletionOptions): Promise<LLMCompletionResponse> {
    if (this.cannedResponses.length > 0 && this.stepIndex < this.cannedResponses.length) {
      const step = this.cannedResponses[this.stepIndex++];
      return {
        content: step.content || null,
        toolCalls: step.toolCalls,
      };
    }

    // Default heuristic for mock when no canned responses are configured
    const lastUserMessage = options.messages
      .filter((m) => m.role === 'user')
      .pop()?.content?.toLowerCase() || '';

    if (lastUserMessage.includes('jam') || lastUserMessage.includes('time')) {
      return {
        content: `Sekarang jam ${new Date().toLocaleTimeString('id-ID')}, bos. Ada lagi yang bisa Lafly bantu?`,
      };
    }

    if (lastUserMessage.includes('buka spotify') || lastUserMessage.includes('open spotify')) {
      return {
        content: 'Siap bos, langsung buka Spotify!',
        toolCalls: [
          {
            id: `call_spotify_${Date.now()}`,
            name: 'open_app',
            parameters: { appName: 'Spotify' },
          },
        ],
      };
    }

    if (lastUserMessage.includes('screenshot') || lastUserMessage.includes('layar')) {
      return {
        content: 'Siap bos, Lafly ambilkan screenshot sekarang.',
        toolCalls: [
          {
            id: `call_screen_${Date.now()}`,
            name: 'screenshot',
            parameters: {},
          },
        ],
      };
    }

    return {
      content: 'Halo bos! Lafly siap membantu tugas apa saja di Mac Anda.',
    };
  }
}
