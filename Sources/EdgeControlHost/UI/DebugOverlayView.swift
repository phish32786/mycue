import SwiftUI

struct DebugOverlayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEBUG")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text("Mode: \(model.isDevKitMode ? "devkit" : "hardware")")
            Text("Display: \(model.debugOverlay.selectedDisplayName)")
            Text("Runtime: \(model.debugOverlay.runtimeConnected ? "connected" : "offline")")
            Text("Plugins: \(model.debugOverlay.pluginCount)")
            Text("HID: \(model.debugOverlay.hidStatus)")
            Text("Touch: \(model.debugOverlay.touchStatus)")
            Text("Map: \(model.debugOverlay.touchPointDescription)")
                .lineLimit(2)
            Text("Validation: \(model.debugOverlay.calibrationValidation)")
                .lineLimit(2)
            Text("Tiles rendered: \(model.debugOverlay.renderedFrames)")
            Divider().overlay(.white.opacity(0.22))
            ForEach(model.debugOverlay.pluginStatuses.prefix(4), id: \.self) { status in
                Text(status)
                    .lineLimit(1)
            }
            Divider().overlay(.white.opacity(0.12))
            ForEach(model.debugOverlay.recentLogs.prefix(6)) { log in
                Text("[\(log.level)] \(log.pluginID ?? "host"): \(log.message)")
                    .lineLimit(2)
            }
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.white.opacity(0.86))
        .padding(14)
        .frame(width: 420, alignment: .leading)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}
