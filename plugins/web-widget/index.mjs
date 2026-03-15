export function createPlugin(context) {
  return {
    async start() {
      context.log("info", "Web widget ready");
    },
    async getSnapshot() {
      const settings = context.getPluginSettings()?.webWidget ?? {};
      const title = settings.title || "Web Widget";
      const subtitle = settings.subtitle || "Embedded dashboard";
      const urlString = settings.urlString || "https://calendar.google.com";

      return {
        status: "running",
        surface: {
          kind: "webWidget",
          title,
          subtitle,
          detail: urlString,
          theme: {
            accentHex: "#8EC5FF",
            backgroundHex: "#08131D",
            foregroundHex: "#F6FAFF"
          },
          metrics: [],
          actions: [],
          media: null,
          hourlyForecast: [],
          dailyForecast: []
        },
        diagnostics: {
          summary: "Healthy",
          detail: `Loading ${urlString}`,
          lastError: null
        }
      };
    }
  };
}
