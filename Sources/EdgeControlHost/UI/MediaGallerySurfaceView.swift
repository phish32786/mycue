import Combine
import EdgeControlShared
import SwiftUI

struct MediaGallerySurfaceView: View {
    let settings: MediaGallerySettings

    @State private var currentIndex = 0

    @ViewBuilder
    var body: some View {
        if imageURLs.isEmpty {
            emptyState
        } else {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geometry in
                    Image(nsImage: NSImage(contentsOf: imageURLs[currentIndex]) ?? NSImage())
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.58)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(imageURLs[currentIndex].deletingPathExtension().lastPathComponent)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(folderLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
            .onReceive(timer) { _ in
                guard imageURLs.count > 1 else { return }
                currentIndex = (currentIndex + 1) % imageURLs.count
            }
            .onChange(of: imageURLs.map(\.path)) { _, _ in
                currentIndex = 0
            }
        }
    }

    private var folderURL: URL? {
        guard !settings.folderPath.isEmpty else { return nil }
        return URL(fileURLWithPath: settings.folderPath)
    }

    private var imageURLs: [URL] {
        guard let folderURL else { return [] }
        let urls = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []
        let filtered = urls.filter { url in
            ["png", "jpg", "jpeg", "heic", "gif", "webp"].contains(url.pathExtension.lowercased())
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        if settings.shuffle {
            return filtered.shuffled()
        }
        return filtered
    }

    private var folderLabel: String {
        folderURL?.lastPathComponent ?? "No folder selected"
    }

    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: max(2, settings.intervalSeconds), on: .main, in: .common).autoconnect()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No media found")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text(settings.folderPath.isEmpty
                 ? "Choose a local image folder in Settings to turn this card into a slideshow."
                 : "The selected folder does not contain supported image files.")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
            if !settings.folderPath.isEmpty {
                Text(settings.folderPath)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}
