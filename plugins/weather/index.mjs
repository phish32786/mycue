function weatherIcon(code, isDay = true) {
  if ([0].includes(code)) return isDay ? "☀" : "☾";
  if ([1, 2].includes(code)) return isDay ? "⛅" : "☁";
  if ([3].includes(code)) return "☁";
  if ([45, 48].includes(code)) return "〰";
  if ([51, 53, 55, 61, 63, 65, 80, 81, 82].includes(code)) return "☔";
  if ([71, 73, 75, 77, 85, 86].includes(code)) return "❄";
  if ([95, 96, 99].includes(code)) return "⚡";
  return "☁";
}

function detailForCode(code) {
  if ([0].includes(code)) return "Clear";
  if ([1, 2].includes(code)) return "Partly cloudy";
  if ([3].includes(code)) return "Cloudy";
  if ([45, 48].includes(code)) return "Fog";
  if ([51, 53, 55].includes(code)) return "Drizzle";
  if ([61, 63, 65, 80, 81, 82].includes(code)) return "Rain";
  if ([71, 73, 75, 77, 85, 86].includes(code)) return "Snow";
  if ([95, 96, 99].includes(code)) return "Storm";
  return "Cloudy";
}

function formatTemp(value) {
  return `${Math.round(value)}°`;
}

function formatPercent(value) {
  return `${Math.round(value)}%`;
}

function formatSpeed(value, unitLabel) {
  return `${Math.round(value)} ${unitLabel}`;
}

function formatRain(value) {
  return `${Math.round(value)}%`;
}

