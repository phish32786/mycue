import AppKit
import SwiftUI

private let devKitFrameAutosaveName = NSWindow.FrameAutosaveName("MyCue.DevKitWindow")
private let devKitAspectRatio = CGSize(width: 2560, height: 720)

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}

@MainActor
enum WindowPlacement {
    static func configure(_ window: NSWindow?, display: DisplayDescriptor?, kioskMode: Bool, devKitMode: Bool) {
        guard let window else { return }

        window.isOpaque = true
        window.backgroundColor = .black
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false

        guard !devKitMode, kioskMode, let display else {
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
            let targetStyle: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
            if window.styleMask != targetStyle {
                window.styleMask = targetStyle
            }
            if window.collectionBehavior != [.managed] {
                window.collectionBehavior = [.managed]
            }
            if window.level != .normal {
                window.level = .normal
            }
            if window.frameAutosaveName != devKitFrameAutosaveName {
                let restored = window.setFrameUsingName(devKitFrameAutosaveName, force: false)
                _ = window.setFrameAutosaveName(devKitFrameAutosaveName)
                if !restored, let screen = display.flatMap({ descriptor in
                    NSScreen.screens.first(where: { $0.displayIdentifier == descriptor.id })
                }) ?? NSScreen.main ?? NSScreen.screens.first {
                    let visible = screen.visibleFrame
                    let width = min(1440, visible.width - 120)
                    let height = width * (devKitAspectRatio.height / devKitAspectRatio.width)
                    let targetFrame = CGRect(
                        x: visible.midX - (width / 2),
                        y: visible.midY - (height / 2),
                        width: width,
                        height: height
                    ).integral
                    window.setFrame(targetFrame, display: true, animate: false)
                }
            }
            window.contentAspectRatio = devKitAspectRatio
            window.contentMinSize = CGSize(width: 960, height: 270)
            return
        }

        guard let screen = NSScreen.screens.first(where: { $0.displayIdentifier == display.id }) else { return }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        let targetStyle: NSWindow.StyleMask = [.borderless, .fullSizeContentView]
        if window.styleMask != targetStyle {
            window.styleMask = targetStyle
        }
        let targetBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenPrimary]
        if window.collectionBehavior != targetBehavior {
            window.collectionBehavior = targetBehavior
        }
        if window.level != .screenSaver {
            window.level = .screenSaver
        }
        if !window.frame.isApproximatelyEqual(to: screen.frame) {
            window.setFrame(screen.frame, display: true, animate: false)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private extension CGRect {
    func isApproximatelyEqual(to other: CGRect, tolerance: CGFloat = 1) -> Bool {
        abs(origin.x - other.origin.x) <= tolerance &&
        abs(origin.y - other.origin.y) <= tolerance &&
        abs(size.width - other.size.width) <= tolerance &&
        abs(size.height - other.size.height) <= tolerance
    }
}
