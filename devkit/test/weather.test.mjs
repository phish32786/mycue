import test from "node:test";
import assert from "node:assert/strict";
import { resolve } from "node:path";

test("weather plugin caches forecasts between snapshots", async () => {
  const modulePath = resolve(process.cwd(), "plugins/weather/index.mjs");
  const { createPlugin } = await import(`file://${modulePath}`);

  let fetchCount = 0;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    fetchCount += 1;
    return {
      ok: true,
      async json() {
        return {
          current: {
            temperature_2m: 61 + fetchCount,
            apparent_temperature: 59 + fetchCount,
            weather_code: 1,
            precipitation: 0,
            wind_speed_10m: 6,
            is_day: 1
          },
          hourly: {
            time: Array.from({ length: 5 }, (_, index) => new Date(Date.now() + index * 3600000).toISOString()),
            temperature_2m: [61, 60, 59, 58, 57],
            weather_code: [1, 1, 2, 3, 3],
            precipitation_probability: [5, 5, 10, 15, 15]
          },
          daily: {
            time: Array.from({ length: 5 }, (_, index) => new Date(Date.now() + index * 86400000).toISOString()),
            temperature_2m_max: [63, 64, 62, 60, 61],
            temperature_2m_min: [49, 50, 48, 47, 48],
            weather_code: [1, 1, 2, 61, 3],
            sunrise: Array(5).fill(new Date().toISOString()),
            sunset: Array(5).fill(new Date().toISOString())
          }
        };
      }
    };
  };

  try {
    const plugin = createPlugin({
      getLocation: () => ({ latitude: 42.3314, longitude: -83.0458 }),
      log() {}
    });

    await plugin.start();
    const first = await plugin.getSnapshot();
    assert.equal(fetchCount, 1);
    assert.deepEqual(first.surface.actions, []);

    const second = await plugin.getSnapshot();
    assert.equal(fetchCount, 1);
    assert.equal(first.surface.metrics[0].displayValue, second.surface.metrics[0].displayValue);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("weather plugin uses configured location name and metric units", async () => {
  const modulePath = resolve(process.cwd(), "plugins/weather/index.mjs");
  const { createPlugin } = await import(`file://${modulePath}`);

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    assert.match(String(url), /temperature_unit=celsius/);
    assert.match(String(url), /wind_speed_unit=kmh/);
    return {
      ok: true,
      async json() {
        return {
          current: {
            temperature_2m: 18,
            apparent_temperature: 17,
            weather_code: 3,
            precipitation: 0,
            wind_speed_10m: 12,
            is_day: 1
          },
          hourly: {
            time: Array.from({ length: 5 }, (_, index) => new Date(Date.now() + index * 3600000).toISOString()),
            temperature_2m: [18, 17, 16, 15, 14],
            weather_code: [3, 3, 2, 2, 1],
            precipitation_probability: [20, 20, 10, 10, 5]
          },
          daily: {
            time: Array.from({ length: 5 }, (_, index) => new Date(Date.now() + index * 86400000).toISOString()),
            temperature_2m_max: [19, 20, 18, 17, 18],
            temperature_2m_min: [12, 11, 10, 9, 10],
            weather_code: [3, 0, 61, 71, 2],
            sunrise: Array(5).fill(new Date().toISOString()),
            sunset: Array(5).fill(new Date().toISOString())
          }
        };
      }
    };
  };

  try {
    const plugin = createPlugin({
      getLocation: () => ({ latitude: 0, longitude: 0 }),
      getPluginSettings: () => ({
        weather: {
          locationName: "Toronto",
          latitude: 43.6532,
          longitude: -79.3832,
          unitPreference: "metric"
        }
      }),
      log() {}
    });

    const snapshot = await plugin.getSnapshot();
    assert.equal(snapshot.surface.title, "Toronto");
    assert.equal(snapshot.surface.metrics[0].unit, "C");
    assert.match(snapshot.diagnostics.detail, /Toronto/);
    assert.match(snapshot.diagnostics.detail, /celsius/);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
