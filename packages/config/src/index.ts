import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';
import type { LogLevel } from '@kacung/types';

export interface KacungConfig {
  server: {
    port: number;
    host: string;
  };
  llm: {
    provider: 'ninerouter' | 'gemini' | 'openai' | 'anthropic' | 'ollama' | 'mock';
    model: string;
    nineRouterBaseUrl: string;
    nineRouterApiKey?: string;
    nineRouterModel: string;
    geminiApiKey?: string;
    openAiApiKey?: string;
    anthropicApiKey?: string;
    ollamaBaseUrl: string;
    ollamaModel: string;
  };
  stt: {
    provider: 'apple' | 'whisper' | 'groq' | 'mock';
    groqApiKey?: string;
  };
  tts: {
    provider: 'macos' | 'openai' | 'elevenlabs' | 'mock';
    voice: string;
    speed: number;
  };
  assistant: {
    name: string;
    wakePhrase: string;
    languages: string[];
    hotkeyFallback: string;
  };
  security: {
    confirmSensitiveActions: boolean;
    confirmDangerousActions: boolean;
  };
  logging: {
    level: LogLevel;
  };
}

let cachedConfig: KacungConfig | null = null;

export function loadConfig(envPath?: string): KacungConfig {
  if (cachedConfig && !envPath) {
    return cachedConfig;
  }

  // Search for .env file if not explicitly passed
  if (!envPath) {
    const candidates = [
      path.resolve(process.cwd(), '.env'),
      path.resolve(process.cwd(), '../../.env'),
      path.resolve(process.cwd(), '../.env'),
    ];
    for (const candidate of candidates) {
      if (fs.existsSync(candidate)) {
        envPath = candidate;
        break;
      }
    }
  }

  if (envPath && fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
  } else {
    dotenv.config();
  }

  const env = process.env;

  const defaultNineRouterModel = env.NINEROUTER_MODEL || 'ag/gemini-3.8-flash-high';
  const defaultNineRouterBaseUrl = env.NINEROUTER_BASE_URL || 'http://localhost:20128/v1';

  const config: KacungConfig = {
    server: {
      port: parseInt(env.PORT || '3847', 10),
      host: env.HOST || '127.0.0.1',
    },
    llm: {
      provider:
        (env.LLM_PROVIDER as KacungConfig['llm']['provider']) ||
        (env.NINEROUTER_API_KEY !== undefined || env.NINEROUTER_BASE_URL !== undefined ? 'ninerouter' : 'mock'),
      model: env.NINEROUTER_MODEL || env.LLM_MODEL || defaultNineRouterModel,
      nineRouterBaseUrl: defaultNineRouterBaseUrl,
      nineRouterApiKey: env.NINEROUTER_API_KEY,
      nineRouterModel: defaultNineRouterModel,
      geminiApiKey: env.GEMINI_API_KEY,
      openAiApiKey: env.OPENAI_API_KEY,
      anthropicApiKey: env.ANTHROPIC_API_KEY,
      ollamaBaseUrl: env.OLLAMA_BASE_URL || 'http://127.0.0.1:11434',
      ollamaModel: env.OLLAMA_MODEL || 'llama3.2',
    },
    stt: {
      provider: (env.STT_PROVIDER as KacungConfig['stt']['provider']) || 'apple',
      groqApiKey: env.GROQ_API_KEY,
    },
    tts: {
      provider: (env.TTS_PROVIDER as KacungConfig['tts']['provider']) || 'macos',
      voice: env.TTS_VOICE || 'Damayanti',
      speed: 1.0,
    },
    assistant: {
      name: env.ASSISTANT_NAME || 'Kacung',
      wakePhrase: env.WAKE_PHRASE || 'Woi Kacung',
      languages: (env.DEFAULT_LANGUAGES || 'id,en').split(',').map((s) => s.trim()),
      hotkeyFallback: env.HOTKEY_FALLBACK || 'Option+Space',
    },
    security: {
      confirmSensitiveActions: env.CONFIRM_SENSITIVE_ACTIONS !== 'false',
      confirmDangerousActions: env.CONFIRM_DANGEROUS_ACTIONS !== 'false',
    },
    logging: {
      level: (env.LOG_LEVEL as LogLevel) || 'info',
    },
  };

  if (!envPath) {
    cachedConfig = config;
  }

  return config;
}

export function getConfig(): KacungConfig {
  return loadConfig();
}
