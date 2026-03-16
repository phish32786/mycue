import Foundation
import Testing
@testable import EdgeControlHost

@Test
func dashboardPageConfigurationEncodesItemsNotLegacyPluginIDs() throws {
    let page = DashboardPageConfiguration(
        id: "dashboard",
        title: "Dashboard",
        items: [
            DashboardPageItem(pluginID: "system-stats", span: .feature),
            DashboardPageItem(pluginID: "spotify", span: .compact)
        ]
    )

    let data = try JSONEncoder().encode(page)
    let text = String(decoding: data, as: UTF8.self)

    #expect(text.contains("\"items\""))
    #expect(!text.contains("\"pluginIDs\""))
}

@Test
func dashboardCardSpanMetadataMatchesExpectedWeights() {
    #expect(DashboardCardSpan.compact.title == "Compact")
    #expect(DashboardCardSpan.standard.title == "Standard")
    #expect(DashboardCardSpan.feature.title == "Feature")
    #expect(DashboardCardSpan.compact.weight < DashboardCardSpan.standard.weight)
    #expect(DashboardCardSpan.feature.weight > DashboardCardSpan.standard.weight)
}
