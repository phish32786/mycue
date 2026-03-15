export function createPlugin(context) {
  return {
    async start() {
      context.log("info", "Media gallery ready");
    },
    async getSnapshot() {
      const settings = context.getPluginSettings()?.mediaGallery ?? {};
      const title = settings.title || "Gallery";
      const subtitle = settings.subtitle || "Local media rotation";
      const folderPath = settings.folderPath || "";

      return {
        status: "running",
        surface: {
          kind: "mediaGallery",
          title,
          subtitle,
          detail: folderPath || "Choose a local folder in Settings",
          theme: {
            accentHex: "#F7B66D",
            backgroundHex: "#17110B",
            foregroundHex: "#FFF8F1"
          },
          metrics: [],
          actions: [],
          media: null,
          hourlyForecast: [],
          dailyForecast: []
        },
        diagnostics: {
          summary: "Healthy",
          detail: folderPath ? `Loading media from ${folderPath}` : "No folder selected",
          lastError: null
        }
      };
    }
  };
}
