const OPENF1_BASE = "https://api.openf1.org/v1";
const MIN_REQUEST_INTERVAL_MS = 380;

let queuedRequest = Promise.resolve();
let lastRequestStartedAt = 0;

function fallbackSettings(settings = {}) {
  return {
    title: settings.title || "Race Control",
    subtitle: settings.subtitle || "OpenF1 timing and incidents",
    seasonYear: settings.seasonYear || new Date().getFullYear(),
    sessionName: settings.sessionName || "Race",
    eventFilter: settings.eventFilter || "",
    sessionKeyOverride: settings.sessionKeyOverride ?? null
  };
}

function theme() {
  return {
    accentHex: "#FF7A3D",
    backgroundHex: "#111213",
    foregroundHex: "#F6F7F8"
  };
}

function normalizeGapText(value, gapToLeader) {
  if (gapToLeader != null && gapToLeader !== "" && gapToLeader !== 0) {
    return `+${String(gapToLeader).replace(/^\+/, "")}`;
  }
  if (value == null || value === "") return "--";
  if (Number(value) === 0) return "LEADER";
  return String(value).startsWith("+") ? String(value) : `+${value}`;
}

function abbreviateCategory(category, flag) {
  if (flag) return flag.toUpperCase();
  if (!category) return "CTRL";
  return category.toUpperCase().replace(/\s+/g, " ").slice(0, 12);
}

function formatLapRange(stint) {
  const start = stint?.lap_start ?? null;
  const end = stint?.lap_end ?? null;
  if (start == null && end == null) return "--";
  if (start != null && end != null && start !== end) return `L${start}-${end}`;
  return `L${start ?? end}`;
}

function formatSourceLabel() {
  return "OPENF1";
}

function formatTimeText(value) {
  if (!value) return "--:--";
  return new Date(value).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function sortByDateAscending(records) {
  return [...records].sort((a, b) => String(a.date).localeCompare(String(b.date)));
}

async function fetchJSON(path, searchParams = {}) {
  queuedRequest = queuedRequest.then(async () => {
    const waitMs = Math.max(0, MIN_REQUEST_INTERVAL_MS - (Date.now() - lastRequestStartedAt));
    if (waitMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, waitMs));
    }
    lastRequestStartedAt = Date.now();
  });
  await queuedRequest;

  const url = new URL(`${OPENF1_BASE}/${path}`);
  for (const [key, value] of Object.entries(searchParams)) {
    if (value == null || value === "") continue;
    url.searchParams.set(key, String(value));
  }
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`OpenF1 returned ${response.status} for ${path}`);
  }
  return response.json();
}

