import { describe, it, expect } from 'vitest';
import { processTranscript } from './normalizer.js';
import { validateTranscript } from './validator.js';

describe('Transcript Validation & Normalization Pipeline', () => {
  describe('Transcript Quality Control (Validation)', () => {
    it('rejects empty transcripts', () => {
      const res = validateTranscript('');
      expect(res.isValid).toBe(false);
      expect(res.reason).toBe('Empty transcript');
    });

    it('rejects punctuation-only noise artifacts', () => {
      const res = validateTranscript('.');
      expect(res.isValid).toBe(false);
      expect(res.reason).toBe('Punctuation-only artifact');
    });

    it('rejects repetitive speech hallucination loops', () => {
      const res = validateTranscript('the the the the the the the the');
      expect(res.isValid).toBe(false);
      expect(res.reason).toContain('Repetitive loop');
    });

    it('rejects garbled symbol text', () => {
      const res = validateTranscript('###$$$%%%&&&');
      expect(res.isValid).toBe(false);
    });

    it('rejects known subtitle hallucination patterns', () => {
      const res = validateTranscript('Thanks for watching!');
      expect(res.isValid).toBe(false);
      expect(res.reason).toContain('hallucination');
    });

    it('accepts valid normal speech', () => {
      const res = validateTranscript('Buka Spotify');
      expect(res.isValid).toBe(true);
      expect(res.confidence).toBeGreaterThan(0.8);
    });
  });

  describe('Contextual Normalization & App Name Recovery', () => {
    it('normalizes common misrecognitions of WhatsApp', () => {
      const t1 = processTranscript("open what's app");
      expect(t1.normalizedTranscript).toBe('Open WhatsApp');
      expect(t1.hasCorrections).toBe(true);
      expect(t1.rawTranscript).toBe("open what's app");

      const t2 = processTranscript('buka whats app terus chat dimas');
      expect(t2.normalizedTranscript).toBe('Buka WhatsApp terus chat Dimas');
    });

    it('normalizes Spotify in music playback context', () => {
      const res = processTranscript('play lagu di seperti');
      expect(res.normalizedTranscript).toBe('Play lagu di Spotify');
      expect(res.hasCorrections).toBe(true);
    });

    it('normalizes CapCut, VS Code, and GitHub', () => {
      const res = processTranscript('buka kap kat lalu buka vs code dan git hub');
      expect(res.normalizedTranscript).toBe('Buka CapCut lalu buka VS Code dan GitHub');
      expect(res.corrections.length).toBe(3);
    });

    it('normalizes contact names in messaging contexts', () => {
      const res = processTranscript('chat di mas bilang gue telat');
      expect(res.normalizedTranscript).toBe('Chat Dimas bilang gue telat');
    });

    it('preserves multi-step conjunctions and intent order', () => {
      const raw = 'open WhatsApp terus send message ke Dimas, then open Spotify and play my playlist';
      const res = processTranscript(raw);
      expect(res.normalizedTranscript).toBe('Open WhatsApp terus send message ke Dimas, then open Spotify and play my playlist');
      expect(res.detectedLanguage).toBe('mixed');
    });

    it('never loses the raw transcript', () => {
      const raw = 'open what\'s app';
      const res = processTranscript(raw);
      expect(res.rawTranscript).toBe('open what\'s app');
      expect(res.normalizedTranscript).toBe('Open WhatsApp');
      expect(res.confidence).toBeDefined();
      expect(res.detectedLanguage).toBe('en');
    });
  });
});
