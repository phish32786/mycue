import EdgeControlShared
import SwiftUI

struct PluginTileView: View {
    @EnvironmentObject private var model: AppModel
    let plugin: PluginSnapshot

    var body: some View {
        GeometryReader { geometry in
            let scale = contentScale(for: geometry.size.width)

            VStack(alignment: .leading, spacing: 0) {
                innerSurfacePanel

                if !model.isLayoutEditMode && plugin.status == .degraded {
                    degradedBanner
                        .padding(.top, 8)
                }

                if !model.isLayoutEditMode && !plugin.surface.actions.isEmpty && plugin.surface.kind != .spotify && plugin.status != .failed {
                    HStack(spacing: 8) {
                        ForEach(plugin.surface.actions) { action in
                            Button {
                                model.perform(action: action, pluginID: plugin.id)
                            } label: {
                                Text(action.title.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.90))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .reportActionFrame(pluginID: plugin.id, actionID: action.id)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(10)
            .frame(
                width: geometry.size.width / scale,
                height: geometry.size.height / scale,
                alignment: .topLeading
            )
            .scaleEffect(scale, anchor: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(model.isLayoutEditMode ? .white.opacity(0.22) : .white.opacity(0.10), lineWidth: model.isLayoutEditMode ? 2 : 1)

                if model.isLayoutEditMode {
                    layoutEditorOverlay
                        .padding(10)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .inset(by: 1)
                .strokeBorder(.black.opacity(0.62), lineWidth: 1)
        )
        .onAppear {
            model.debugOverlay.didRenderFrame()
        }
    }

    private var usesFullBleedSurface: Bool {
        switch plugin.surface.kind {
        case .spotify, .webWidget, .mediaGallery:
            return true
        default:
            return false
        }
    }

    private func contentScale(for width: CGFloat) -> CGFloat {
        guard model.isDevKitMode else { return 1 }
        let scale = width / 420
        return min(1, max(0.68, scale))
    }

    @ViewBuilder
    private var surfaceBody: some View {
        switch plugin.surface.kind {
        case .systemStats:
            SystemStatsSurfaceView(surface: plugin.surface)
        case .spotify:
            SpotifySurfaceView(surface: plugin.surface, pluginID: plugin.id)
        case .weather:
            WeatherSurfaceView(surface: plugin.surface)
        case .launcher:
            LauncherSurfaceView(surface: plugin.surface, pluginID: plugin.id)
        case .webWidget:
            WebWidgetSurfaceView(settings: model.settings.webWidget)
        case .mediaGallery:
            MediaGallerySurfaceView(settings: model.settings.mediaGallery)
        case .custom:
            Text(plugin.surface.detail ?? "Custom plugin surface")
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var innerSurfacePanel: some View {
        Group {
            if plugin.status == .failed {
                failedSurface
            } else {
                surfaceBody
            }
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(usesFullBleedSurface ? 0 : 6)
            .background(innerPanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }

    private var degradedBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("DEGRADED")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))

            Text(plugin.diagnostics.summary.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.60))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button("RECOVER") {
                model.restartPluginRuntime()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.90))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var failedSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(plugin.manifest.name.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("PLUGIN FAILURE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange.opacity(0.88))
                Text(plugin.diagnostics.summary.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(2)
            }

            if let detail = plugin.diagnostics.lastError ?? plugin.surface.detail ?? plugin.diagnostics.detail {
                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(5)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                failureButton(title: "RESTART RUNTIME") {
                    model.restartPluginRuntime()
                }

                failureButton(title: model.isPluginEnabled(plugin) ? "DISABLE" : "ENABLE") {
                    model.togglePlugin(plugin.id, enabled: !model.isPluginEnabled(plugin))
                }
            }
        }
        .padding(14)
    }

    private func failureButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var tileBackground: some View {
        return ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.12)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.01),
                    Color.clear,
                    Color.black.opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var innerPanelBackground: some View {
        return ZStack {
            Color(red: 0.17, green: 0.17, blue: 0.18)
            LinearGradient(
                colors: [
                    .white.opacity(0.02),
                    .clear,
                    .black.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var layoutEditorOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Edit")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )

                Spacer(minLength: 0)

                editorButton(
                    title: "Left",
                    systemImage: "arrow.left",
                    actionID: "layout.moveLeft"
                )

                editorButton(
                    title: model.cardSpan(for: plugin.id).title,
                    systemImage: "rectangle.split.3x1",
                    actionID: "layout.cycleSpan"
                )

                editorButton(
                    title: "Right",
                    systemImage: "arrow.right",
                    actionID: "layout.moveRight"
                )
            }

            Spacer(minLength: 0)
        }
    }

    private func editorButton(title: String, systemImage: String, actionID: String) -> some View {
        Button {
            model.perform(action: SurfaceAction(id: actionID, title: title, icon: systemImage), pluginID: plugin.id)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.94))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .reportActionFrame(pluginID: plugin.id, actionID: actionID)
    }
}