function serializeSearchParams(searchParams = {}) {
  return Object.entries(searchParams)
    .filter(([, value]) => value != null && value !== "")
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${key}=${value}`)
    .join("&");
}

function buildSurface(dataset, settings, panelMode) {
  const driversByNumber = new Map(dataset.drivers.map((driver) => [driver.driver_number, driver]));

  const latestPositionByDriver = new Map();
  for (const entry of sortByDateAscending(dataset.position)) {
    latestPositionByDriver.set(entry.driver_number, entry);
  }
  const latestOrder = [...latestPositionByDriver.values()].sort((a, b) => a.position - b.position);

  const latestIntervalByDriver = new Map();
  for (const interval of sortByDateAscending(dataset.intervals)) {
    latestIntervalByDriver.set(interval.driver_number, interval);
  }

  const latestStintByDriver = new Map();
  for (const stint of dataset.stints) {
    const existing = latestStintByDriver.get(stint.driver_number);
    if (!existing) {
      latestStintByDriver.set(stint.driver_number, stint);
      continue;
    }
    const existingEnd = existing.lap_end ?? existing.lap_start ?? 0;
    const nextEnd = stint.lap_end ?? stint.lap_start ?? 0;
    if (nextEnd >= existingEnd) {
      latestStintByDriver.set(stint.driver_number, stint);
    }
  }

  const currentLap = Math.max(
    ...dataset.raceControl.map((item) => Number(item.lap_number ?? 0)),
    ...dataset.stints.map((item) => Number(item.lap_end ?? item.lap_start ?? 0)),
    0
  );

  const orderedDrivers = latestOrder.length > 0
    ? latestOrder.map((entry) => ({ driverNumber: entry.driver_number, position: entry.position }))
    : [...latestStintByDriver.keys()]
      .sort((left, right) => Number(left) - Number(right))
      .map((driverNumber, index) => ({ driverNumber, position: index + 1 }));

  const topStandings = orderedDrivers.slice(0, 8).map((entry) => {
    const driver = driversByNumber.get(entry.driverNumber) ?? {};
    const stint = latestStintByDriver.get(entry.driverNumber);
    const interval = latestIntervalByDriver.get(entry.driverNumber) ?? {};
    const hasTimingOrder = latestOrder.length > 0;
    return {
      id: `standing-${entry.driverNumber}`,
      position: entry.position,
      driverNumber: entry.driverNumber,
      acronym: driver.name_acronym || String(entry.driverNumber),
      teamName: driver.team_name || "Unknown",
      teamColorHex: driver.team_colour ? `#${driver.team_colour}` : null,
      gapText: hasTimingOrder
        ? (entry.position === 1 ? "LEADER" : normalizeGapText(interval.interval, interval.gap_to_leader))
        : "--",
      statusText: stint?.compound ? `${stint.compound} ${formatLapRange(stint)}` : "NO STINT"
    };
  });

  const raceControl = sortByDateAscending(dataset.raceControl)
    .slice(-5)
    .reverse()
    .map((item, index) => ({
      id: `control-${item.date}-${index}`,
      timeText: formatTimeText(item.date),
      category: item.category || "Control",
      flagText: item.flag || null,
      message: item.message || "No message",
      lapText: item.lap_number ? `LAP ${item.lap_number}` : null
    }));

  const tyreRows = topStandings
    .map((row) => {
      const stint = latestStintByDriver.get(row.driverNumber);
      return {
        ...row,
        gapText: stint?.compound || "UNKNOWN",
        statusText: stint ? `${formatLapRange(stint)} • AGE ${stint.tyre_age_at_start ?? 0}` : "NO DATA"
      };
    })
    .slice(0, 8);

  const meetingName = dataset.meeting?.meeting_name || dataset.session?.country_name || "Formula 1";
  const circuit = dataset.session?.circuit_short_name || dataset.meeting?.circuit_short_name || dataset.meeting?.location || "Circuit";
  const sessionName = dataset.session?.session_name || settings.sessionName;
  const sourceLabel = formatSourceLabel();
  const leader = topStandings[0];
  const topControl = raceControl[0];
  const statusLine = currentLap > 0
    ? `LAP ${currentLap}${leader ? ` • P1 ${leader.acronym}` : ""}`
    : topControl?.message || "Awaiting timing";

  return {
    kind: "f1",
    title: settings.title,
    subtitle: settings.subtitle,
    detail: `${meetingName} • ${sessionName}`,
    theme: theme(),
    metrics: [],
    actions: [
      { id: "mode.overview", title: "Overview", icon: "list.number", role: null },
      { id: "mode.control", title: "Control", icon: "flag.fill", role: null },
      { id: "mode.tyres", title: "Tyres", icon: "circle.hexagongrid.fill", role: null },
      { id: "refresh", title: "Refresh", icon: "arrow.clockwise", role: null }
    ],
    media: null,
    hourlyForecast: [],
    dailyForecast: [],
    f1: {
      panelMode,
      sessionLabel: `${meetingName} • ${sessionName}`,
      sessionStatus: statusLine,
      circuitLabel: circuit,
      sourceLabel,
      topStandings,
      raceControl: raceControl.map((item) => ({
        ...item,
        category: abbreviateCategory(item.category, item.flagText)
      })),
      tyreRows
    }
  };
}

