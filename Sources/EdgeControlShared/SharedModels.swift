import CoreGraphics
import Foundation

public struct PluginManifest: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let apiVersion: String
    public let kind: PluginKind
    public let entry: String
    public let permissions: [PluginPermission]
    public let defaultEnabled: Bool

    public init(
        id: String,
        name: String,
        version: String,
        apiVersion: String,
        kind: PluginKind,
        entry: String,
        permissions: [PluginPermission],
        defaultEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.apiVersion = apiVersion
        self.kind = kind
        self.entry = entry
        self.permissions = permissions
        self.defaultEnabled = defaultEnabled
    }
}

public enum PluginKind: String, Codable, Hashable, Sendable, CaseIterable {
    case systemStats
    case spotify
    case weather
    case launcher
    case webWidget
    case mediaGallery
    case custom
}

public enum PluginPermission: String, Codable, Hashable, Sendable, CaseIterable {
    case systemMetrics
    case mediaControl
    case network
    case location
    case notifications
    case appLaunch
    case webContent
    case fileAccess
}

public enum PluginRuntimeStatus: String, Codable, Hashable, Sendable {
    case starting
    case running
    case degraded
    case failed
    case disabled
}

public struct PluginDiagnostics: Codable, Hashable, Sendable {
    public let summary: String
    public let detail: String?
    public let lastError: String?

    public init(summary: String, detail: String? = nil, lastError: String? = nil) {
        self.summary = summary
        self.detail = detail
        self.lastError = lastError
    }
}

public struct SurfaceTheme: Codable, Hashable, Sendable {
    public let accentHex: String
    public let backgroundHex: String
    public let foregroundHex: String

    public init(accentHex: String, backgroundHex: String, foregroundHex: String) {
        self.accentHex = accentHex
        self.backgroundHex = backgroundHex
        self.foregroundHex = foregroundHex
    }
}

public struct SurfaceMetric: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let value: Double
    public let unit: String
    public let target: Double?
    public let displayValue: String

    public init(id: String, label: String, value: Double, unit: String, target: Double? = nil, displayValue: String) {
        self.id = id
        self.label = label
        self.value = value
        self.unit = unit
        self.target = target
        self.displayValue = displayValue
    }
}

public struct SurfaceAction: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let role: String?

    public init(id: String, title: String, icon: String, role: String? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.role = role
    }
}

public struct MediaSurface: Codable, Hashable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let progress: Double
    public let durationText: String
    public let elapsedText: String
    public let artworkURL: String?
    public let isPlaying: Bool
    public let volume: Double
    public let deviceName: String?

    public init(
        title: String,
        artist: String,
        album: String,
        progress: Double,
        durationText: String,
        elapsedText: String,
        artworkURL: String? = nil,
        isPlaying: Bool,
        volume: Double,
        deviceName: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.progress = progress
        self.durationText = durationText
        self.elapsedText = elapsedText
        self.artworkURL = artworkURL
        self.isPlaying = isPlaying
        self.volume = volume
        self.deviceName = deviceName
    }
}

public struct WeatherPoint: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let temperature: String
    public let icon: String
    public let detail: String

    public init(id: String, label: String, temperature: String, icon: String, detail: String) {
        self.id = id
        self.label = label
        self.temperature = temperature
        self.icon = icon
        self.detail = detail
    }
}

public struct DashboardSurface: Codable, Hashable, Sendable {
    public let kind: PluginKind
    public let title: String
    public let subtitle: String
    public let detail: String?
    public let theme: SurfaceTheme
    public let metrics: [SurfaceMetric]
    public let actions: [SurfaceAction]
    public let media: MediaSurface?
    public let hourlyForecast: [WeatherPoint]
    public let dailyForecast: [WeatherPoint]

    public init(
        kind: PluginKind,
        title: String,
        subtitle: String,
        detail: String? = nil,
        theme: SurfaceTheme,
        metrics: [SurfaceMetric] = [],
        actions: [SurfaceAction] = [],
        media: MediaSurface? = nil,
        hourlyForecast: [WeatherPoint] = [],
        dailyForecast: [WeatherPoint] = []
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.theme = theme
        self.metrics = metrics
        self.actions = actions
        self.media = media
        self.hourlyForecast = hourlyForecast
        self.dailyForecast = dailyForecast
    }
}

public struct PluginSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let manifest: PluginManifest
    public let status: PluginRuntimeStatus
    public let surface: DashboardSurface
    public let diagnostics: PluginDiagnostics
    public let lastUpdated: Date

    public var id: String { manifest.id }

    public init(
        manifest: PluginManifest,
        status: PluginRuntimeStatus,
        surface: DashboardSurface,
        diagnostics: PluginDiagnostics,
        lastUpdated: Date
    ) {
        self.manifest = manifest
        self.status = status
        self.surface = surface
        self.diagnostics = diagnostics
        self.lastUpdated = lastUpdated
    }
}

public struct PluginActionRequest: Codable, Hashable, Sendable {
    public let pluginID: String
    public let actionID: String
    public let value: Double?

    public init(pluginID: String, actionID: String, value: Double? = nil) {
        self.pluginID = pluginID
        self.actionID = actionID
        self.value = value
    }
}

public enum WeatherUnitPreference: String, Codable, Hashable, Sendable, CaseIterable {
    case automatic
    case imperial
    case metric
}

public struct WeatherPluginSettings: Codable, Hashable, Sendable {
    public var locationName: String
    public var latitude: Double
    public var longitude: Double
    public var unitPreference: WeatherUnitPreference

