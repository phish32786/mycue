import SwiftUI

struct DashboardHeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.settings.debugMode {
                operationalHeader
            } else {
                hardwareOverlay
            }
        }
    }

    private var operationalHeader: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.isDevKitMode ? "DevKit" : "Dashboard")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(model.isDevKitMode ? "DevKit Mode • \(model.selectedDisplay?.summary ?? "Windowed")" : (model.selectedDisplay?.summary ?? "No display selected"))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
                if !model.isDevKitMode, model.settings.debugMode {
                    Text("\(model.touchState.hidStatus) • \(model.touchState.calibrationStatus)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            Spacer()

            editModeButton
            settingsButton
        }
        .padding(.horizontal, 28)
    }

    private var hardwareOverlay: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                ZStack(alignment: .bottomTrailing) {
                    if model.dashboardControlsVisible || model.isLayoutEditMode {
                        HStack(spacing: 10) {
                            editModeButton
                            settingsButton
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        revealHotspot
                    }
                }
            }
        }
        .padding(.trailing, 18)
        .padding(.bottom, 18)
    }

    private var settingsButton: some View {
                    Button {
                        model.openSettingsWindow()
                        model.hideDashboardControls()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .reportActionFrame(pluginID: "__host__", actionID: "openSettings")
    }

    private var editModeButton: some View {
        Button {
            model.setLayoutEditMode(!model.isLayoutEditMode)
        } label: {
            Label(model.isLayoutEditMode ? "Done" : "Edit", systemImage: model.isLayoutEditMode ? "checkmark.circle.fill" : "slider.horizontal.3")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background((model.isLayoutEditMode ? Color.mint : .black).opacity(model.isLayoutEditMode ? 0.24 : 0.28), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(.white.opacity(model.isLayoutEditMode ? 0.20 : 0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .reportActionFrame(pluginID: "__host__", actionID: "toggleLayoutEditMode")
    }

    private var revealHotspot: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                model.revealDashboardControlsTemporarily()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .bold))

                Text("CTL")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(0.8)
            }
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .reportActionFrame(pluginID: "__host__", actionID: "revealSettings")
    }
}
