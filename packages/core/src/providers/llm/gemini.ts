import type {
  LLMProvider,
  LLMCompletionOptions,
  LLMCompletionResponse,
  ToolCallRequest,
  ChatMessage,
  ToolDefinition,
} from '@lafly/types';

export interface GeminiLLMOptions {
  apiKey: string;
  model?: string;
}

export class GeminiLLMProvider implements LLMProvider {
  public name = 'gemini';
  public model: string;
  private apiKey: string;

  constructor(options: GeminiLLMOptions) {
    this.apiKey = options.apiKey;
    this.model = options.model || 'gemini-2.0-flash';
  }

  public async complete(options: LLMCompletionOptions): Promise<LLMCompletionResponse> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`;

    // Extract system prompt
    const systemMessages = options.messages.filter((m) => m.role === 'system');
    const systemInstruction =
      systemMessages.length > 0
        ? {
            parts: [{ text: systemMessages.map((m) => m.content).join('\n\n') }],
          }
        : undefined;

    // Convert conversation contents
    const contents: Array<{
      role: 'user' | 'model';
      parts: Array<Record<string, unknown>>;
    }> = [];

    for (const msg of options.messages) {
      if (msg.role === 'system') continue;

      if (msg.role === 'user') {
        contents.push({
          role: 'user',
          parts: [{ text: msg.content || '' }],
        });
      } else if (msg.role === 'assistant') {
        const parts: Array<Record<string, unknown>> = [];
        if (msg.content) {
          parts.push({ text: msg.content });
        }
        if (msg.tool_calls && msg.tool_calls.length > 0) {
          for (const tc of msg.tool_calls) {
            try {
              const args = JSON.parse(tc.function.arguments);
              parts.push({
                functionCall: {
                  name: tc.function.name,
                  args,
                },
              });
            } catch {
              // Ignore argument JSON parse error
            }
          }
        }
        if (parts.length > 0) {
          contents.push({ role: 'model', parts });
        }
      } else if (msg.role === 'tool') {
        // Tool observation response
        contents.push({
          role: 'user',
          parts: [
            {
              functionResponse: {
                name: msg.name || 'tool_response',
                response: {
                  output: msg.content,
                },
              },
            },
          ],
        });
      }
    }

    // Convert tools if provided
    let toolsPayload: Array<{ functionDeclarations: unknown[] }> | undefined;
    if (options.tools && options.tools.length > 0) {
      toolsPayload = [
        {
          functionDeclarations: options.tools.map((t: ToolDefinition) => ({
            name: t.name,
            description: t.description,
            parameters: t.parameters,
          })),
        },
      ];
    }

    const requestBody = {
      systemInstruction,
      contents,
      tools: toolsPayload,
      generationConfig: {
        temperature: options.temperature ?? 0.4,
        maxOutputTokens: options.maxTokens ?? 2048,
      },
    };

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestBody),
    });

    if (!res.ok) {
      const errBody = await res.text();
      throw new Error(`Gemini API error (HTTP ${res.status}): ${errBody}`);
    }

    const data = (await res.json()) as {
      candidates?: Array<{
        content?: {
          parts?: Array<{
            text?: string;
            functionCall?: {
              name: string;
              args: Record<string, unknown>;
            };
          }>;
        };
      }>;
    };

    const candidate = data.candidates?.[0];
    if (!candidate || !candidate.content || !candidate.content.parts) {
      return { content: '', rawResponse: data };
    }

    let textContent = '';
    const toolCalls: ToolCallRequest[] = [];

    for (const part of candidate.content.parts) {
      if (part.text) {
        textContent += part.text;
      }
      if (part.functionCall) {
        toolCalls.push({
          id: `call_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
          name: part.functionCall.name,
          parameters: part.functionCall.args || {},
        });
      }
    }

    return {
      content: textContent.trim() || null,
      toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
      rawResponse: data,
    };
  }
}
