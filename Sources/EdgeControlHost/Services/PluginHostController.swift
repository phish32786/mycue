import Foundation
import EdgeControlShared

private enum BridgeDateCoding {
    static func decode(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    static func encode(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

@MainActor
public final class PluginHostController {
    public struct Callbacks {
        public let onConnected: (Bool) -> Void
        public let onSnapshots: ([PluginSnapshot]) -> Void
        public let onLog: (PluginLogEvent) -> Void

        public init(onConnected: @escaping (Bool) -> Void, onSnapshots: @escaping ([PluginSnapshot]) -> Void, onLog: @escaping (PluginLogEvent) -> Void) {
            self.onConnected = onConnected
            self.onSnapshots = onSnapshots
            self.onLog = onLog
        }
    }

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutBuffer = Data()
    private var callbacks: Callbacks?

    public init() {
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = BridgeDateCoding.decode(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported ISO8601 date: \(value)")
        }
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(BridgeDateCoding.encode(date))
        }
    }

    public func start(settings: AppSettings, initialHostMetrics: HostSystemMetrics?, callbacks: Callbacks) {
        self.callbacks = callbacks

        let runtimeURL = resolvedRuntimeURL()
        let pluginsURL = resolvedPluginsURL()
        guard let nodeURL = resolvedNodeExecutableURL() else {
            callbacks.onLog(PluginLogEvent(level: "error", message: "Node runtime not found. Install Node.js or bundle a node executable."))
            callbacks.onSnapshots(Self.mockSnapshots())
            return
        }

        guard FileManager.default.fileExists(atPath: runtimeURL.path) else {
            callbacks.onLog(PluginLogEvent(level: "error", message: "Node runtime not found at \(runtimeURL.path)"))
            callbacks.onSnapshots(Self.mockSnapshots())
            return
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stdinPipe = Pipe()
        process.executableURL = nodeURL
        process.arguments = [runtimeURL.path]
        process.standardOutput = stdoutPipe
        process.standardInput = stdinPipe
        process.standardError = stdoutPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.consume(data)
            }
        }

        process.terminationHandler = { [weak self] process in
            Task { @MainActor [weak self] in
                self?.callbacks?.onConnected(false)
                self?.callbacks?.onLog(
                    PluginLogEvent(
                        level: process.terminationReason == .exit ? "info" : "error",
                        message: "Plugin runtime exited with code \(process.terminationStatus)"
                    )
                )
            }
        }

        do {
            try process.run()
            self.process = process
            self.stdinPipe = stdinPipe
            callbacks.onConnected(true)

            let payload = HostInitializePayload(
                pluginsPath: pluginsURL.path,
                devMode: settings.devKitEnabled,
                latitude: settings.weather.latitude,
                longitude: settings.weather.longitude,
                hostMetrics: initialHostMetrics,
                pluginSettings: runtimeSettings(from: settings)
            )
            try send(command: "initialize", payload: payload)
        } catch {
            callbacks.onLog(PluginLogEvent(level: "error", message: "Failed to launch runtime: \(error.localizedDescription)"))
            callbacks.onSnapshots(Self.mockSnapshots())
        }
    }

    public func perform(_ request: PluginActionRequest) {
        do {
            try send(command: "action", payload: request)
        } catch {
            callbacks?.onLog(PluginLogEvent(level: "error", pluginID: request.pluginID, message: "Failed to send action \(request.actionID): \(error.localizedDescription)"))
        }
    }

    public func updateHostMetrics(_ metrics: HostSystemMetrics) {
        do {
            try send(command: "hostMetrics.update", payload: metrics)
        } catch {
            callbacks?.onLog(PluginLogEvent(level: "error", message: "Failed to send host metrics: \(error.localizedDescription)"))
        }
    }

    public func updateSettings(_ settings: AppSettings) {
        do {
            try send(command: "settings.update", payload: runtimeSettings(from: settings))
        } catch {
            callbacks?.onLog(PluginLogEvent(level: "error", message: "Failed to send plugin settings: \(error.localizedDescription)"))
        }
    }

    public func stop() {
        process?.terminate()
        process = nil
        stdinPipe = nil
    }

    private func send<T: Encodable>(command: String, payload: T) throws {
        guard let process, process.isRunning else {
            throw PluginHostError.runtimeUnavailable
        }
        let envelope = HostCommandEnvelope(command: command, payload: try JSONValue(encodable: payload))
        let data = try encoder.encode(envelope)
        guard let line = String(data: data, encoding: .utf8)?.appending("\n").data(using: .utf8) else { return }
        guard let stdinPipe else {
            throw PluginHostError.runtimeUnavailable
        }
        try stdinPipe.fileHandleForWriting.write(contentsOf: line)
    }

    private func consume(_ data: Data) {
        stdoutBuffer.append(data)
        while let newline = stdoutBuffer.firstIndex(of: 0x0A) {
            let line = stdoutBuffer.prefix(upTo: newline)
            stdoutBuffer.removeSubrange(...newline)
            guard !line.isEmpty else { continue }
            handleLine(Data(line))
        }
    }

    private func handleLine(_ line: Data) {
        guard let envelope = try? decoder.decode(RuntimeEventEnvelope.self, from: line) else {
            if let raw = String(data: line, encoding: .utf8) {
                callbacks?.onLog(PluginLogEvent(level: "debug", message: raw))
            }
            return
        }

        switch envelope.event {
        case "runtime.ready":
            callbacks?.onLog(PluginLogEvent(level: "info", message: "Plugin runtime ready"))
        case "plugins.snapshot":
            guard let payload = envelope.payload,
                  let snapshots = try? payload.decode([PluginSnapshot].self, using: decoder) else {
                callbacks?.onLog(PluginLogEvent(level: "error", message: "Invalid plugins.snapshot payload"))
                return
            }
            callbacks?.onSnapshots(snapshots)
        case "plugin.log":
            guard let payload = envelope.payload,
                  let log = try? payload.decode(PluginLogEvent.self, using: decoder) else { return }
            callbacks?.onLog(log)
        default:
            callbacks?.onLog(PluginLogEvent(level: "debug", message: envelope.event))
        }
    }

    private static func mockSnapshots() -> [PluginSnapshot] {
        let manifest = PluginManifest(
            id: "system-stats",
            name: "System Stats",
            version: "0.1.0",
            apiVersion: "1.0.0",
            kind: .systemStats,
            entry: "index.mjs",
            permissions: [.systemMetrics]
        )

        return [
            PluginSnapshot(
                manifest: manifest,
                status: .degraded,
                surface: DashboardSurface(
                    kind: .systemStats,
                    title: "Runtime offline",
                    subtitle: "Using local fallback data",
                    detail: "The Node host did not start, so the dashboard is showing a built-in placeholder.",
                    theme: SurfaceTheme(accentHex: "#7EE0C3", backgroundHex: "#07141B", foregroundHex: "#F7FCFF"),
                    metrics: [
                        SurfaceMetric(id: "cpu", label: "CPU", value: 31, unit: "%", target: 100, displayValue: "31%"),
                        SurfaceMetric(id: "ram", label: "RAM", value: 62, unit: "%", target: 100, displayValue: "62%")
                    ]
                ),
                diagnostics: PluginDiagnostics(summary: "Fallback"),
                lastUpdated: .now
            )
        ]
    }

    private func runtimeSettings(from settings: AppSettings) -> HostPluginSettings {
        HostPluginSettings(
            weather: settings.weather,
            webWidget: settings.webWidget,
            mediaGallery: settings.mediaGallery
        )
    }

    private func resolvedRuntimeURL() -> URL {
        if let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("Runtime", isDirectory: true)
            .appendingPathComponent("node-host", isDirectory: true)
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("host.mjs"),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("runtime", isDirectory: true)
            .appendingPathComponent("node-host", isDirectory: true)
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("host.mjs")
    }

    private func resolvedPluginsURL() -> URL {
        if let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("Plugins", isDirectory: true),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("plugins", isDirectory: true)
    }

    private func resolvedNodeExecutableURL() -> URL? {
        let fileManager = FileManager.default

        let candidates = [
            Bundle.main.resourceURL?
                .appendingPathComponent("Runtime", isDirectory: true)
                .appendingPathComponent("node", isDirectory: false),
            URL(fileURLWithPath: "/opt/homebrew/bin/node"),
            URL(fileURLWithPath: "/usr/local/bin/node"),
            URL(fileURLWithPath: "/usr/bin/node")
        ].compactMap { $0 }

        if let envPath = ProcessInfo.processInfo.environment["MYCUE_NODE_PATH"], !envPath.isEmpty {
            let envURL = URL(fileURLWithPath: envPath)
            if fileManager.isExecutableFile(atPath: envURL.path) {
                return envURL
            }
        }

        return candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) })
    }
}

private enum PluginHostError: LocalizedError {
    case runtimeUnavailable

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            return "Plugin runtime is unavailable"
        }
    }
}
