import test from "node:test";
import assert from "node:assert/strict";
import { resolve } from "node:path";

function loadPlugin() {
  const modulePath = resolve(process.cwd(), "plugins/f1/index.mjs");
  return import(`file://${modulePath}?t=${Date.now()}-${Math.random()}`);
}

function jsonResponse(payload) {
  return {
    ok: true,
    async json() {
      return payload;
    }
  };
}

test("f1 plugin selects the latest completed race by default", async () => {
  const { createPlugin } = await loadPlugin();
  const originalFetch = globalThis.fetch;
  const fetchPaths = [];

  globalThis.fetch = async (url) => {
    const parsed = new URL(String(url));
    fetchPaths.push(parsed.pathname);

    if (parsed.pathname.endsWith("/sessions")) {
      return jsonResponse([
        {
          session_key: 2001,
          meeting_key: 301,
          session_name: "Race",
          circuit_short_name: "Future",
          country_name: "Futureland",
          date_start: "2099-01-01T10:00:00Z",
          date_end: "2099-01-01T12:00:00Z"
        },
        {
          session_key: 1001,
          meeting_key: 201,
          session_name: "Race",
          circuit_short_name: "Melbourne",
          country_name: "Australia",
          date_start: "2026-03-15T04:00:00Z",
          date_end: "2026-03-15T06:00:00Z"
        }
      ]);
    }

    if (parsed.pathname.endsWith("/meetings")) {
      return jsonResponse([
        {
          meeting_key: 201,
          meeting_name: "Australian Grand Prix",
          circuit_short_name: "Albert Park",
          location: "Melbourne"
        }
      ]);
    }

    if (parsed.pathname.endsWith("/drivers")) {
      return jsonResponse([
        {
          driver_number: 81,
          name_acronym: "PIA",
          team_name: "McLaren",
          team_colour: "F47600"
        },
        {
          driver_number: 16,
          name_acronym: "LEC",
          team_name: "Ferrari",
          team_colour: "DC0000"
        }
      ]);
    }

    if (parsed.pathname.endsWith("/position")) {
      return jsonResponse([
        { date: "2026-03-15T05:59:00Z", driver_number: 81, position: 1 },
        { date: "2026-03-15T05:59:00Z", driver_number: 16, position: 2 }
      ]);
    }

    if (parsed.pathname.endsWith("/intervals")) {
      return jsonResponse([
        { date: "2026-03-15T05:59:00Z", driver_number: 81, interval: 0, gap_to_leader: 0 },
        { date: "2026-03-15T05:59:00Z", driver_number: 16, interval: "+2.1", gap_to_leader: "+2.1" }
      ]);
    }

    if (parsed.pathname.endsWith("/race_control")) {
      return jsonResponse([
        {
          date: "2026-03-15T05:40:00Z",
          category: "Track Limits",
          message: "CAR 16 LAP TIME DELETED",
          lap_number: 37
        }
      ]);
    }

    if (parsed.pathname.endsWith("/stints")) {
      return jsonResponse([
        {
          driver_number: 81,
          compound: "MEDIUM",
          lap_start: 21,
          lap_end: 58,
          tyre_age_at_start: 0
        }
      ]);
    }

    throw new Error(`Unhandled path ${parsed.pathname}`);
  };

  try {
    const plugin = createPlugin({
      getPluginSettings: () => ({ f1: { title: "Race Control", subtitle: "OpenF1 timing and incidents" } }),
      log() {}
    });

    const snapshot = await plugin.getSnapshot();
    assert.equal(snapshot.status, "running");
    assert.equal(snapshot.surface.f1.sessionLabel, "Australian Grand Prix • Race");
    assert.equal(snapshot.surface.f1.circuitLabel, "Melbourne");
    assert.equal(snapshot.surface.f1.topStandings[0].acronym, "PIA");
    assert.equal(snapshot.surface.f1.topStandings[1].gapText, "+2.1");
    assert.match(snapshot.diagnostics.detail, /Session 1001/);
    assert.equal(fetchPaths.filter((path) => path.endsWith("/sessions")).length, 1);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("f1 control mode only fetches session, meeting, and race control data", async () => {
  const { createPlugin } = await loadPlugin();
  const originalFetch = globalThis.fetch;
  const fetchPaths = [];

  globalThis.fetch = async (url) => {
    const parsed = new URL(String(url));
    fetchPaths.push(parsed.pathname);

    if (parsed.pathname.endsWith("/sessions")) {
      return jsonResponse([
        {
          session_key: 1001,
          meeting_key: 201,
          session_name: "Race",
          date_start: "2026-03-15T04:00:00Z",
          date_end: "2026-03-15T06:00:00Z"
        }
      ]);
    }

    if (parsed.pathname.endsWith("/meetings")) {
      return jsonResponse([{ meeting_key: 201, meeting_name: "Australian Grand Prix", circuit_short_name: "Albert Park" }]);
    }

    if (parsed.pathname.endsWith("/race_control")) {
      return jsonResponse([
        { date: "2026-03-15T05:55:00Z", category: "Flag", flag: "yellow", message: "YELLOW IN SECTOR 2" }
      ]);
    }

    throw new Error(`Unexpected endpoint ${parsed.pathname}`);
  };

  try {
    const plugin = createPlugin({ getPluginSettings: () => ({ f1: {} }), log() {} });
    await plugin.performAction({ actionID: "mode.control" });
    const snapshot = await plugin.getSnapshot();

    assert.equal(snapshot.status, "running");
    assert.equal(snapshot.surface.f1.panelMode, "control");
    assert.equal(snapshot.surface.f1.raceControl.length, 1);
    assert.equal(snapshot.surface.f1.topStandings.length, 0);
    assert.deepEqual(fetchPaths.sort(), [
      "/v1/meetings",
      "/v1/race_control",
      "/v1/sessions"
    ]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("f1 tyres mode falls back to stint-based rows when position is unavailable", async () => {
  const { createPlugin } = await loadPlugin();
  const originalFetch = globalThis.fetch;

  globalThis.fetch = async (url) => {
    const parsed = new URL(String(url));

    if (parsed.pathname.endsWith("/sessions")) {
      return jsonResponse([
        {
          session_key: 1001,
          meeting_key: 201,
          session_name: "Race",
          date_start: "2026-03-15T04:00:00Z",
          date_end: "2026-03-15T06:00:00Z"
        }
      ]);
    }

    if (parsed.pathname.endsWith("/meetings")) {
      return jsonResponse([{ meeting_key: 201, meeting_name: "Australian Grand Prix", circuit_short_name: "Albert Park" }]);
    }

    if (parsed.pathname.endsWith("/drivers")) {
      return jsonResponse([
        { driver_number: 4, name_acronym: "NOR", team_name: "McLaren", team_colour: "F47600" },
        { driver_number: 63, name_acronym: "RUS", team_name: "Mercedes", team_colour: "27F4D2" }
      ]);
    }

    if (parsed.pathname.endsWith("/position")) {
      return { ok: false, status: 429, async json() { return {}; } };
    }

    if (parsed.pathname.endsWith("/stints")) {
      return jsonResponse([
        { driver_number: 4, compound: "SOFT", lap_start: 1, lap_end: 18, tyre_age_at_start: 0 },
        { driver_number: 63, compound: "MEDIUM", lap_start: 19, lap_end: 58, tyre_age_at_start: 0 }
      ]);
    }

    throw new Error(`Unexpected endpoint ${parsed.pathname}`);
  };

  try {
    const plugin = createPlugin({ getPluginSettings: () => ({ f1: {} }), log() {} });
    await plugin.performAction({ actionID: "mode.tyres" });
    const snapshot = await plugin.getSnapshot();

    assert.equal(snapshot.status, "degraded");
    assert.equal(snapshot.surface.f1.panelMode, "tyres");
    assert.equal(snapshot.surface.f1.tyreRows.length, 2);
    assert.equal(snapshot.surface.f1.tyreRows[0].gapText, "SOFT");
    assert.match(snapshot.diagnostics.lastError, /Partial data unavailable: position/);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
