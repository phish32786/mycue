import CoreGraphics
import Foundation

public enum DashboardCardSpan: String, Codable, Hashable, CaseIterable, Sendable {
    case compact
    case standard
    case feature

    public var title: String {
        switch self {
        case .compact:
            return "Compact"
        case .standard:
            return "Standard"
        case .feature:
            return "Feature"
        }
    }

    public var weight: CGFloat {
        switch self {
        case .compact:
            return 0.84
        case .standard:
            return 1.0
        case .feature:
            return 1.28
        }
    }
}

public struct DashboardPageItem: Codable, Hashable, Identifiable, Sendable {
    public var pluginID: String
    public var span: DashboardCardSpan

    public var id: String { pluginID }

    public init(pluginID: String, span: DashboardCardSpan = .standard) {
        self.pluginID = pluginID
        self.span = span
    }
}

public struct DashboardPageConfiguration: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var items: [DashboardPageItem]

    public var pluginIDs: [String] {
        get { items.map(\.pluginID) }
        set { items = newValue.map { DashboardPageItem(pluginID: $0) } }
    }

    public init(id: String = UUID().uuidString, title: String, pluginIDs: [String]) {
        self.id = id
        self.title = title
        self.items = pluginIDs.map { DashboardPageItem(pluginID: $0) }
    }

    public init(id: String = UUID().uuidString, title: String, items: [DashboardPageItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

extension DashboardPageConfiguration {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case items
        case pluginIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)

        if let items = try container.decodeIfPresent([DashboardPageItem].self, forKey: .items) {
            self.items = items
        } else {
            let pluginIDs = try container.decodeIfPresent([String].self, forKey: .pluginIDs) ?? []
            self.items = pluginIDs.map { DashboardPageItem(pluginID: $0) }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(items, forKey: .items)
    }
}
