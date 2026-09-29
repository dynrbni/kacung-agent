import type { WakeWordDetector } from '@kacung/types';

/**
 * HotkeyWakeWordDetector
 *
 * Development fallback for wake-word detection using Option+Space hotkey or manual trigger.
 * Clearly marked as a development feature until production-ready local on-device wake-word model is attached.
 */
export class HotkeyWakeWordDetector implements WakeWordDetector {
  public name = 'hotkey-fallback (Option+Space - Development Feature)';
  private listening = false;
  private onWakeCallback?: () => void;

  public start(onWake: () => void): void {
    this.listening = true;
    this.onWakeCallback = onWake;
  }

  public stop(): void {
    this.listening = false;
    this.onWakeCallback = undefined;
  }

  public isListening(): boolean {
    return this.listening;
  }

  /**
   * Manually triggers wake word event (used by hotkey listener or UI trigger)
   */
  public trigger(): void {
    if (this.listening && this.onWakeCallback) {
      this.onWakeCallback();
    }
  }
}