    public init(
        locationName: String = "Detroit",
        latitude: Double = 42.3314,
        longitude: Double = -83.0458,
        unitPreference: WeatherUnitPreference = .automatic
    ) {
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.unitPreference = unitPreference
    }
}

public struct WebWidgetSettings: Codable, Hashable, Sendable {
    public var title: String
    public var subtitle: String
    public var urlString: String

    public init(
        title: String = "Web Widget",
        subtitle: String = "Embedded dashboard",
        urlString: String = "https://calendar.google.com"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.urlString = urlString
    }
}

public struct MediaGallerySettings: Codable, Hashable, Sendable {
    public var title: String
    public var subtitle: String
    public var folderPath: String
    public var intervalSeconds: Double
    public var shuffle: Bool

    public init(
        title: String = "Gallery",
        subtitle: String = "Local media rotation",
        folderPath: String = "",
        intervalSeconds: Double = 8,
        shuffle: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.folderPath = folderPath
        self.intervalSeconds = intervalSeconds
        self.shuffle = shuffle
    }
}

public struct HostPluginSettings: Codable, Hashable, Sendable {
    public var weather: WeatherPluginSettings
    public var webWidget: WebWidgetSettings
    public var mediaGallery: MediaGallerySettings

    public init(
        weather: WeatherPluginSettings = WeatherPluginSettings(),
        webWidget: WebWidgetSettings = WebWidgetSettings(),
        mediaGallery: MediaGallerySettings = MediaGallerySettings()
    ) {
        self.weather = weather
        self.webWidget = webWidget
        self.mediaGallery = mediaGallery
    }
}

public struct HostInitializePayload: Codable, Hashable, Sendable {
    public let pluginsPath: String
    public let devMode: Bool
    public let latitude: Double
    public let longitude: Double
    public let hostMetrics: HostSystemMetrics?
    public let pluginSettings: HostPluginSettings

    public init(
        pluginsPath: String,
        devMode: Bool,
        latitude: Double,
        longitude: Double,
        hostMetrics: HostSystemMetrics? = nil,
        pluginSettings: HostPluginSettings = HostPluginSettings()
    ) {
        self.pluginsPath = pluginsPath
        self.devMode = devMode
        self.latitude = latitude
        self.longitude = longitude
        self.hostMetrics = hostMetrics
        self.pluginSettings = pluginSettings
    }
}

public struct HostSystemMetrics: Codable, Hashable, Sendable {
    public let cpuLoadPercent: Double
    public let memoryUsedPercent: Double
    public let memoryUsedGB: Double
    public let memoryTotalGB: Double
    public let memoryPressurePercent: Double
    public let swapUsedMB: Double
    public let storageUsedPercent: Double
    public let storageUsedGB: Double
    public let storageTotalGB: Double
    public let uptimeSeconds: Double
    public let cpuBrand: String
    public let performanceCoreCount: Int
    public let efficiencyCoreCount: Int
    public let gpuName: String
    public let thermalState: String
    public let collectedAt: Date

    public init(
        cpuLoadPercent: Double,
        memoryUsedPercent: Double,
        memoryUsedGB: Double,
        memoryTotalGB: Double,
        memoryPressurePercent: Double,
        swapUsedMB: Double,
        storageUsedPercent: Double,
        storageUsedGB: Double,
        storageTotalGB: Double,
        uptimeSeconds: Double,
        cpuBrand: String,
        performanceCoreCount: Int,
        efficiencyCoreCount: Int,
        gpuName: String,
        thermalState: String,
        collectedAt: Date
    ) {
        self.cpuLoadPercent = cpuLoadPercent
        self.memoryUsedPercent = memoryUsedPercent
        self.memoryUsedGB = memoryUsedGB
        self.memoryTotalGB = memoryTotalGB
        self.memoryPressurePercent = memoryPressurePercent
        self.swapUsedMB = swapUsedMB
        self.storageUsedPercent = storageUsedPercent
        self.storageUsedGB = storageUsedGB
        self.storageTotalGB = storageTotalGB
        self.uptimeSeconds = uptimeSeconds
        self.cpuBrand = cpuBrand
        self.performanceCoreCount = performanceCoreCount
        self.efficiencyCoreCount = efficiencyCoreCount
        self.gpuName = gpuName
        self.thermalState = thermalState
        self.collectedAt = collectedAt
    }
}

public struct HostCommandEnvelope: Codable, Hashable, Sendable {
    public let command: String
    public let payload: JSONValue?

    public init(command: String, payload: JSONValue? = nil) {
        self.command = command
        self.payload = payload
    }
}

public struct RuntimeEventEnvelope: Codable, Hashable, Sendable {
    public let event: String
    public let payload: JSONValue?

    public init(event: String, payload: JSONValue? = nil) {
        self.event = event
        self.payload = payload
    }
}

public struct PluginLogEvent: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let level: String
    public let pluginID: String?
    public let message: String
    public let timestamp: Date

    public init(id: UUID = UUID(), level: String, pluginID: String? = nil, message: String, timestamp: Date = .now) {
        self.id = id
        self.level = level
        self.pluginID = pluginID
        self.message = message
        self.timestamp = timestamp
    }
}

public enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public extension JSONValue {
    init<T: Encodable>(encodable value: T) throws {
        let data = try JSONEncoder().encode(value)
        self = try JSONDecoder().decode(JSONValue.self, from: data)
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try decode(type, using: JSONDecoder())
    }

    func decode<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try decoder.decode(T.self, from: data)
    }
}
