import Foundation
import Testing
@testable import EdgeControlShared

@Test
func jsonValueRoundTripsSnapshotPayload() throws {
    let manifest = PluginManifest(
        id: "weather",
        name: "Weather",
        version: "0.1.0",
        apiVersion: "1.0.0",
        kind: .weather,
        entry: "index.mjs",
        permissions: [.network, .location]
    )
    let snapshot = PluginSnapshot(
        manifest: manifest,
        status: .running,
        surface: DashboardSurface(
            kind: .weather,
            title: "Detroit",
            subtitle: "Cloudy",
            theme: SurfaceTheme(accentHex: "#8BD3FF", backgroundHex: "#0E1D2D", foregroundHex: "#F5FBFF")
        ),
        diagnostics: PluginDiagnostics(summary: "Healthy"),
        lastUpdated: .now
    )

    let payload = try JSONValue(encodable: [snapshot])
    let decoded = try payload.decode([PluginSnapshot].self)
    #expect(decoded.count == 1)
    #expect(decoded[0].manifest.id == "weather")
}

@Test
func pluginManifestPreservesDefaultEnabledAndPermissions() throws {
    let manifest = PluginManifest(
        id: "f1",
        name: "F1",
        version: "0.1.0",
        apiVersion: "1.0.0",
        kind: .f1,
        entry: "index.mjs",
        permissions: [.network],
        defaultEnabled: false
    )

    let data = try JSONEncoder().encode(manifest)
    let decoded = try JSONDecoder().decode(PluginManifest.self, from: data)

    #expect(decoded.defaultEnabled == false)
    #expect(decoded.kind == .f1)
    #expect(decoded.permissions == [.network])
}

@Test
func f1SurfaceRoundTripsNestedRows() throws {
    let surface = DashboardSurface(
        kind: .f1,
        title: "Race Control",
        subtitle: "Completed data",
        theme: SurfaceTheme(accentHex: "#FF7A3D", backgroundHex: "#111213", foregroundHex: "#F6F7F8"),
        f1: F1Surface(
            panelMode: .overview,
            sessionLabel: "Australian Grand Prix • Race",
            sessionStatus: "LAP 58 • P1 NOR",
            circuitLabel: "Albert Park",
            sourceLabel: "OPENF1",
            topStandings: [
                F1StandingRow(
                    id: "standing-4",
                    position: 1,
                    driverNumber: 4,
                    acronym: "NOR",
                    teamName: "McLaren",
                    teamColorHex: "#F47600",
                    gapText: "LEADER",
                    statusText: "MEDIUM L21-58"
                )
            ],
            raceControl: [
                F1RaceControlItem(
                    id: "control-1",
                    timeText: "10:45",
                    category: "FLAG",
                    flagText: "YELLOW",
                    message: "YELLOW IN SECTOR 2",
                    lapText: "LAP 37"
                )
            ],
            tyreRows: []
        )
    )

    let data = try JSONEncoder().encode(surface)
    let decoded = try JSONDecoder().decode(DashboardSurface.self, from: data)

    #expect(decoded.kind == .f1)
    #expect(decoded.f1?.panelMode == .overview)
    #expect(decoded.f1?.topStandings.first?.acronym == "NOR")
    #expect(decoded.f1?.raceControl.first?.message == "YELLOW IN SECTOR 2")
}
