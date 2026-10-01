import { describe, it, expect } from 'vitest';
import { capabilityLabel, firstSentence } from './skills.js';

describe('Skills — capability wording', () => {
  it('names a capability, not something that already happened', () => {
    expect(capabilityLabel('open_app')).toBe('Open an app');
    expect(capabilityLabel('run_command')).toBe('Run a shell command');
    expect(capabilityLabel('send_whatsapp_message')).toBe('Send a WhatsApp message');
  });

  it('tells apart two tools the activity log names identically', () => {
    // humanizeToolName renders both of these as "Captured screen".
    expect(capabilityLabel('screenshot')).not.toBe(capabilityLabel('screenshot_app'));
  });

  it('falls back to a readable phrase for a tool with no wording yet', () => {
    expect(capabilityLabel('rotate_display')).toBe('Use rotate display');
  });
});

describe('Skills — visible description', () => {
  it('keeps the first sentence and stops at its end', () => {
    const description =
      'Takes a screenshot of the main macOS display and saves it locally. Useful for inspecting current screen state or UI.';

    expect(firstSentence(description)).toBe(
      'Takes a screenshot of the main macOS display and saves it locally.'
    );
  });

  it('does not mistake an abbreviation for the end of a sentence', () => {
    const description =
      'Simulates pressing a single keyboard key (e.g. "return", "escape") with optional modifiers.';

    // Cutting at "e.g." would leave the row ending inside a parenthesis.
    expect(firstSentence(description)).toBe(description);
    expect(firstSentence(description)).not.toMatch(/\([^)]*$/);
  });

  it('returns a single-sentence description unchanged', () => {
    const description = 'Reads the contents of a local file as UTF-8 text.';
    expect(firstSentence(description)).toBe(description);
  });

  it('returns text with no sentence break unchanged', () => {
    expect(firstSentence('Lists files and folders inside a given directory')).toBe(
      'Lists files and folders inside a given directory'
    );
  });
});
