import type { ProcessedTranscript, TranscriptCorrection } from '@kacung/types';
import { validateTranscript } from './validator.js';

/**
 * Contextual Transcript Normalizer
 * Preserves user intent, normalizes app names, homophones, and proper nouns without hallucinating.
 */

interface ReplacementRule {
  pattern: RegExp;
  replacement: string;
  reason: string;
  contextCheck?: (text: string) => boolean;
}

const NORMALIZATION_RULES: ReplacementRule[] = [
  // Application Names
  {
    pattern: /\b(what'?s\s*app|whats\s*app|buat\s*sab|watsap|wa)\b/gi,
    replacement: 'WhatsApp',
    reason: 'Normalize WhatsApp application name',
  },
  {
    pattern: /\b(spotifly|spotfy|spoti\s*fy)\b/gi,
    replacement: 'Spotify',
    reason: 'Normalize Spotify application name',
  },
  {
    // Contextual: "seperti" in a music / play context -> Spotify
    pattern: /\bseperti\b/gi,
    replacement: 'Spotify',
    reason: 'Contextual correction of "seperti" to Spotify in music playback context',
    contextCheck: (text: string) => /\b(play|putar|musik|lagu|buka|open|song|album|playlist)\b/i.test(text),
  },
  {
    pattern: /\b(cap\s*cut|kap\s*kat|kapkat|cup\s*cut)\b/gi,
    replacement: 'CapCut',
    reason: 'Normalize CapCut application name',
  },
  {
    pattern: /\b(vs\s*code|vscode|visio\s*code|visual\s*studio\s*code)\b/gi,
    replacement: 'VS Code',
    reason: 'Normalize VS Code application name',
  },
  {
    pattern: /\b(git\s*hub|git\s*up)\b/gi,
    replacement: 'GitHub',
    reason: 'Normalize GitHub proper noun',
  },
  {
    pattern: /\b(dis\s*cord)\b/gi,
    replacement: 'Discord',
    reason: 'Normalize Discord application name',
  },
  {
    pattern: /\b(tele\s*gram)\b/gi,
    replacement: 'Telegram',
    reason: 'Normalize Telegram application name',
  },
  {
    pattern: /\b(google\s*chrome|gogle\s*crom|gugel\s*crom)\b/gi,
    replacement: 'Google Chrome',
    reason: 'Normalize Google Chrome browser name',
  },
  {
    pattern: /\b(ms\s*word|microsoft\s*word)\b/gi,
    replacement: 'Word',
    reason: 'Normalize Microsoft Word application name',
  },
  // Proper nouns / Contact names in messaging context
  {
    pattern: /\b(di\s*mas|the\s*mass)\b/gi,
    replacement: 'Dimas',
    reason: 'Normalize contact name Dimas',
    contextCheck: (text: string) => /\b(chat|pesan|message|wa|whatsapp|kirim|send|ke|to|hubungi)\b/i.test(text),
  },
];

/**
 * Detect language based on vocabulary distribution.
 */
function detectLanguage(text: string): 'id' | 'en' | 'mixed' {
  const lower = text.toLowerCase();
  const indonesianWords = [
    'buka', 'tutup', 'terus', 'lalu', 'dan', 'ke', 'di', 'gue', 'lu', 'tolong',
    'kecilkan', 'besarkan', 'turunin', 'naikin', 'suara', 'lagu', 'putar',
    'kirim', 'pesan', 'bilang', 'bahaya', 'kesimpulan', 'ketik', 'layar',
    'matikan', 'nyalakan', 'cari', 'tentang', 'habis', 'itu', 'kemudian'
  ];
  const englishWords = [
    'open', 'close', 'play', 'send', 'message', 'to', 'and', 'then', 'volume',
    'screenshot', 'write', 'search', 'find', 'down', 'up', 'mute', 'unmute',
    'please', 'my', 'playlist', 'daily', 'late', 'about', 'document'
  ];

  let idCount = 0;
  let enCount = 0;

  for (const w of indonesianWords) {
    if (new RegExp(`\\b${w}\\b`, 'i').test(lower)) idCount++;
  }
  for (const w of englishWords) {
    if (new RegExp(`\\b${w}\\b`, 'i').test(lower)) enCount++;
  }

  if (idCount > 0 && enCount > 0) return 'mixed';
  if (idCount > 0) return 'id';
  if (enCount > 0) return 'en';
  return 'mixed';
}

/**
 * Normalizes speech-to-text transcript while strictly preserving raw original transcript.
 */
export function processTranscript(rawText: string): ProcessedTranscript {
  const rawTranscript = rawText || '';
  const validation = validateTranscript(rawTranscript);

  if (!validation.isValid) {
    return {
      rawTranscript,
      normalizedTranscript: rawTranscript,
      confidence: validation.confidence,
      detectedLanguage: 'mixed',
      isValid: false,
      validationReason: validation.reason,
      hasCorrections: false,
      corrections: [],
    };
  }

  let normalized = rawTranscript.trim();
  const corrections: TranscriptCorrection[] = [];

  // Apply contextual normalization rules
  for (const rule of NORMALIZATION_RULES) {
    if (rule.contextCheck && !rule.contextCheck(normalized)) {
      continue;
    }

    const matches = normalized.match(rule.pattern);
    if (matches) {
      for (const m of matches) {
        if (m !== rule.replacement) {
          corrections.push({
            from: m,
            to: rule.replacement,
            reason: rule.reason,
          });
        }
      }
      normalized = normalized.replace(rule.pattern, rule.replacement);
    }
  }

  // Clean redundant whitespace and standard capitalization
  normalized = normalized.replace(/\s{2,}/g, ' ');

  // Ensure first character is capitalized if sentence starts with lowercase
  if (normalized.length > 0 && /^[a-z]/.test(normalized)) {
    normalized = normalized.charAt(0).toUpperCase() + normalized.slice(1);
  }

  const detectedLanguage = detectLanguage(normalized);

  return {
    rawTranscript,
    normalizedTranscript: normalized,
    confidence: validation.confidence,
    detectedLanguage,
    isValid: true,
    hasCorrections: corrections.length > 0,
    corrections,
  };
}
