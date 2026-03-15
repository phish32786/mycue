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
    private struct AppliedConfiguration: Equatable {
        let mode: String
        let displayID: String?
        let frame: CGRect
    }

    private static var appliedConfigurations: [ObjectIdentifier: AppliedConfiguration] = [:]

    static func configure(_ window: NSWindow?, display: DisplayDescriptor?, kioskMode: Bool, devKitMode: Bool) {
        guard let window else { return }
        let windowID = ObjectIdentifier(window)

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
            appliedConfigurations[windowID] = AppliedConfiguration(
                mode: "windowed",
                displayID: display?.id,
                frame: window.frame
            )
            return
        }

        guard let screen = NSScreen.screens.first(where: { $0.displayIdentifier == display.id }) else { return }

        if prefersBundledSafeHardwarePresentation {
            let safeFrame = screen.visibleFrame.insetBy(dx: 12, dy: 12)
            let targetConfiguration = AppliedConfiguration(
                mode: "hardware-safe",
                displayID: display.id,
                frame: safeFrame
            )
            let needsPresentationUpdate = appliedConfigurations[windowID] != targetConfiguration

            let targetStyle: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
            if window.styleMask != targetStyle {
                window.styleMask = targetStyle
            }
            window.title = "MyCue Dashboard"
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
            if window.collectionBehavior != [.managed] {
                window.collectionBehavior = [.managed]
            }
            if window.level != .normal {
                window.level = .normal
            }

            if !window.frame.isApproximatelyEqual(to: safeFrame) {
                window.setFrame(safeFrame, display: true, animate: false)
            }
            if needsPresentationUpdate {
                window.setFrameOrigin(safeFrame.origin)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
            appliedConfigurations[windowID] = targetConfiguration
            return
        }

        let targetConfiguration = AppliedConfiguration(
            mode: "hardware-kiosk",
            displayID: display.id,
            frame: screen.frame
        )
        let needsPresentationUpdate = appliedConfigurations[windowID] != targetConfiguration

        if window.frameAutosaveName != "" {
            window.setFrameAutosaveName("")
        }
        window.isReleasedWhenClosed = false
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
        if needsPresentationUpdate {
            window.setFrameOrigin(screen.frame.origin)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        appliedConfigurations[windowID] = targetConfiguration
    }

    private static var prefersBundledSafeHardwarePresentation: Bool {
        ProcessInfo.processInfo.environment["MYCUE_SAFE_WINDOW_MODE"] == "1"
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
