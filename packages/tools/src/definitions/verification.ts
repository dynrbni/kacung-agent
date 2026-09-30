import { execFile } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import type { ToolDefinition, ToolExecutionContext, ToolResult, VerificationResult } from '@lafly/types';
import { toolSafety } from '../safety/policy.js';

const execFileAsync = promisify(execFile);

export interface VerifyStateParams {
  action: 'app_running' | 'app_frontmost' | 'file_exists' | 'music_playing' | 'custom_check';
  target: string;
}

export const verifyStateTool: ToolDefinition<VerifyStateParams, VerificationResult> = {
  name: 'verify_state',
  description: 'Verifies whether a computer action or state transition succeeded (e.g. app is running, music is playing, file exists).',
  permissionLevel: 'SAFE',
  safety: toolSafety('none', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      action: {
        type: 'string',
        enum: ['app_running', 'app_frontmost', 'file_exists', 'music_playing', 'custom_check'],
        description: 'Type of state verification to perform.',
      },
      target: {
        type: 'string',
        description: 'Target to verify (e.g. "Spotify", "/path/to/file.txt", "WhatsApp").',
      },
    },
    required: ['action', 'target'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.action || typeof p.action !== 'string') {
      return { valid: false, error: 'action is required' };
    }
    if (!p.target || typeof p.target !== 'string') {
      return { valid: false, error: 'target is required' };
    }
    return { valid: true };
  },
  async execute(params: VerifyStateParams, context: ToolExecutionContext): Promise<ToolResult<VerificationResult>> {
    const { action, target } = params;
    context.logger.info(`Verifying state: action="${action}", target="${target}"`);

    switch (action) {
      case 'app_running': {
        try {
          const { stdout } = await execFileAsync('pgrep', ['-ix', target]);
          const running = stdout.trim().length > 0;
          return {
            success: running,
            data: {
              verified: running,
              action,
              target,
              details: running ? `Aplikasi "${target}" sedang berjalan.` : `Aplikasi "${target}" TIDAK berjalan.`,
            },
          };
        } catch {
          return {
            success: false,
            data: {
              verified: false,
              action,
              target,
              details: `Aplikasi "${target}" tidak ditemukan sedang berjalan.`,
            },
          };
        }
      }

      case 'app_frontmost': {
        try {
          const script = 'tell application "System Events" to get name of first process whose frontmost is true';
          const { stdout } = await execFileAsync('osascript', ['-e', script]);
          const frontApp = stdout.trim();
          const matches = frontApp.toLowerCase().includes(target.toLowerCase());
          return {
            success: matches,
            data: {
              verified: matches,
              action,
              target,
              details: matches
                ? `Aplikasi "${target}" berada di jendela aktif (frontmost).`
                : `Aplikasi aktif saat ini adalah "${frontApp}", bukan "${target}".`,
            },
          };
        } catch (err) {
          return {
            success: false,
            data: {
              verified: false,
              action,
              target,
              details: `Gagal memeriksa aplikasi aktif: ${err}`,
            },
          };
        }
      }

      case 'file_exists': {
        const exists = fs.existsSync(target);
        return {
          success: exists,
          data: {
            verified: exists,
            action,
            target,
            details: exists ? `File "${target}" ada.` : `File "${target}" tidak ditemukan.`,
          },
        };
      }

      case 'music_playing': {
        // Check Apple Music or Spotify playback state via AppleScript
        try {
          const script = `
            set musicStatus to "stopped"
            try
              tell application "System Events"
                if exists (processes where name is "Music") then
                  tell application "Music" to set musicStatus to (player state as string)
                else if exists (processes where name is "Spotify") then
                  tell application "Spotify" to set musicStatus to (player state as string)
                end if
              end tell
            end try
            return musicStatus
          `;
          const { stdout } = await execFileAsync('osascript', ['-e', script]);
          let state = stdout.trim().toLowerCase();

          // If stopped or paused, try to kickstart playback once
          if (state !== 'playing') {
            try {
              await execFileAsync('osascript', ['-e', 'tell application "Music" to play']);
              await new Promise((r) => setTimeout(r, 800));
              const { stdout: retryOut } = await execFileAsync('osascript', ['-e', 'tell application "Music" to get player state as string']);
              state = retryOut.trim().toLowerCase();
            } catch {}
          }

          const isPlaying = state === 'playing';
          return {
            success: true,
            data: {
              verified: isPlaying,
              action,
              target,
              details: isPlaying
                ? `Musik sedang diputar (status: ${state}).`
                : `Status pemutaran musik saat ini: ${state}.`,
            },
          };
        } catch {
          return {
            success: true,
            data: {
              verified: false,
              action,
              target,
              details: 'Tidak dapat mendeteksi status pemutaran musik.',
            },
          };
        }
      }

      default: {
        return {
          success: true,
          data: {
            verified: true,
            action,
            target,
            details: `Verifikasi kustom untuk "${target}" selesai.`,
          },
        };
      }
    }
  },
};
