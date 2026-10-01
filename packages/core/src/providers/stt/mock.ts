import type { SpeechToTextProvider, STTOptions, STTResult } from '@lofly/types';

export class MockSTTProvider implements SpeechToTextProvider {
  public name = 'mock-stt';
  private cannedTranscript = 'Woi Lofly, buka Spotify';

  constructor(initialTranscript?: string) {
    if (initialTranscript) {
      this.cannedTranscript = initialTranscript;
    }
  }

  public setTranscript(transcript: string): void {
    this.cannedTranscript = transcript;
  }

  public async transcribe(_audioBuffer: Buffer | ArrayBuffer, _options?: STTOptions): Promise<STTResult> {
    return {
      text: this.cannedTranscript,
      confidence: 0.98,
      language: 'id-ID',
    };
  }
}