function fallbackSurface(settings, panelMode, error = null) {
  return {
    status: "degraded",
    surface: {
      kind: "f1",
      title: settings.title,
      subtitle: settings.subtitle,
      detail: error || "No F1 data available yet.",
      theme: theme(),
      metrics: [],
      actions: [
        { id: "mode.overview", title: "Overview", icon: "list.number", role: null },
        { id: "mode.control", title: "Control", icon: "flag.fill", role: null },
        { id: "mode.tyres", title: "Tyres", icon: "circle.hexagongrid.fill", role: null },
        { id: "refresh", title: "Refresh", icon: "arrow.clockwise", role: null }
      ],
      media: null,
      hourlyForecast: [],
      dailyForecast: [],
      f1: {
        panelMode,
        sessionLabel: "Formula 1",
        sessionStatus: "Waiting for completed race data",
        circuitLabel: "No source connected",
        sourceLabel: "OFFLINE",
        topStandings: [],
        raceControl: [],
        tyreRows: []
      }
    },
    diagnostics: {
      summary: "Waiting for F1 data",
      detail: "Completed OpenF1 race data unavailable.",
      lastError: error
    }
  };
}

export function createPlugin(context) {
  let panelMode = "overview";
  let lastError = null;
  let advisoryMessage = null;
  const endpointCache = new Map();

  const ttl = {
    meetings: 6 * 60 * 60 * 1000,
    sessions: 15 * 60 * 1000,
    drivers: 6 * 60 * 60 * 1000,
    position: 20 * 1000,
    intervals: 20 * 1000,
    race_control: 15 * 1000,
    stints: 45 * 1000
  };
  const backoffMs = 60 * 1000;

  function noteEndpointFailure(path, error) {
    advisoryMessage = `Partial data unavailable: ${path}`;
    context.log("warn", "F1 endpoint unavailable", { path, error: error.message });
  }

  async function fetchEndpoint(path, searchParams = {}, ttlMs, force = false) {
    const key = `${path}?${serializeSearchParams(searchParams)}`;
    const now = Date.now();
    const cached = endpointCache.get(key);

    if (!force && cached?.value !== undefined && now - cached.fetchedAt < ttlMs) {
      return cached.value;
    }

    if (!force && cached?.inFlight) {
      return cached.inFlight;
    }

    if (!force && cached?.nextRetryAt && now < cached.nextRetryAt) {
      if (cached.value !== undefined) {
        return cached.value;
      }
      throw new Error(cached.lastError ?? `Backing off ${path}`);
    }

    const inFlight = (async () => {
      try {
        const value = await fetchJSON(path, searchParams);
        endpointCache.set(key, {
          value,
          fetchedAt: Date.now(),
          nextRetryAt: 0,
          lastError: null
        });
        return value;
      } catch (error) {
        const fallback = endpointCache.get(key);
        endpointCache.set(key, {
          value: fallback?.value,
          fetchedAt: fallback?.fetchedAt ?? 0,
          nextRetryAt: Date.now() + backoffMs,
          lastError: error.message
        });
        if (fallback?.value !== undefined) {
          advisoryMessage = `Using cached ${path}`;
          context.log("warn", "Using cached F1 endpoint after fetch failure", { path, error: error.message });
          return fallback.value;
        }
        throw error;
      } finally {
        const settled = endpointCache.get(key);
        if (settled) {
          delete settled.inFlight;
          endpointCache.set(key, settled);
        }
      }
    })();

    endpointCache.set(key, { ...(cached ?? {}), inFlight });
    return inFlight;
  }

  async function fetchOptionalEndpoint(path, searchParams = {}, ttlMs, fallbackValue, force = false) {
    try {
      return await fetchEndpoint(path, searchParams, ttlMs, force);
    } catch (error) {
      noteEndpointFailure(path, error);
      return fallbackValue;
    }
  }

  async function resolveSession(settings, force = false) {
    if (settings.sessionKeyOverride != null) {
      const overriddenSession = (await fetchEndpoint("sessions", { session_key: settings.sessionKeyOverride }, ttl.sessions, force))?.[0] ?? null;
      if (!overriddenSession) return null;
      return overriddenSession;
    }

    let meetingKey = null;
    const filter = settings.eventFilter.trim().toLowerCase();

    if (filter) {
      const meetings = await fetchEndpoint("meetings", { year: settings.seasonYear }, ttl.meetings, force);
      const selectedMeeting = [...meetings]
        .filter((meeting) => {
          const haystack = [
            meeting.meeting_name,
            meeting.meeting_official_name,
            meeting.location,
            meeting.country_name,
            meeting.circuit_short_name
          ]
            .filter(Boolean)
            .join(" ")
            .toLowerCase();
          return haystack.includes(filter);
        })
        .sort((a, b) => String(b.date_start).localeCompare(String(a.date_start)))[0] ?? null;
      meetingKey = selectedMeeting?.meeting_key ?? null;
    }

    const sessions = await fetchEndpoint(
      "sessions",
      {
        year: settings.seasonYear,
        session_name: settings.sessionName,
        meeting_key: meetingKey
      },
      ttl.sessions,
      force
    );

    const now = Date.now();
    return [...sessions]
      .filter((session) => {
        const endTime = session.date_end ? Date.parse(session.date_end) : Number.NaN;
        return Number.isFinite(endTime) && endTime <= now;
      })
      .sort((a, b) => String(b.date_start).localeCompare(String(a.date_start)))[0] ?? null;
  }

  async function loadHistoricalDataset(settings, activePanelMode, force = false) {
    const session = await resolveSession(settings, force);
    if (!session) {
      throw new Error("No completed OpenF1 session matched the current settings.");
    }

    const query = { session_key: session.session_key };
    const includeDrivers = activePanelMode === "overview" || activePanelMode === "tyres";
    const includePosition = activePanelMode === "overview" || activePanelMode === "tyres";
    const includeIntervals = activePanelMode === "overview";
    const includeRaceControl = activePanelMode === "overview" || activePanelMode === "control";
    const includeStints = activePanelMode === "tyres";

    const [meeting, drivers, position, intervals, raceControl, stints] = await Promise.all([
      fetchEndpoint("meetings", { meeting_key: session.meeting_key }, ttl.meetings, force).then((items) => items?.[0] ?? null),
      includeDrivers ? fetchOptionalEndpoint("drivers", query, ttl.drivers, [], force) : Promise.resolve([]),
      includePosition ? fetchOptionalEndpoint("position", query, ttl.position, [], force) : Promise.resolve([]),
      includeIntervals ? fetchOptionalEndpoint("intervals", query, ttl.intervals, [], force) : Promise.resolve([]),
      includeRaceControl ? fetchOptionalEndpoint("race_control", query, ttl.race_control, [], force) : Promise.resolve([]),
      includeStints ? fetchOptionalEndpoint("stints", query, ttl.stints, [], force) : Promise.resolve([])
    ]);

    return {
      source: "historical",
      meeting,
      session,
      drivers,
      position,
      intervals,
      raceControl,
      stints
    };
  }

  async function loadDataset(force = false) {
    const settings = fallbackSettings(context.getPluginSettings?.().f1);
    advisoryMessage = null;
    try {
      const dataset = await loadHistoricalDataset(settings, panelMode, force);
      lastError = null;
      return { settings, dataset };
    } catch (error) {
      lastError = error.message;
      context.log("error", "F1 data load failed", { error: error.message });
      return { settings, dataset: null };
    }
  }

  return {
    async start() {
      context.log("info", "F1 plugin ready");
    },
    async getSnapshot() {
      const { settings, dataset } = await loadDataset(false);
      if (!dataset) {
        return fallbackSurface(settings, panelMode, lastError);
      }

      return {
        status: advisoryMessage ? "degraded" : "running",
        surface: buildSurface(dataset, settings, panelMode),
        diagnostics: {
          summary: advisoryMessage ? "Partial F1 data" : "Healthy",
          detail: dataset.session?.session_key ? `Session ${dataset.session.session_key} • ${dataset.source}` : dataset.source,
          lastError: advisoryMessage ?? lastError
        }
      };
    },
    async performAction(action) {
      if (action.actionID === "refresh") {
        await loadDataset(true);
        return;
      }

      if (action.actionID.startsWith("mode.")) {
        panelMode = action.actionID.split(".")[1] ?? "overview";
      }
    }
  };
}
