import { describe, it, expect } from 'vitest';
import { WhatsAppController } from './controller.js';

describe('WhatsAppController', () => {
  it('should initialize successfully', () => {
    const controller = new WhatsAppController();
    expect(controller).toBeDefined();
    expect(typeof controller.openWhatsApp).toBe('function');
    expect(typeof controller.searchContact).toBe('function');
    expect(typeof controller.openChat).toBe('function');
    expect(typeof controller.sendMessage).toBe('function');
    expect(typeof controller.resolveContact).toBe('function');
  });

  it('should resolve contact name accurately when unique match', () => {
    const controller = new WhatsAppController();
    const contacts = [
      { name: 'Andi Pratama' },
      { name: 'Budi Santoso' },
      { name: 'Citra Dewi' },
    ];

    const result = controller.resolveContact('Budi', contacts);
    expect(result.exactMatch).toBeDefined();
    expect(result.exactMatch?.name).toBe('Budi Santoso');
    expect(result.candidates.length).toBe(1);
  });

  it('should detect ambiguous contacts for clarification', () => {
    const controller = new WhatsAppController();
    const contacts = [
      { name: 'Andi Pratama' },
      { name: 'Andi Saputra' },
      { name: 'Andi Kurniawan' },
      { name: 'Budi Santoso' },
    ];

    const result = controller.resolveContact('Andi', contacts);
    expect(result.exactMatch).toBeUndefined();
    expect(result.candidates.length).toBe(3);
  });
});
