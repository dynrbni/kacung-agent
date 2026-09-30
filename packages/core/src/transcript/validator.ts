/**
 * Transcript Validator & Quality Control
 * Evaluates whether an STT transcript is usable, suspicious, empty, or corrupted.
 */

export interface ValidationResult {
  isValid: boolean;
  reason?: string;
  confidence: number;
}

export function validateTranscript(text: string): ValidationResult {
  const trimmed = (text || '').trim();

  // 1. Empty check
  if (!trimmed) {
    return {
      isValid: false,
      reason: 'Empty transcript',
      confidence: 0.0,
    };
  }

  // 2. Minimum length check: single punctuation or solitary vowel artifact
  if (trimmed.length === 1 && !/[a-zA-Z0-9]/.test(trimmed)) {
    return {
      isValid: false,
      reason: 'Punctuation-only artifact',
      confidence: 0.0,
    };
  }

  // 3. Hallucination / repetitive loops (e.g. "ha ha ha ha ha ha ha", "the the the the the")
  const words = trimmed.toLowerCase().split(/\s+/);
  if (words.length >= 5) {
    const wordCounts = new Map<string, number>();
    for (const w of words) {
      wordCounts.set(w, (wordCounts.get(w) || 0) + 1);
    }
    const maxRepetition = Math.max(...wordCounts.values());
    if (maxRepetition / words.length > 0.7 && words.length >= 6) {
      return {
        isValid: false,
        reason: 'Repetitive loop artifact detected',
        confidence: 0.2,
      };
    }
  }

  // 4. Excessive symbol density or keyboard smash (e.g. "§$%&/()=?")
  const alphanumericCount = (trimmed.match(/[a-zA-Z0-9\s]/g) || []).length;
  const ratio = alphanumericCount / trimmed.length;
  if (ratio < 0.5 && trimmed.length > 3) {
    return {
      isValid: false,
      reason: 'Garbled text with excessive symbols',
      confidence: 0.1,
    };
  }

  // 5. Common whisper/STT filler hallucination patterns
  const knownFillerHallucinations = [
    'subtitles by',
    'subtitle by',
    'terima kasih sudah menonton',
    'thanks for watching',
    'thank you for watching',
    'subtitles created by',
  ];
  const lower = trimmed.toLowerCase();
  for (const filler of knownFillerHallucinations) {
    if (lower.includes(filler) && words.length <= 6) {
      return {
        isValid: false,
        reason: 'Known STT hallucination phrase',
        confidence: 0.1,
      };
    }
  }

  // High-confidence valid transcript
  let baseConfidence = 0.95;
  if (words.length <= 2) {
    baseConfidence = 0.88;
  }

  return {
    isValid: true,
    confidence: baseConfidence,
  };
}
