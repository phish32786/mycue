import Foundation
import EdgeControlShared

public struct AppSettings: Codable, Hashable, Sendable {
    public var selectedDisplayID: String?
    public var launchAtLogin: Bool
    public var kioskMode: Bool
    public var startInDashboard: Bool
    public var darkChrome: Bool
    public var debugMode: Bool
    public var devKitEnabled: Bool
    public var pluginOrder: [String]
    public var enabledPluginIDs: Set<String>
    public var disabledPluginIDs: Set<String>
    public var weather: WeatherPluginSettings
    public var webWidget: WebWidgetSettings
    public var mediaGallery: MediaGallerySettings
    public var dashboardPages: [DashboardPageConfiguration]
    public var selectedPageID: String?

    public init(
        selectedDisplayID: String? = nil,
        launchAtLogin: Bool = false,
        kioskMode: Bool = true,
        startInDashboard: Bool = true,
        darkChrome: Bool = true,
        debugMode: Bool = false,
        devKitEnabled: Bool = true,
        pluginOrder: [String] = [],
        enabledPluginIDs: Set<String> = [],
        disabledPluginIDs: Set<String> = [],
        weather: WeatherPluginSettings = WeatherPluginSettings(),
        webWidget: WebWidgetSettings = WebWidgetSettings(),
        mediaGallery: MediaGallerySettings = MediaGallerySettings(),
        dashboardPages: [DashboardPageConfiguration] = [],
        selectedPageID: String? = nil
    ) {
        self.selectedDisplayID = selectedDisplayID
        self.launchAtLogin = launchAtLogin
        self.kioskMode = kioskMode
        self.startInDashboard = startInDashboard
        self.darkChrome = darkChrome
        self.debugMode = debugMode
        self.devKitEnabled = devKitEnabled
        self.pluginOrder = pluginOrder
        self.enabledPluginIDs = enabledPluginIDs
        self.disabledPluginIDs = disabledPluginIDs
        self.weather = weather
        self.webWidget = webWidget
        self.mediaGallery = mediaGallery
        self.dashboardPages = dashboardPages
        self.selectedPageID = selectedPageID
    }
}

extension AppSettings {
    enum CodingKeys: String, CodingKey {
        case selectedDisplayID
        case launchAtLogin
        case kioskMode
        case startInDashboard
        case darkChrome
        case debugMode
        case devKitEnabled
        case pluginOrder
        case enabledPluginIDs
        case disabledPluginIDs
        case weather
        case webWidget
        case mediaGallery
        case dashboardPages
        case selectedPageID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedDisplayID = try container.decodeIfPresent(String.self, forKey: .selectedDisplayID)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        kioskMode = try container.decodeIfPresent(Bool.self, forKey: .kioskMode) ?? true
        startInDashboard = try container.decodeIfPresent(Bool.self, forKey: .startInDashboard) ?? true
        darkChrome = try container.decodeIfPresent(Bool.self, forKey: .darkChrome) ?? true
        debugMode = try container.decodeIfPresent(Bool.self, forKey: .debugMode) ?? false
        devKitEnabled = try container.decodeIfPresent(Bool.self, forKey: .devKitEnabled) ?? true
        pluginOrder = try container.decodeIfPresent([String].self, forKey: .pluginOrder) ?? []
        enabledPluginIDs = try container.decodeIfPresent(Set<String>.self, forKey: .enabledPluginIDs) ?? []
        disabledPluginIDs = try container.decodeIfPresent(Set<String>.self, forKey: .disabledPluginIDs) ?? []
        weather = try container.decodeIfPresent(WeatherPluginSettings.self, forKey: .weather) ?? WeatherPluginSettings()
        webWidget = try container.decodeIfPresent(WebWidgetSettings.self, forKey: .webWidget) ?? WebWidgetSettings()
        mediaGallery = try container.decodeIfPresent(MediaGallerySettings.self, forKey: .mediaGallery) ?? MediaGallerySettings()
        dashboardPages = try container.decodeIfPresent([DashboardPageConfiguration].self, forKey: .dashboardPages) ?? []
        selectedPageID = try container.decodeIfPresent(String.self, forKey: .selectedPageID)
    }
}
