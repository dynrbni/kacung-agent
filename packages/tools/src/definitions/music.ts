import { execFile } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import type { ToolDefinition, ToolExecutionContext, ToolResult } from '@kacung/types';

const execFileAsync = promisify(execFile);

export interface PlayMusicParams {
  query: string;
  app?: 'auto' | 'music' | 'spotify';
}

export interface PlayMusicResultData {
  app: string;
  query: string;
  action: 'playing_library' | 'catalog_search' | 'spotify_app' | 'spotify_web';
  message: string;
}

/**
 * Checks whether Spotify application is installed on this Mac.
 */
async function isSpotifyInstalled(): Promise<boolean> {
  const commonPaths = [
    '/Applications/Spotify.app',
    `${process.env.HOME}/Applications/Spotify.app`,
  ];
  for (const p of commonPaths) {
    if (fs.existsSync(p)) return true;
  }

  try {
    const { stdout } = await execFileAsync('mdfind', [
      "kMDItemCFBundleIdentifier == 'com.spotify.client'",
    ]);
    return stdout.trim().length > 0;
  } catch {
    return false;
  }
}

export const playMusicTool: ToolDefinition<PlayMusicParams, PlayMusicResultData> = {
  name: 'play_music',
  description:
    'Searches and plays a song, artist, album, or playlist in Apple Music or Spotify on macOS.',
  permissionLevel: 'SAFE',
  parameters: {
    type: 'object',
    properties: {
      query: {
        type: 'string',
        description: 'The song title, artist, or keywords to search and play (e.g. "The Weeknd Starboy", "Bohemian Rhapsody", "Tulus").',
      },
      app: {
        type: 'string',
        enum: ['auto', 'music', 'spotify'],
        description: 'Target music player ("music" for Apple Music, "spotify" for Spotify, or "auto" to automatically pick). Default: "auto".',
      },
    },
    required: ['query'],
  },
  validate(params: unknown) {
    if (!params || typeof params !== 'object') {
      return { valid: false, error: 'Parameters must be an object' };
    }
    const p = params as Record<string, unknown>;
    if (!p.query || typeof p.query !== 'string' || !p.query.trim()) {
      return { valid: false, error: 'query is required and must be a non-empty string' };
    }
    return { valid: true };
  },
  async execute(
    params: PlayMusicParams,
    context: ToolExecutionContext
  ): Promise<ToolResult<PlayMusicResultData>> {
    const query = params.query.trim();
    let targetApp = params.app || 'auto';

    // Auto-detect target based on user keywords if set to auto
    if (targetApp === 'auto') {
      const lower = query.toLowerCase();
      if (lower.includes('spotify')) {
        targetApp = 'spotify';
      } else {
        targetApp = 'music';
      }
    }

    context.logger.info(`play_music requested for "${query}" on target: ${targetApp}`);

    // Clean query from player names (e.g. "di spotify", "in apple music")
    const cleanQuery = query
      .replace(/\b(di|in|on)\s+(spotify|apple\s*music|music)\b/gi, '')
      .replace(/\b(spotify|apple\s*music)\b/gi, '')
      .trim();

    // 1. SPOTIFY HANDLING
    if (targetApp === 'spotify') {
      const hasSpotify = await isSpotifyInstalled();

      if (hasSpotify) {
        try {
          // Open Spotify with search query URI
          await execFileAsync('open', [`spotify:search:${encodeURIComponent(cleanQuery)}`]);
          return {
            success: true,
            data: {
              app: 'Spotify',
              query: cleanQuery,
              action: 'spotify_app',
              message: `Membuka dan mencari "${cleanQuery}" di aplikasi Spotify.`,
            },
          };
        } catch (err) {
          const msg = err instanceof Error ? err.message : String(err);
          context.logger.warn(`Failed to open Spotify URI: ${msg}`);
        }
      }

      // Fallback to Spotify Web if app not installed or failed
      const webUrl = `https://open.spotify.com/search/${encodeURIComponent(cleanQuery)}`;
      try {
        await execFileAsync('open', [webUrl]);
        return {
          success: true,
          data: {
            app: 'Spotify Web',
            query: cleanQuery,
            action: 'spotify_web',
            message: `Aplikasi Spotify belum terpasang, membuka "${cleanQuery}" di Spotify Web browser.`,
          },
        };
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        return {
          success: false,
          error: `Gagal membuka Spotify Web: ${msg}`,
        };
      }
    }

    // 2. APPLE MUSIC HANDLING (Default & macOS Native)
    try {
      // Step A: Check if song exists in local user's library and play directly
      const safeQueryForAppleScript = cleanQuery.replace(/"/g, '\\"');
      const script = `
        tell application "Music"
          activate
          set searchResults to (search playlist 1 for "${safeQueryForAppleScript}")
          if (count of searchResults) > 0 then
            play (item 1 of searchResults)
            return "playing_library"
          else
            return "not_in_library"
          end if
        end tell
      `;

      const { stdout } = await execFileAsync('osascript', ['-e', script]);
      const status = stdout.trim();

      if (status === 'playing_library') {
        return {
          success: true,
          data: {
            app: 'Apple Music',
            query: cleanQuery,
            action: 'playing_library',
            message: `Memutar "${cleanQuery}" langsung dari perpustakaan Apple Music.`,
          },
        };
      }
    } catch (err) {
      context.logger.warn(`Local Music library check skipped: ${err}`);
    }

    // Step B: If not in local library, open Apple Music catalog search URL
    try {
      const appleMusicUrl = `music://music.apple.com/search?term=${encodeURIComponent(cleanQuery)}`;
      await execFileAsync('open', [appleMusicUrl]);
      return {
        success: true,
        data: {
          app: 'Apple Music',
          query: cleanQuery,
          action: 'catalog_search',
          message: `Mencari dan membuka "${cleanQuery}" di Apple Music katalog.`,
        },
      };
    } catch (openErr) {
      const msg = openErr instanceof Error ? openErr.message : String(openErr);
      return {
        success: false,
        error: `Gagal membuka Apple Music: ${msg}`,
      };
    }
  },
};

export const searchMusicTool: ToolDefinition<PlayMusicParams, PlayMusicResultData> = {
  ...playMusicTool,
  name: 'search_music',
  description: 'Searches for songs, albums, or artists in Apple Music or Spotify on macOS.',
};
