function formatUptime(seconds) {
  const safe = Math.max(0, Math.floor(seconds));
  const days = Math.floor(safe / 86400);
  const hours = Math.floor((safe % 86400) / 3600);
  const minutes = Math.floor((safe % 3600) / 60);
  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

function fallbackSnapshot() {
  return {
    status: "degraded",
    surface: {
      kind: "systemStats",
      title: "System",
      subtitle: "Waiting for host metrics",
      detail: "The native host has not published system metrics yet.",
      theme: {
        accentHex: "#70F0C8",
        backgroundHex: "#07161C",
        foregroundHex: "#F7FEFF"
      },
      metrics: [],
      actions: [],
      media: null,
      hourlyForecast: [],
      dailyForecast: []
    },
    diagnostics: {
      summary: "Waiting for host",
      detail: null,
      lastError: null
    }
  };
}

export function createPlugin(context) {
  return {
    async start() {
      context.log("info", "System stats ready");
    },
    async getSnapshot() {
      const stats = context.getHostMetrics?.();
      if (!stats) {
        return fallbackSnapshot();
      }

      return {
        status: "running",
        surface: {
          kind: "systemStats",
          title: "System",
          subtitle: `${stats.cpuBrand} • ${stats.gpuName}`,
          detail: "Metrics are sampled natively by the host and pushed into the plugin runtime. No subprocess probes run inside this plugin.",
          theme: {
            accentHex: "#70F0C8",
            backgroundHex: "#07161C",
            foregroundHex: "#F7FEFF"
          },
          metrics: [
            {
              id: "cpu-load",
              label: "CPU Load",
              value: stats.cpuLoadPercent,
              unit: "%",
              target: 100,
              displayValue: `${Math.round(stats.cpuLoadPercent)}%`
            },
            {
              id: "perf-cores",
              label: "P Cores",
              value: stats.performanceCoreCount,
              unit: "cores",
              target: Math.max(stats.performanceCoreCount, 1),
              displayValue: `${stats.performanceCoreCount}`
            },
            {
              id: "efficiency-cores",
              label: "E Cores",
              value: stats.efficiencyCoreCount,
              unit: "cores",
              target: Math.max(stats.efficiencyCoreCount, 1),
              displayValue: `${stats.efficiencyCoreCount}`
            },
            {
              id: "memory-used",
              label: "Memory",
              value: stats.memoryUsedPercent,
              unit: "%",
              target: 100,
              displayValue: `${stats.memoryUsedGB.toFixed(1)} / ${stats.memoryTotalGB.toFixed(0)} GB`
            },
            {
              id: "memory-pressure",
              label: "Pressure",
              value: stats.memoryPressurePercent,
              unit: "%",
              target: 100,
              displayValue: `${Math.round(stats.memoryPressurePercent)}%`
            },
            {
              id: "swap-used",
              label: "Swap",
              value: Math.min(stats.swapUsedMB, 8192),
              unit: "MB",
              target: 8192,
              displayValue: `${Math.round(stats.swapUsedMB)} MB`
            },
            {
              id: "storage-used",
              label: "Storage",
              value: stats.storageUsedPercent,
              unit: "%",
              target: 100,
              displayValue: `${stats.storageUsedGB.toFixed(0)} / ${stats.storageTotalGB.toFixed(0)} GB`
            },
            {
              id: "uptime",
              label: "Uptime",
              value: Math.min(stats.uptimeSeconds / 3600, 240),
              unit: "hours",
              target: 240,
              displayValue: formatUptime(stats.uptimeSeconds)
            }
          ],
          actions: [],
          media: null,
          hourlyForecast: [],
          dailyForecast: []
        },
        diagnostics: {
          summary: "Healthy",
          detail: `Thermal: ${stats.thermalState}. CPU split: ${stats.performanceCoreCount}P/${stats.efficiencyCoreCount}E.`,
          lastError: null
        }
      };
    },
    async performAction() {}
  };
}
