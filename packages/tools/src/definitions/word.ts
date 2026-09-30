import { execFile } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';
import os from 'os';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@lafly/types';
import { toolSafety } from '../safety/policy.js';

const execFileAsync = promisify(execFile);

export interface WriteWordDocumentParams {
  title?: string;
  content: string;
  createNew?: boolean;
}

export interface WriteWordDocumentResultData {
  app: string;
  documentTitle: string;
  wordCount: number;
  message: string;
}

export const writeWordDocumentTool: ToolDefinition<WriteWordDocumentParams, WriteWordDocumentResultData> = {
  name: 'write_word_document',
  description:
    'Writes or types research findings, summaries, notes, or essays directly into Microsoft Word (or Pages/TextEdit as fallback). Creates a new document or appends to an active document.',
  permissionLevel: 'SAFE',
  safety: toolSafety('reversible', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      title: {
        type: 'string',
        description: 'Document heading or title (e.g. "Riset Bahaya Merokok bagi Kesehatan").',
      },
      content: {
        type: 'string',
        description: 'The body text, research conclusions, or bullet points to type into the document.',
      },
      createNew: {
        type: 'boolean',
        description: 'Whether to create a new blank document before typing (default: true).',
      },
    },
    required: ['content'],
  },
  async execute(
    params: WriteWordDocumentParams,
    context: ToolExecutionContext
  ): Promise<ToolResult<WriteWordDocumentResultData>> {
    const title = params.title || 'Dokumen Baru';
    const content = params.content || '';
    const createNew = params.createNew !== false;

    context.logger.info(`Writing document: "${title}" (length: ${content.length} chars)`);

    // Prepare full text payload with formatted header
    let fullText = '';
    if (params.title) {
      fullText = `${title.toUpperCase()}\n==============================\n\n${content}`;
    } else {
      fullText = content;
    }

    const tempFilePath = path.join(os.tmpdir(), `lafly-word-${Date.now()}.txt`);

    try {
      fs.writeFileSync(tempFilePath, fullText, 'utf8');

      // 1. Check if Microsoft Word is installed
      const isWordInstalled = fs.existsSync('/Applications/Microsoft Word.app');

      if (isWordInstalled) {
        const wordScript = `
          tell application "Microsoft Word"
            activate
            ${createNew ? 'set targetDoc to make new document' : 'set targetDoc to active document'}
            set textObj to text object of targetDoc
            set docContent to (read POSIX file "${tempFilePath}" as «class utf8»)
            set content of textObj to docContent
            return "word_success"
          end tell
        `;

        try {
          await execFileAsync('osascript', ['-e', wordScript]);
          const wordCount = fullText.split(/\s+/).filter(Boolean).length;
          return {
            success: true,
            data: {
              app: 'Microsoft Word',
              documentTitle: title,
              wordCount,
              message: `Berhasil menulis kesimpulan "${title}" ke dalam Microsoft Word (${wordCount} kata).`,
            },
          };
        } catch (wordErr) {
          context.logger.warn(`Microsoft Word script failed, attempting fallback: ${wordErr}`);
        }
      }

      // 2. Fallback to Apple Pages
      const isPagesInstalled = fs.existsSync('/Applications/Pages.app');
      if (isPagesInstalled) {
        const pagesScript = `
          tell application "Pages"
            activate
            set newDoc to make new document
            set body text of newDoc to (read POSIX file "${tempFilePath}" as «class utf8»)
            return "pages_success"
          end tell
        `;
        try {
          await execFileAsync('osascript', ['-e', pagesScript]);
          const wordCount = fullText.split(/\s+/).filter(Boolean).length;
          return {
            success: true,
            data: {
              app: 'Pages',
              documentTitle: title,
              wordCount,
              message: `Berhasil menulis kesimpulan "${title}" ke dalam Pages (${wordCount} kata).`,
            },
          };
        } catch (pagesErr) {
          context.logger.warn(`Pages fallback script failed: ${pagesErr}`);
        }
      }

      // 3. Fallback to TextEdit
      const textEditScript = `
        tell application "TextEdit"
          activate
          set newDoc to make new document
          set text of newDoc to (read POSIX file "${tempFilePath}" as «class utf8»)
          return "textedit_success"
        end tell
      `;
      await execFileAsync('osascript', ['-e', textEditScript]);
      const wordCount = fullText.split(/\s+/).filter(Boolean).length;
      return {
        success: true,
        data: {
          app: 'TextEdit',
          documentTitle: title,
          wordCount,
          message: `Berhasil menulis kesimpulan "${title}" ke dalam TextEdit (${wordCount} kata).`,
        },
      };
    } catch (err: unknown) {
      const errMsg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Failed to write document: ${errMsg}`);
      return {
        success: false,
        error: `Gagal menulis dokumen: ${errMsg}`,
      };
    } finally {
      try {
        if (fs.existsSync(tempFilePath)) {
          fs.unlinkSync(tempFilePath);
        }
      } catch {}
    }
  },
};
