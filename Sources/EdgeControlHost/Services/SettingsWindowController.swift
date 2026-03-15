import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController {
    private weak var window: NSWindow?
    private weak var model: AppModel?

    public init() {}

    public func show(model: AppModel) {
        self.model = model

        let settingsWindow: NSWindow
        if let existing = self.window {
            settingsWindow = existing
        } else {
            let content = AnyView(
                SettingsView()
                    .environmentObject(model)
            )

            let hosting = NSHostingController(rootView: content)
            let created = NSWindow(contentViewController: hosting)
            created.title = "MyCue Settings"
            created.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            created.isReleasedWhenClosed = false
            created.level = .normal
            created.setContentSize(NSSize(width: 860, height: 760))
            created.center()
            self.window = created
            settingsWindow = created
        }

        if let hosting = settingsWindow.contentViewController as? NSHostingController<AnyView> {
            hosting.rootView = AnyView(
                SettingsView()
                    .environmentObject(model)
            )
        }

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let size = settingsWindow.frame.size
            let frame = CGRect(
                x: visible.midX - (size.width / 2),
                y: visible.midY - (size.height / 2),
                width: size.width,
                height: size.height
            )
            settingsWindow.setFrame(frame, display: true)
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.makeKeyAndOrderFront(nil)
    }
}