function formatTime(value) {
  return new Date(value).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

function formatDay(value) {
  return new Date(value).toLocaleDateString([], { weekday: "short" });
}

function unitConfig(preference = "automatic") {
  const locale = Intl.DateTimeFormat().resolvedOptions().locale || "en-US";
  const useImperial = preference === "imperial"
    ? true
    : preference === "metric"
      ? false
      : locale.toLowerCase().startsWith("en-us");
  return {
    tempUnit: useImperial ? "fahrenheit" : "celsius",
    windUnit: useImperial ? "mph" : "kmh",
    speedLabel: useImperial ? "mph" : "km/h"
  };
}

function themeForConditions(code, isDay) {
  if ([95, 96, 99].includes(code)) {
    return {
      accentHex: "#C8D3FF",
      backgroundHex: "#111728",
      foregroundHex: "#F7F9FF"
    };
  }

  if ([71, 73, 75, 77, 85, 86].includes(code)) {
    return {
      accentHex: "#D9F1FF",
      backgroundHex: "#10273B",
      foregroundHex: "#F5FBFF"
    };
  }

  if ([45, 48].includes(code)) {
    return {
      accentHex: "#D6DEE7",
      backgroundHex: "#17232D",
      foregroundHex: "#F7FAFC"
    };
  }

  if ([51, 53, 55, 61, 63, 65, 80, 81, 82].includes(code)) {
    return {
      accentHex: "#8EDCFF",
      backgroundHex: "#0B2236",
      foregroundHex: "#F3FAFF"
    };
  }

  if (isDay) {
    return {
      accentHex: "#89DEFF",
      backgroundHex: "#123654",
      foregroundHex: "#F5FBFF"
    };
  }

  return {
    accentHex: "#96A9FF",
    backgroundHex: "#0A1531",
    foregroundHex: "#F4F7FF"
  };
}

function fallbackForecast() {
  return {
    current: {
      temperature_2m: 47,
      apparent_temperature: 44,
      weather_code: 3,
      precipitation: 0,
      wind_speed_10m: 9,
      is_day: 1
    },
    hourly: {
      time: [new Date().toISOString(), new Date(Date.now() + 3600000).toISOString(), new Date(Date.now() + 7200000).toISOString(), new Date(Date.now() + 10800000).toISOString(), new Date(Date.now() + 14400000).toISOString()],
      temperature_2m: [47, 45, 44, 43, 42],
      weather_code: [3, 3, 2, 2, 1],
      precipitation_probability: [10, 10, 5, 5, 0]
    },
    daily: {
      time: [new Date().toISOString(), new Date(Date.now() + 86400000).toISOString(), new Date(Date.now() + 172800000).toISOString(), new Date(Date.now() + 259200000).toISOString(), new Date(Date.now() + 345600000).toISOString()],
      temperature_2m_max: [49, 52, 46, 44, 48],
      temperature_2m_min: [40, 38, 34, 31, 36],
      weather_code: [3, 0, 61, 71, 2],
      sunrise: Array(5).fill(new Date().toISOString()),
      sunset: Array(5).fill(new Date().toISOString())
    }
  };
}

export function createPlugin(context) {
  let cached = null;
  let cachedAt = 0;
  let inFlightFetch = null;
  let lastError = null;

  async function loadForecast(force = false) {
    const cacheAge = Date.now() - cachedAt;
    if (!force && cached && cacheAge < 10 * 60 * 1000) {
      return cached;
    }

    if (inFlightFetch) {
      return inFlightFetch;
    }

    const pluginSettings = context.getPluginSettings?.() ?? {};
    const weatherSettings = pluginSettings.weather ?? {};
    const location = weatherSettings.latitude != null && weatherSettings.longitude != null
      ? { latitude: weatherSettings.latitude, longitude: weatherSettings.longitude }
      : context.getLocation();
    const units = unitConfig(weatherSettings.unitPreference ?? "automatic");
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);

    inFlightFetch = (async () => {
      try {
        const url = new URL("https://api.open-meteo.com/v1/forecast");
        url.searchParams.set("latitude", location.latitude);
        url.searchParams.set("longitude", location.longitude);
        url.searchParams.set("temperature_unit", units.tempUnit);
        url.searchParams.set("wind_speed_unit", units.windUnit);
        url.searchParams.set("current", "temperature_2m,apparent_temperature,weather_code,precipitation,wind_speed_10m,is_day");
        url.searchParams.set("hourly", "temperature_2m,weather_code,precipitation_probability");
        url.searchParams.set("daily", "temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset");
        url.searchParams.set("forecast_days", "5");
        url.searchParams.set("timezone", "auto");

        const response = await fetch(url, { signal: controller.signal });
        if (!response.ok) {
          throw new Error(`Weather API returned ${response.status}`);
        }

        cached = await response.json();
        cachedAt = Date.now();
        lastError = null;
        return cached;
      } catch (error) {
        lastError = error.message;
        context.log("error", "Weather fetch failed", { error: error.message });
        return cached;
      } finally {
        clearTimeout(timeout);
        inFlightFetch = null;
      }
    })();

    return inFlightFetch;
  }

  return {
    async start() {
      context.log("info", "Weather plugin ready");
    },
    async getSnapshot() {
      const pluginSettings = context.getPluginSettings?.() ?? {};
      const weatherSettings = pluginSettings.weather ?? {};
      const location = weatherSettings.latitude != null && weatherSettings.longitude != null
        ? { latitude: weatherSettings.latitude, longitude: weatherSettings.longitude }
        : context.getLocation();
      const units = unitConfig(weatherSettings.unitPreference ?? "automatic");
      await loadForecast(false);
      const data = cached ?? fallbackForecast();
      const current = data.current;
      const currentCode = current.weather_code ?? 3;
      const currentDetail = detailForCode(currentCode);
      const headlineTemp = current.temperature_2m ?? 47;
      const feelsLike = current.apparent_temperature ?? headlineTemp;
      const windSpeed = current.wind_speed_10m ?? 0;
      const isDay = (current.is_day ?? 1) === 1;
      const rainChance = data.hourly?.precipitation_probability?.[0] ?? 0;
      const sunrise = data.daily?.sunrise?.[0] ? formatTime(data.daily.sunrise[0]) : "6:00 AM";
      const sunset = data.daily?.sunset?.[0] ? formatTime(data.daily.sunset[0]) : "7:00 PM";
      const theme = themeForConditions(currentCode, isDay);
      const updatedTime = cachedAt ? formatTime(new Date(cachedAt).toISOString()) : "Offline";

      const hourly = (data.hourly?.time ?? []).slice(0, 5).map((time, index) => ({
        id: `hour-${index}`,
        label: index === 0 ? "Now" : new Date(time).toLocaleTimeString([], { hour: "numeric" }),
        temperature: formatTemp(data.hourly.temperature_2m[index]),
        icon: weatherIcon(data.hourly.weather_code[index], isDay),
        detail: `${detailForCode(data.hourly.weather_code[index])} • ${formatPercent(data.hourly.precipitation_probability[index] ?? 0)}`
      }));

      const daily = (data.daily?.time ?? []).slice(0, 5).map((time, index) => ({
        id: `day-${index}`,
        label: index === 0 ? "Today" : formatDay(time),
        temperature: `${formatTemp(data.daily.temperature_2m_max[index])} / ${formatTemp(data.daily.temperature_2m_min[index])}`,
        icon: weatherIcon(data.daily.weather_code[index], true),
        detail: `${detailForCode(data.daily.weather_code[index])}`
      }));

      return {
        status: cached ? "running" : "degraded",
        surface: {
          kind: "weather",
          title: weatherSettings.locationName || "Local Weather",
          subtitle: `${currentDetail} • Feels like ${formatTemp(feelsLike)}`,
          detail: cached
            ? `Updated ${updatedTime} • Wind ${formatSpeed(windSpeed, units.speedLabel)} • Rain ${formatRain(rainChance)}`
            : "Using offline placeholder forecast because network data is unavailable.",
          theme,
          metrics: [
            {
              id: "current-temp",
              label: currentDetail,
              value: headlineTemp,
              unit: units.tempUnit === "fahrenheit" ? "F" : "C",
              target: units.tempUnit === "fahrenheit" ? 120 : 50,
              displayValue: `${weatherIcon(currentCode, isDay)} ${formatTemp(headlineTemp)}`
            },
            {
              id: "wind",
              label: "Wind",
              value: windSpeed,
              unit: units.speedLabel,
              target: units.windUnit === "mph" ? 50 : 80,
              displayValue: formatSpeed(windSpeed, units.speedLabel)
            },
            {
              id: "rain",
              label: "Rain chance",
              value: rainChance,
              unit: "%",
              target: 100,
              displayValue: formatRain(rainChance)
            },
            {
              id: "sun",
              label: "Sun cycle",
              value: 1,
              unit: "",
              target: 1,
              displayValue: `${sunrise} / ${sunset}`
            }
          ],
          actions: [],
          media: null,
          hourlyForecast: hourly.length ? hourly : fallbackForecast().hourly.time.slice(0, 5).map((_, index) => ({
            id: `fh-${index}`,
            label: index === 0 ? "Now" : `${index}h`,
            temperature: formatTemp(fallbackForecast().hourly.temperature_2m[index]),
            icon: weatherIcon(fallbackForecast().hourly.weather_code[index], true),
            detail: "Offline"
          })),
          dailyForecast: daily.length ? daily : fallbackForecast().daily.time.slice(0, 5).map((time, index) => ({
            id: `fd-${index}`,
            label: index === 0 ? "Today" : formatDay(time),
            temperature: `${formatTemp(fallbackForecast().daily.temperature_2m_max[index])} / ${formatTemp(fallbackForecast().daily.temperature_2m_min[index])}`,
            icon: weatherIcon(fallbackForecast().daily.weather_code[index], true),
            detail: "Offline"
          }))
        },
        diagnostics: {
          summary: cached ? "Healthy" : "Offline fallback",
          detail: cached ? `Units: ${units.tempUnit}, wind ${units.speedLabel} • ${weatherSettings.locationName || "Local Weather"} (${Number(location.latitude).toFixed(2)}, ${Number(location.longitude).toFixed(2)})` : null,
          lastError
        }
      };
    },
    async performAction() {}
  };
}
