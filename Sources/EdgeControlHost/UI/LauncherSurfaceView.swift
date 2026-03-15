import EdgeControlShared
import SwiftUI

struct LauncherSurfaceView: View {
    @EnvironmentObject private var model: AppModel
    let surface: DashboardSurface
    let pluginID: String

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let detail = surface.detail {
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.60))
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(surface.actions) { action in
                    Button {
                        model.perform(action: action, pluginID: pluginID)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.system(size: 22, weight: .semibold))
                            Text(action.title)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .multilineTextAlignment(.leading)
                            if let role = action.role {
                                Text(role)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                        .padding(12)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .reportActionFrame(pluginID: pluginID, actionID: action.id)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
