import { describe, it, expect } from 'vitest';
import { readFileSync } from 'fs';
import path from 'path';

const APP_STATE = readFileSync(
  path.join(process.cwd(), 'apps/macos/Sources/LoflyApp/AppState.swift'),
  'utf8'
);
const HOTKEY = readFileSync(
  path.join(process.cwd(), 'apps/macos/Sources/LoflyApp/Services/HotkeyManager.swift'),
  'utf8'
);

/**
 * Push-to-talk is timing logic that cannot be exercised from the Node suite, so
 * these assertions guard the source shape that implements it: a tap must never
 * open the notch or the microphone, and a release must always be handled.
 */
describe('Push to talk — a tap must not summon the notch', () => {
  it('treats the hotkey press as arming only, not as starting capture', () => {
    // handleHotkeyPress only schedules; it must not call showOverlay/startListening.
    const press = APP_STATE.slice(
      APP_STATE.indexOf('public func handleHotkeyPress()'),
      APP_STATE.indexOf('private func beginPushToTalk()')
    );

    expect(press).toContain('pushToTalkThreshold');
    expect(press).not.toContain('showOverlay()');
    expect(press).not.toContain('startListening()');
  });

  it('opens the notch and microphone only after the hold threshold elapses', () => {
    const begin = APP_STATE.slice(
      APP_STATE.indexOf('private func beginPushToTalk()'),
      APP_STATE.indexOf('public func startHandsFreeListening()')
    );

    expect(begin).toContain('showOverlay()');
    expect(begin).toContain('startListening()');
  });

  it('guards capture behind a short, deliberate threshold', () => {
    expect(APP_STATE).toMatch(/pushToTalkThreshold: TimeInterval = 0\.\d+/);
  });

  it('never summons on release below the threshold', () => {
    const release = APP_STATE.slice(
      APP_STATE.indexOf('public func handleHotkeyRelease(duration:'),
      APP_STATE.indexOf('private func cancelPushToTalk()')
    );

    // A tap short-circuits before it can submit anything.
    expect(release).toMatch(/duration < Self\.pushToTalkThreshold/);
    expect(release).toContain('cancelPushToTalk()');
    expect(release).toContain('return');
  });

  it('discards the capture and hides the notch when nothing was spoken', () => {
    const discard = APP_STATE.slice(
      APP_STATE.indexOf('public func handleHotkeyRelease(duration:'),
      APP_STATE.indexOf('private func cancelPushToTalk()')
    );

    expect(discard).toContain('speechRecognizer.hasSpoken');
    expect(discard).toContain('stopListening()');
  });

  it('tears down cleanly instead of leaving the microphone open', () => {
    const cancel = APP_STATE.slice(
      APP_STATE.indexOf('private func cancelPushToTalk()'),
      APP_STATE.indexOf('public func startListening()')
    );

    expect(cancel).toContain('speechRecognizer.cancelListening()');
    expect(cancel).toContain('hideOverlay()');
    expect(cancel).toContain('state = .idle');
  });

  it('keeps a hands-free path that does not require holding', () => {
    expect(APP_STATE).toContain('public func startHandsFreeListening()');
    const menu = readFileSync(
      path.join(process.cwd(), 'apps/macos/Sources/LoflyApp/Views/MenuBarView.swift'),
      'utf8'
    );
    expect(menu).toContain('startHandsFreeListening()');
  });

  it('has no leftover tap-to-summon entry point', () => {
    expect(APP_STATE).not.toContain('handleHotkeyWake');
    expect(HOTKEY).not.toContain('onHotkeyTriggered');
    // The old 0.45s "summon hands-free on tap" path is gone.
    expect(APP_STATE).not.toContain('duration < 0.45');
  });

  it('emits a press event separate from the release event', () => {
    expect(HOTKEY).toContain('onHotkeyPressed');
    expect(HOTKEY).toContain('onHotkeyReleased');
  });
});
