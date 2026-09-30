import { execFile } from 'child_process';
import { promisify } from 'util';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@kacung/types';
import { toolSafety } from '../safety/policy.js';

const execFileAsync = promisify(execFile);

export interface VolumeParams {
  action: 'set' | 'up' | 'down' | 'mute' | 'unmute' | 'get';
  level?: number;
  step?: number;
}

export interface VolumeResultData {
  previousVolume?: number;
  currentVolume: number;
  isMuted: boolean;
  message: string;
}

export const setVolumeTool: ToolDefinition<VolumeParams, VolumeResultData> = {
  name: 'set_volume',
  description:
    'Controls macOS system volume. Supports lowering volume (down), increasing volume (up), setting exact volume percentage (set), muting, unmuting, and reading current volume.',
  permissionLevel: 'SAFE',
  safety: toolSafety('reversible', { supportsSandbox: true }),
  parameters: {
    type: 'object',
    properties: {
      action: {
        type: 'string',
        enum: ['set', 'up', 'down', 'mute', 'unmute', 'get'],
        description: 'The volume control action to perform.',
      },
      level: {
        type: 'number',
        description: 'Target volume level percentage from 0 to 100 (used when action is "set").',
      },
      step: {
        type: 'number',
        description: 'Number of percentage points to raise or lower the volume (default: 15).',
      },
    },
    required: ['action'],
  },
  async execute(params: VolumeParams, context: ToolExecutionContext): Promise<ToolResult<VolumeResultData>> {
    const action = params.action || 'get';
    const step = typeof params.step === 'number' && params.step > 0 ? params.step : 15;

    context.logger.info(`System volume action: ${action}`);

    try {
      // 1. Get current volume settings first
      const { stdout: currentOut } = await execFileAsync('osascript', ['-e', 'get volume settings']);
      // Format: "output volume:73, input volume:24, alert volume:100, output muted:false"
      const volMatch = currentOut.match(/output volume:(\d+)/);
      const muteMatch = currentOut.match(/output muted:(true|false)/);

      const prevVol = volMatch ? parseInt(volMatch[1], 10) : 50;
      let isMuted = muteMatch ? muteMatch[1] === 'true' : false;
      let targetVol = prevVol;

      if (action === 'down') {
        targetVol = Math.max(0, prevVol - step);
        await execFileAsync('osascript', ['-e', `set volume output volume ${targetVol}`]);
        if (isMuted) {
          await execFileAsync('osascript', ['-e', 'set volume output muted false']);
          isMuted = false;
        }
      } else if (action === 'up') {
        targetVol = Math.min(100, prevVol + step);
        await execFileAsync('osascript', ['-e', `set volume output volume ${targetVol}`]);
        if (isMuted) {
          await execFileAsync('osascript', ['-e', 'set volume output muted false']);
          isMuted = false;
        }
      } else if (action === 'set') {
        const desiredLevel = typeof params.level === 'number' ? Math.max(0, Math.min(100, params.level)) : 50;
        targetVol = desiredLevel;
        await execFileAsync('osascript', ['-e', `set volume output volume ${targetVol}`]);
        if (isMuted) {
          await execFileAsync('osascript', ['-e', 'set volume output muted false']);
          isMuted = false;
        }
      } else if (action === 'mute') {
        await execFileAsync('osascript', ['-e', 'set volume output muted true']);
        isMuted = true;
      } else if (action === 'unmute') {
        await execFileAsync('osascript', ['-e', 'set volume output muted false']);
        isMuted = false;
      }

      // Check final volume
      const { stdout: finalOut } = await execFileAsync('osascript', ['-e', 'get volume settings']);
      const finalVolMatch = finalOut.match(/output volume:(\d+)/);
      const finalMuteMatch = finalOut.match(/output muted:(true|false)/);
      const currentVolume = finalVolMatch ? parseInt(finalVolMatch[1], 10) : targetVol;
      const finalMuted = finalMuteMatch ? finalMuteMatch[1] === 'true' : isMuted;

      let message = '';
      if (action === 'down') {
        message = `Volume diturunkan dari ${prevVol}% ke ${currentVolume}%.`;
      } else if (action === 'up') {
        message = `Volume dinaikkan dari ${prevVol}% ke ${currentVolume}%.`;
      } else if (action === 'set') {
        message = `Volume disetel ke ${currentVolume}%.`;
      } else if (action === 'mute') {
        message = `Audio dimatikan (mute).`;
      } else if (action === 'unmute') {
        message = `Audio dinyalakan kembali pada level ${currentVolume}%.`;
      } else {
        message = `Level volume saat ini: ${currentVolume}%.`;
      }

      return {
        success: true,
        data: {
          previousVolume: prevVol,
          currentVolume,
          isMuted: finalMuted,
          message,
        },
      };
    } catch (err: unknown) {
      const errMsg = err instanceof Error ? err.message : String(err);
      context.logger.error(`Volume control failed: ${errMsg}`);
      return {
        success: false,
        error: `Gagal mengatur volume sistem: ${errMsg}`,
      };
    }
  },
};
