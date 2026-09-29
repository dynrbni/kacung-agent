import type {
  LLMProvider,
  LLMCompletionOptions,
  LLMCompletionResponse,
  ToolCallRequest,
  ToolDefinition,
} from '@kacung/types';

export interface OpenAILLMOptions {
  apiKey?: string;
  baseUrl?: string;
  model?: string;
}

export class OpenAILLMProvider implements LLMProvider {
  public name = 'openai';
  private apiKey?: string;
  private baseUrl: string;
  private model: string;

  constructor(options: OpenAILLMOptions = {}) {
    this.apiKey = options.apiKey;
    this.baseUrl = (options.baseUrl || 'https://api.openai.com/v1').replace(/\/$/, '');
    this.model = options.model || 'gpt-4o-mini';
  }

  public async complete(options: LLMCompletionOptions): Promise<LLMCompletionResponse> {
    const url = `${this.baseUrl}/chat/completions`;

    const tools = options.tools?.map((tool: ToolDefinition) => ({
      type: 'function',
      function: {
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters,
      },
    }));

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey || ''}`,
      },
      body: JSON.stringify({
        model: this.model,
        messages: options.messages,
        tools: tools && tools.length > 0 ? tools : undefined,
        temperature: options.temperature ?? 0.4,
        max_tokens: options.maxTokens ?? 2048,
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`OpenAI API error (${res.status}): ${err}`);
    }

    const data = (await res.json()) as {
      choices?: Array<{
        message?: {
          content?: string;
          tool_calls?: Array<{
            id: string;
            function: {
              name: string;
              arguments: string;
            };
          }>;
        };
      }>;
    };

    const choice = data.choices?.[0]?.message;
    if (!choice) {
      return { content: '', rawResponse: data };
    }

    const toolCalls: ToolCallRequest[] = [];
    if (choice.tool_calls) {
      for (const tc of choice.tool_calls) {
        try {
          toolCalls.push({
            id: tc.id,
            name: tc.function.name,
            parameters: JSON.parse(tc.function.arguments),
          });
        } catch {
          // Ignore json parse error
        }
      }
    }

    return {
      content: choice.content || null,
      toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
      rawResponse: data,
    };
  }
}
