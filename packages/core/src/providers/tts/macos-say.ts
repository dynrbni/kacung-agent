import { execFile } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';
import os from 'os';
import type { TextToSpeechProvider, TTSOptions } from '@lafly/types';

const execFileAsync = promisify(execFile);

export interface MacOSSayOptions {
  defaultVoice?: string;
  defaultSpeed?: number;
}

export class MacOSSayTTSProvider implements TextToSpeechProvider {
  public name = 'macos-say';
  private defaultVoice: string;
  private defaultSpeed: number;

  constructor(options: MacOSSayOptions = {}) {
    this.defaultVoice = options.defaultVoice || 'Damayanti';
    this.defaultSpeed = options.defaultSpeed || 1.0;
  }

  public async speak(text: string, options?: TTSOptions): Promise<void> {
    if (!text || text.trim() === '') return;

    const voice = options?.voice || this.defaultVoice;
    const cleanText = text.replace(/[*_#`]/g, '').trim();

    try {
      // First try configured voice
      await execFileAsync('say', ['-v', voice, cleanText]);
    } catch {
      // Fallback to default system voice if configured voice is not downloaded
      try {
        await execFileAsync('say', [cleanText]);
      } catch (err: unknown) {
        console.error('MacOS say failed:', err);
      }
    }
  }

  public async synthesize(text: string, options?: TTSOptions): Promise<Buffer | null> {
    if (!text || text.trim() === '') return null;

    const voice = options?.voice || this.defaultVoice;
    const tempFile = path.join(os.tmpdir(), `lafly-tts-${Date.now()}.aiff`);
    const cleanText = text.replace(/[*_#`]/g, '').trim();

    try {
      await execFileAsync('say', ['-v', voice, '-o', tempFile, cleanText]);
      if (fs.existsSync(tempFile)) {
        const buffer = fs.readFileSync(tempFile);
        fs.unlinkSync(tempFile);
        return buffer;
      }
      return null;
    } catch {
      // Fallback
      try {
        await execFileAsync('say', ['-o', tempFile, cleanText]);
        if (fs.existsSync(tempFile)) {
          const buffer = fs.readFileSync(tempFile);
          fs.unlinkSync(tempFile);
          return buffer;
        }
      } catch {
        return null;
      }
      return null;
    }
  }
}
