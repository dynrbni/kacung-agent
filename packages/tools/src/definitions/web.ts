import { execFile } from 'child_process';
import { promisify } from 'util';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@kacung/types';

const execFileAsync = promisify(execFile);

// ----------------------------------------------------------------------------
// Open URL Tool
// ----------------------------------------------------------------------------
export interface OpenUrlParams {
  url: string;
}

export const openUrlTool: ToolDefinition<OpenUrlParams, { url: string; message: string }> = {
  name: 'open_url',
  description: 'Opens a web URL in the user\'s default web browser on macOS.',
  permissionLevel: 'SAFE',
  parameters: {
    type: 'object',
    properties: {
      url: {
        type: 'string',
        description: 'The full URL to open (e.g. "https://apple.com" or "https://google.com").',
      },
    },
    required: ['url'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.url || typeof p.url !== 'string') {
      return { valid: false, error: 'url is required and must be a string' };
    }
    try {
      new URL(p.url);
      return { valid: true };
    } catch {
      return { valid: false, error: 'url must be a valid URL starting with http:// or https://' };
    }
  },
  async execute(params: OpenUrlParams, context: ToolExecutionContext): Promise<ToolResult<{ url: string; message: string }>> {
    const url = params.url.trim();
    context.logger.info(`Opening URL in default browser: ${url}`);

    try {
      await execFileAsync('open', [url]);
      return {
        success: true,
        data: {
          url,
          message: `Opened ${url} in default browser.`,
        },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Open URL failed: ${msg}`);
      return { success: false, error: `Failed to open URL: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Web Search Tool
// ----------------------------------------------------------------------------
export interface WebSearchParams {
  query: string;
  maxResults?: number;
}

export interface SearchResultItem {
  title: string;
  snippet: string;
  url: string;
}

export const webSearchTool: ToolDefinition<WebSearchParams, { query: string; results: SearchResultItem[] }> = {
  name: 'web_search',
  description: 'Searches the web for information using DuckDuckGo and returns top results with titles, snippets, and URLs.',
  permissionLevel: 'SAFE',
  parameters: {
    type: 'object',
    properties: {
      query: {
        type: 'string',
        description: 'The search query or keywords.',
      },
      maxResults: {
        type: 'number',
        description: 'Maximum number of results to return (default: 5).',
      },
    },
    required: ['query'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.query || typeof p.query !== 'string' || p.query.trim() === '') {
      return { valid: false, error: 'query is required and must be a non-empty string' };
    }
    return { valid: true };
  },
  async execute(params: WebSearchParams, context: ToolExecutionContext): Promise<ToolResult<{ query: string; results: SearchResultItem[] }>> {
    const query = params.query.trim();
    const maxResults = params.maxResults || 5;
    context.logger.info(`Searching web for: "${query}"`);

    try {
      // DuckDuckGo HTML search endpoint
      const searchUrl = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;
      const response = await fetch(searchUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      });

      if (!response.ok) {
        return {
          success: false,
          error: `Search request failed with HTTP ${response.status}`,
        };
      }

      const html = await response.text();
      const results: SearchResultItem[] = [];

      // Extract results from DDG HTML
      const resultRegex = /<a[^>]*class="result__url"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>[\s\S]*?<a[^>]*class="result__snippet"[^>]*>([\s\S]*?)<\/a>/gi;
      let match: RegExpExecArray | null;

      while ((match = resultRegex.exec(html)) !== null && results.length < maxResults) {
        let rawUrl = match[1] || '';
        // DDG redirects URLs through //duckduckgo.com/l/?uddg=...
        if (rawUrl.includes('uddg=')) {
          const uddgMatch = rawUrl.match(/uddg=([^&]+)/);
          if (uddgMatch && uddgMatch[1]) {
            rawUrl = decodeURIComponent(uddgMatch[1]);
          }
        }

        const snippet = (match[3] || '').replace(/<[^>]+>/g, '').trim();
        const title = (match[2] || '').replace(/<[^>]+>/g, '').trim();

        if (rawUrl.startsWith('http')) {
          results.push({
            title: title || rawUrl,
            snippet: snippet || '',
            url: rawUrl,
          });
        }
      }

      // Fallback simple title extraction if regex above matched differently
      if (results.length === 0) {
        const titleRegex = /<h2[^>]*class="result__title"[^>]*>[\s\S]*?<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/gi;
        let tMatch: RegExpExecArray | null;
        while ((tMatch = titleRegex.exec(html)) !== null && results.length < maxResults) {
          let rawUrl = tMatch[1] || '';
          if (rawUrl.includes('uddg=')) {
            const uddgMatch = rawUrl.match(/uddg=([^&]+)/);
            if (uddgMatch && uddgMatch[1]) {
              rawUrl = decodeURIComponent(uddgMatch[1]);
            }
          }
          const title = (tMatch[2] || '').replace(/<[^>]+>/g, '').trim();
          if (rawUrl.startsWith('http')) {
            results.push({
              title,
              snippet: '',
              url: rawUrl,
            });
          }
        }
      }

      context.logger.info(`Web search returned ${results.length} results`);

      return {
        success: true,
        data: {
          query,
          results,
        },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Web search failed: ${msg}`);
      return { success: false, error: `Web search error: ${msg}` };
    }
  },
};

// ----------------------------------------------------------------------------
// Read Web Page Tool
// ----------------------------------------------------------------------------
export interface ReadWebPageParams {
  url: string;
  maxLength?: number;
}

export const readWebPageTool: ToolDefinition<ReadWebPageParams, { url: string; title: string; content: string }> = {
  name: 'read_web_page',
  description: 'Fetches and extracts clean readable text content from a web page URL.',
  permissionLevel: 'SAFE',
  parameters: {
    type: 'object',
    properties: {
      url: {
        type: 'string',
        description: 'The webpage URL to read.',
      },
      maxLength: {
        type: 'number',
        description: 'Maximum characters of text to return (default: 8000).',
      },
    },
    required: ['url'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.url || typeof p.url !== 'string') {
      return { valid: false, error: 'url is required and must be a string' };
    }
    try {
      new URL(p.url);
      return { valid: true };
    } catch {
      return { valid: false, error: 'url must be a valid URL starting with http:// or https://' };
    }
  },
  async execute(params: ReadWebPageParams, context: ToolExecutionContext): Promise<ToolResult<{ url: string; title: string; content: string }>> {
    const url = params.url.trim();
    const maxLength = params.maxLength || 8000;
    context.logger.info(`Fetching web page content: ${url}`);

    try {
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      });

      if (!response.ok) {
        return {
          success: false,
          error: `HTTP error ${response.status}: ${response.statusText}`,
        };
      }

      const rawHtml = await response.text();

      // Extract title
      const titleMatch = rawHtml.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
      const title = titleMatch ? titleMatch[1]?.trim() || '' : '';

      // Strip script, style, nav, footer tags
      let clean = rawHtml
        .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
        .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '')
        .replace(/<nav\b[^<]*(?:(?!<\/nav>)<[^<]*)*<\/nav>/gi, '')
        .replace(/<footer\b[^<]*(?:(?!<\/footer>)<[^<]*)*<\/footer>/gi, '')
        .replace(/<!--[\s\S]*?-->/g, '');

      // Replace common block elements with newlines
      clean = clean
        .replace(/<\/(p|div|h[1-6]|li|blockquote|tr)>/gi, '\n')
        .replace(/<br\s*\/?>/gi, '\n');

      // Strip remaining HTML tags
      clean = clean.replace(/<[^>]+>/g, ' ');

      // Normalize whitespace
      clean = clean
        .replace(/[ \t]+/g, ' ')
        .replace(/\n\s*\n+/g, '\n\n')
        .trim();

      if (clean.length > maxLength) {
        clean = clean.substring(0, maxLength) + '... [Content truncated]';
      }

      return {
        success: true,
        data: {
          url,
          title,
          content: clean,
        },
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Read web page failed: ${msg}`);
      return { success: false, error: `Failed to read web page: ${msg}` };
    }
  },
};
