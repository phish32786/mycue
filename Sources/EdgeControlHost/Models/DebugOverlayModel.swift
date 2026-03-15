import EdgeControlShared
import Foundation
import SwiftUI

@MainActor
public final class DebugOverlayModel: ObservableObject {
    @Published public var renderedFrames: Int = 0
    @Published public var runtimeConnected = false
    @Published public var selectedDisplayName = "Unknown"
    @Published public var recentLogs: [PluginLogEvent] = []
    @Published public var hidStatus = "inactive"
    @Published public var touchStatus = "idle"
    @Published public var touchPointDescription = "n/a"
    @Published public var calibrationValidation = "n/a"
    @Published public var pluginCount = 0
    @Published public var pluginStatuses: [String] = []

    public init() {}

    public func push(log: PluginLogEvent) {
        recentLogs.insert(log, at: 0)
        recentLogs = Array(recentLogs.prefix(16))
    }

    public func didRenderFrame() {
        renderedFrames += 1
    }
}
