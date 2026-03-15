import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const launcherItems = [
  { id: "open-spotify", title: "Spotify", icon: "music.note", role: "App", type: "app", value: "Spotify" },
  { id: "open-safari", title: "Safari", icon: "safari.fill", role: "App", type: "app", value: "Safari" },
  { id: "open-activity-monitor", title: "Activity Monitor", icon: "waveform.path.ecg", role: "App", type: "app", value: "Activity Monitor" },
  { id: "open-discord", title: "Discord", icon: "bubble.left.and.bubble.right.fill", role: "App", type: "app", value: "Discord" },
  { id: "open-corsair", title: "CORSAIR", icon: "globe", role: "URL", type: "url", value: "https://www.corsair.com/us/en/explorer/" },
  { id: "open-downloads", title: "Downloads", icon: "folder.fill", role: "Folder", type: "path", value: "~/Downloads" }
];

async function openLauncherItem(item) {
  if (item.type === "app") {
    await execFileAsync("open", ["-a", item.value]);
    return;
  }
  if (item.type === "url") {
    await execFileAsync("open", [item.value]);
    return;
  }
  if (item.type === "path") {
    await execFileAsync("open", [item.value.replace(/^~(?=\/)/, process.env.HOME || "~")]);
  }
}

export function createPlugin(context) {
  return {
    async start() {
      context.log("info", "Launcher plugin ready");
    },
    async getSnapshot() {
      return {
        status: "running",
        surface: {
          kind: "launcher",
          title: "Launch",
          subtitle: "Apps, sites, and quick tools",
          detail: "Quick access shortcuts intended for a dedicated control-surface page.",
          theme: {
            accentHex: "#F0B676",
            backgroundHex: "#1A120A",
            foregroundHex: "#FFF8F1"
          },
          metrics: [],
          actions: launcherItems.map(({ id, title, icon, role }) => ({ id, title, icon, role })),
          media: null,
          hourlyForecast: [],
          dailyForecast: []
        },
        diagnostics: {
          summary: "Healthy",
          detail: `${launcherItems.length} launcher targets configured`,
          lastError: null
        }
      };
    },
    async performAction(action) {
      const item = launcherItems.find((candidate) => candidate.id === action.actionID);
      if (!item) return;

      try {
        await openLauncherItem(item);
      } catch (error) {
        context.log("error", "Launcher action failed", { action: action.actionID, error: error.message });
      }
    }
  };
}
