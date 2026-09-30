import type { TextToSpeechProvider, TTSOptions } from '@lafly/types';

export class MockTTSProvider implements TextToSpeechProvider {
  public name = 'mock-tts';
  public spokenTexts: string[] = [];

  public async speak(text: string, _options?: TTSOptions): Promise<void> {
    this.spokenTexts.push(text);
  }

  public async synthesize(text: string, _options?: TTSOptions): Promise<Buffer | null> {
    this.spokenTexts.push(text);
    return Buffer.from('mock-audio-data');
  }

  public clear(): void {
    this.spokenTexts = [];
  }
}
