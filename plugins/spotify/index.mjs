import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

async function runAppleScript(lines) {
  const args = lines.flatMap((line) => ["-e", line]);
  const { stdout } = await execFileAsync("osascript", args);
  return stdout.trim();
}

async function readSpotifyState() {
  try {
    const state = await runAppleScript([
      'if application "Spotify" is running then',
      'tell application "Spotify"',
      'set trackID to id of current track',
      'set trackName to name of current track',
      'set artistName to artist of current track',
      'set albumName to album of current track',
      'set artworkURL to artwork url of current track',
      'set durationMs to duration of current track',
      'set playerState to player state as string',
      'set playerPosition to player position',
      'set soundVolume to sound volume',
      'return trackID & "||" & trackName & "||" & artistName & "||" & albumName & "||" & artworkURL & "||" & durationMs & "||" & playerState & "||" & playerPosition & "||" & soundVolume',
      'end tell',
      'else',
      'return "offline"',
      'end if'
    ]);

    if (state === "offline") return null;
    const [trackID, title, artist, album, artworkURL, durationMs, playerState, playerPosition, soundVolume] = state.split("||");
    const duration = Number(durationMs) / 1000;
    const elapsed = Number(playerPosition);
    const progress = duration > 0 ? elapsed / duration : 0;
    return {
      trackID,
      title,
      artist,
      album,
      artworkURL: artworkURL || null,
      duration,
      elapsed,
      progress,
      state: playerState,
      isPlaying: playerState === "playing",
      volume: Number(soundVolume) / 100
    };
  } catch (error) {
    return {
      error: error.message
    };
  }
}

function formatTime(seconds) {
  const safe = Math.max(0, Math.floor(seconds));
  const minutes = Math.floor(safe / 60);
  const remainder = `${safe % 60}`.padStart(2, "0");
  return `${minutes}:${remainder}`;
}

function fallbackState() {
  return {
    trackID: null,
    title: "Open Spotify",
    artist: "Desktop client not running",
    album: "MyCue",
    artworkURL: null,
    duration: 240,
    elapsed: 0,
    progress: 0,
    state: "offline",
    isPlaying: false,
    volume: 0.7
  };
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

export function createPlugin(context) {
  let cached = fallbackState();

  return {
    async start() {
      context.log("info", "Spotify plugin ready");
    },
    async getSnapshot() {
      const next = await readSpotifyState();
      if (next?.error) {
        context.log("error", "Spotify state read failed", { error: next.error });
      }
      cached = next && !next.error ? next : fallbackState();
      const connected = cached.state !== "offline";

      return {
        status: connected ? "running" : "degraded",
        surface: {
          kind: "spotify",
          title: connected ? cached.title : "Spotify",
          subtitle: connected ? `${cached.artist} • ${cached.album}` : "Desktop client unavailable",
          detail: connected
            ? `${cached.isPlaying ? "Playing" : "Paused"} on Spotify Desktop`
            : "Open the Spotify desktop client on this Mac to enable transport and volume control.",
          theme: {
            accentHex: "#4DDB75",
            backgroundHex: "#08140B",
            foregroundHex: "#F8FFF8"
          },
          metrics: [],
          actions: [
            { id: "previousTrack", title: "Previous", icon: "backward.fill", role: null },
            { id: "playPause", title: cached.isPlaying ? "Pause" : "Play", icon: cached.isPlaying ? "pause.fill" : "play.fill", role: null },
            { id: "nextTrack", title: "Next", icon: "forward.fill", role: null },
            { id: "volumeDown", title: "Volume Down", icon: "speaker.wave.1.fill", role: null },
            { id: "volumeUp", title: "Volume Up", icon: "speaker.wave.3.fill", role: null }
          ],
          media: {
            title: cached.title,
            artist: cached.artist,
            album: cached.album,
            progress: cached.progress,
            durationText: formatTime(cached.duration),
            elapsedText: formatTime(cached.elapsed),
            artworkURL: cached.artworkURL,
            isPlaying: cached.isPlaying,
            volume: cached.volume,
            deviceName: connected ? "Spotify Desktop" : "This Mac"
          },
          hourlyForecast: [],
          dailyForecast: []
        },
        diagnostics: {
          summary: connected ? "Healthy" : "Desktop client unavailable",
          detail: connected ? `Track ID: ${cached.trackID ?? "unknown"}` : null,
          lastError: next?.error ?? null
        }
      };
    },
    async performAction(action) {
      const transportCommands = {
        playPause: "playpause",
        nextTrack: "next track",
        previousTrack: "previous track"
      };

      if (action.actionID in transportCommands) {
        try {
          await runAppleScript([
            'if application "Spotify" is running then',
            `tell application "Spotify" to ${transportCommands[action.actionID]}`,
            'end if'
          ]);
        } catch (error) {
          context.log("error", "Spotify transport action failed", { action: action.actionID, error: error.message });
        }
        return;
      }

      if (action.actionID === "volumeDown" || action.actionID === "volumeUp") {
        const delta = action.actionID === "volumeDown" ? -8 : 8;
        const current = Math.round((cached.volume ?? 0.7) * 100);
        const nextVolume = clamp(current + delta, 0, 100);
        try {
          await runAppleScript([
            'if application "Spotify" is running then',
            `tell application "Spotify" to set sound volume to ${nextVolume}`,
            'end if'
          ]);
          cached.volume = nextVolume / 100;
        } catch (error) {
          context.log("error", "Spotify volume action failed", { action: action.actionID, error: error.message });
        }
      }
    }
  };
}
