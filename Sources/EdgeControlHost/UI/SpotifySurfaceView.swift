import EdgeControlShared
import SwiftUI

struct SpotifySurfaceView: View {
    @EnvironmentObject private var model: AppModel
    let surface: DashboardSurface
    let pluginID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            hero
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if let media = surface.media {
                footer(media: media)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            if let media = surface.media, let artworkURL = media.artworkURL, let url = URL(string: artworkURL) {
                GeometryReader { geometry in
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                            .clipped()
                    } placeholder: {
                        Color.clear
                            .overlay {
                                ProgressView()
                                    .tint(.white.opacity(0.7))
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .overlay(
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            if let media = surface.media {
                VStack(alignment: .leading, spacing: 4) {
                    Text(media.title)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                    Text("\(media.artist) • \(media.album)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                    Text(surface.detail ?? "")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.60))
                        .textCase(.uppercase)
                }
                .padding(12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    private func footer(media: MediaSurface) -> some View {
        VStack(spacing: 7) {
            ProgressView(value: media.progress)
                .progressViewStyle(.linear)
                .tint(.white)
            HStack {
                Text(media.elapsedText)
                Spacer()
                Text(media.durationText)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.60))

            HStack(spacing: 10) {
                ForEach(surface.actions) { action in
                    Button {
                        model.perform(action: action, pluginID: pluginID)
                    } label: {
                        Label(action.title, systemImage: action.icon)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 40, height: 38)
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
                    .reportActionFrame(pluginID: pluginID, actionID: action.id)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(media.deviceName ?? "Mac")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                    Text("Volume \(Int(media.volume * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.60))
                        .textCase(.uppercase)
                }
            }
        }
    }
}
