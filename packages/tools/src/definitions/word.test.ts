import { describe, it, expect } from 'vitest';
import { writeWordDocumentTool } from './word.js';

describe('Word Document Tool', () => {
  it('should have correct name and parameters definition', () => {
    expect(writeWordDocumentTool.name).toBe('write_word_document');
    expect(writeWordDocumentTool.permissionLevel).toBe('SAFE');
    expect(writeWordDocumentTool.parameters.required).toContain('content');
  });
});
