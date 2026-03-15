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
