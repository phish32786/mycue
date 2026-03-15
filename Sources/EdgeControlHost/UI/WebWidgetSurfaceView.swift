import EdgeControlShared
import SwiftUI
import WebKit

struct WebWidgetSurfaceView: View {
    let settings: WebWidgetSettings

    var body: some View {
        Group {
            if normalizedURL != nil {
                WebWidgetRepresentable(url: normalizedURL!)
            } else {
                invalidURLState
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var normalizedURL: URL? {
        if let url = URL(string: settings.urlString), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(settings.urlString)")
    }

    private var invalidURLState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invalid URL")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text("Update the web widget URL in Settings to load a valid `https://` page.")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
            Text(settings.urlString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(.black.opacity(0.22))
    }
}

private struct WebWidgetRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}
