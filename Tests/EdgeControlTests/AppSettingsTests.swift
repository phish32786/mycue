import Foundation
import Testing
import EdgeControlShared
@testable import EdgeControlHost

@Test
func appSettingsRoundTripPersistsDashboardPages() throws {
    let settings = AppSettings(
        selectedDisplayID: "display-1",
        kioskMode: true,
        debugMode: false,
        pluginOrder: ["system-stats", "spotify", "weather", "launcher"],
        disabledPluginIDs: ["weather"],
        webWidget: WebWidgetSettings(
            title: "Calendar",
            subtitle: "Upcoming schedule",
            urlString: "https://calendar.google.com"
        ),
        mediaGallery: MediaGallerySettings(
            title: "Gallery",
            subtitle: "Moodboard",
            folderPath: "/tmp/gallery",
            intervalSeconds: 6,
            shuffle: true
        ),
        dashboardPages: [
            DashboardPageConfiguration(
                id: "dashboard",
                title: "Dashboard",
                items: [
                    DashboardPageItem(pluginID: "system-stats", span: .feature),
                    DashboardPageItem(pluginID: "spotify", span: .standard),
                    DashboardPageItem(pluginID: "weather", span: .compact)
                ]
            ),
            DashboardPageConfiguration(
                id: "launch",
                title: "Launch",
                items: [
                    DashboardPageItem(pluginID: "launcher", span: .feature)
                ]
            )
        ],
        selectedPageID: "launch"
    )

    let encoded = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)

    #expect(decoded.dashboardPages.count == 2)
    #expect(decoded.dashboardPages[0].pluginIDs == ["system-stats", "spotify", "weather"])
    #expect(decoded.dashboardPages[0].items[0].span == DashboardCardSpan.feature)
    #expect(decoded.dashboardPages[0].items[2].span == DashboardCardSpan.compact)
    #expect(decoded.dashboardPages[1].title == "Launch")
    #expect(decoded.selectedPageID == "launch")
    #expect(decoded.disabledPluginIDs.contains("weather"))
    #expect(decoded.webWidget.title == "Calendar")
    #expect(decoded.webWidget.urlString == "https://calendar.google.com")
    #expect(decoded.mediaGallery.folderPath == "/tmp/gallery")
    #expect(decoded.mediaGallery.shuffle == true)
}

@Test
func dashboardPagesDecodeLegacyPluginIDFormat() throws {
    let json = """
    {
      "dashboardPages": [
        {
          "id": "dashboard",
          "title": "Dashboard",
          "pluginIDs": ["system-stats", "spotify"]
        }
      ],
      "selectedPageID": "dashboard"
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(AppSettings.self, from: json)

    #expect(decoded.dashboardPages.count == 1)
    #expect(decoded.dashboardPages[0].items.count == 2)
    #expect(decoded.dashboardPages[0].items.allSatisfy { $0.span == .standard })
    #expect(decoded.dashboardPages[0].pluginIDs == ["system-stats", "spotify"])
    #expect(decoded.webWidget.title == "Web Widget")
    #expect(decoded.webWidget.urlString == "https://calendar.google.com")
    #expect(decoded.mediaGallery.title == "Gallery")
    #expect(decoded.mediaGallery.folderPath.isEmpty)
}

@Test
func appSettingsDecodeDefaultsForMissingFields() throws {
    let json = """
    {
      "selectedDisplayID": "display-2"
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(AppSettings.self, from: json)

    #expect(decoded.selectedDisplayID == "display-2")
    #expect(decoded.launchAtLogin == false)
    #expect(decoded.kioskMode == true)
    #expect(decoded.startInDashboard == true)
    #expect(decoded.darkChrome == true)
    #expect(decoded.debugMode == false)
    #expect(decoded.devKitEnabled == true)
    #expect(decoded.weather.locationName == "Detroit")
    #expect(decoded.f1.title == "Race Control")
    #expect(decoded.dashboardPages.isEmpty)
}

@Test
func appSettingsRoundTripPersistsPluginConfiguration() throws {
    let settings = AppSettings(
        enabledPluginIDs: ["f1", "weather"],
        disabledPluginIDs: ["spotify"],
        weather: WeatherPluginSettings(
            locationName: "Montreal",
            latitude: 45.5017,
            longitude: -73.5673,
            unitPreference: .metric
        ),
        f1: F1PluginSettings(
            title: "Race Control",
            subtitle: "Completed race data",
            seasonYear: 2026,
            sessionName: "Race",
            eventFilter: "Monaco",
            sessionKeyOverride: 11245
        )
    )

    let encoded = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)

    #expect(decoded.enabledPluginIDs.contains("f1"))
    #expect(decoded.disabledPluginIDs.contains("spotify"))
    #expect(decoded.weather.locationName == "Montreal")
    #expect(decoded.weather.unitPreference == .metric)
    #expect(decoded.f1.eventFilter == "Monaco")
    #expect(decoded.f1.sessionKeyOverride == 11245)
}
