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
  trackName?: string;
  artistName?: string;
  action: 'playing_library' | 'playing_catalog' | 'catalog_search' | 'spotify_app' | 'spotify_web';
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

/**
 * Searches Apple Music catalog via official iTunes Search API.
 */
async function searchAppleMusicCatalog(query: string): Promise<{ trackName: string; artistName: string; trackUrl: string } | null> {
  try {
    const apiUrl = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&entity=song&limit=1`;
    const res = await fetch(apiUrl, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return null;
    const data = await res.json() as { results?: Array<{ trackName?: string; artistName?: string; trackViewUrl?: string }> };
    const first = data.results?.[0];
    if (first && first.trackViewUrl) {
      return {
        trackName: first.trackName || query,
        artistName: first.artistName || '',
        trackUrl: first.trackViewUrl,
      };
    }
  } catch {}
  return null;
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
          await execFileAsync('open', [`spotify:search:${encodeURIComponent(cleanQuery)}`]);
          // Short delay then send play command
          await new Promise((r) => setTimeout(r, 800));
          try {
            await execFileAsync('osascript', ['-e', 'tell application "Spotify" to play']);
          } catch {}

          return {
            success: true,
            data: {
              app: 'Spotify',
              query: cleanQuery,
              action: 'spotify_app',
              message: `Membuka dan memutar "${cleanQuery}" di aplikasi Spotify.`,
            },
          };
        } catch (err) {
          const msg = err instanceof Error ? err.message : String(err);
          context.logger.warn(`Failed to open Spotify URI: ${msg}`);
        }
      }

      // Fallback to Spotify Web if app not installed
      const webUrl = `https://open.spotify.com/search/${encodeURIComponent(cleanQuery)}`;
      try {
        await execFileAsync('open', [webUrl]);
        return {
          success: true,
          data: {
            app: 'Spotify Web',
            query: cleanQuery,
            action: 'spotify_web',
            message: `Aplikasi Spotify belum terpasang di Mac, membuka lagu "${cleanQuery}" di Spotify Web browser.`,
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

    // 2. APPLE MUSIC HANDLING (Native macOS Player)
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

    // Step B: Search catalog via iTunes Search API to get exact track deep link
    const catalogMatch = await searchAppleMusicCatalog(cleanQuery);
    if (catalogMatch && catalogMatch.trackUrl) {
      try {
        // 1. Pause any currently playing track first so player does not resume previous song
        try {
          await execFileAsync('osascript', ['-e', 'tell application "Music" to pause']);
        } catch {}

        // 2. Open new track/album deep link
        const nativeUrl = catalogMatch.trackUrl.replace(/^https?:\/\//i, 'music://');
        context.logger.info(`Opening Apple Music deep link: ${nativeUrl}`);
        await execFileAsync('open', [nativeUrl]);

        // 3. Wait for Music app to load and render the new album view
        await new Promise((r) => setTimeout(r, 1400));

        // 4. Click the "Play" button in the album details view to start playing the new song
        const clickPlayScript = `
          tell application "Music" to activate
          delay 0.4
          tell application "System Events"
            tell process "Music"
              set frontmost to true
              try
                set sg to first UI element of front window whose role is "AXSplitGroup"
                repeat with el in every UI element of sg
                  try
                    if description of el is "album details" then
                      repeat with b in every button of el
                        try
                          if description of b is "play" or name of b is "Play" then
                            click b
                            return "clicked_play"
                          end if
                        end try
                      end repeat
                    end if
                  end try
                end repeat
              end try
              return "fallback"
            end tell
          end tell
        `;

        try {
          const { stdout: clickOut } = await execFileAsync('osascript', ['-e', clickPlayScript]);
          context.logger.info(`Apple Music play click result: ${clickOut.trim()}`);
          if (clickOut.trim() !== 'clicked_play') {
            await execFileAsync('osascript', ['-e', 'tell application "Music" to play']);
          }
        } catch {
          try {
            await execFileAsync('osascript', ['-e', 'tell application "Music" to play']);
          } catch {}
        }

        const songDisplay = catalogMatch.artistName
          ? `"${catalogMatch.trackName}" oleh ${catalogMatch.artistName}`
          : `"${catalogMatch.trackName}"`;

        return {
          success: true,
          data: {
            app: 'Apple Music',
            query: cleanQuery,
            trackName: catalogMatch.trackName,
            artistName: catalogMatch.artistName,
            action: 'playing_catalog',
            message: `Memutar ${songDisplay} di Apple Music.`,
          },
        };
      } catch (err) {
        context.logger.warn(`Failed opening deep link: ${err}`);
      }
    }

    // Step C: Fallback to general search URL if API match not found
    try {
      try {
        await execFileAsync('osascript', ['-e', 'tell application "Music" to pause']);
      } catch {}

      const appleMusicUrl = `music://music.apple.com/search?term=${encodeURIComponent(cleanQuery)}`;
      await execFileAsync('open', [appleMusicUrl]);
      await new Promise((r) => setTimeout(r, 1400));

      const fallbackClickScript = `
        tell application "Music" to activate
        delay 0.4
        tell application "System Events"
          tell process "Music"
            set frontmost to true
            try
              set sg to first UI element of front window whose role is "AXSplitGroup"
              repeat with el in every UI element of sg
                try
                  repeat with b in every button of el
                    try
                      if description of b is "play" or name of b is "Play" then
                        click b
                        return "clicked_play"
                      end if
                    end try
                  end repeat
                end try
              end repeat
            end try
            return "fallback"
          end tell
        end tell
      `;

      try {
        await execFileAsync('osascript', ['-e', fallbackClickScript]);
      } catch {
        try {
          await execFileAsync('osascript', ['-e', 'tell application "Music" to play']);
        } catch {}
      }

      return {
        success: true,
        data: {
          app: 'Apple Music',
          query: cleanQuery,
          action: 'catalog_search',
          message: `Membuka dan memutar "${cleanQuery}" di Apple Music.`,
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
