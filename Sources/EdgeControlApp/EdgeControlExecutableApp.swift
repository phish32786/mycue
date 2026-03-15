import AppKit
import EdgeControlHost
import Darwin
import SwiftUI

@MainActor
final class DashboardWindowController {
    private var window: NSWindow?

    func show(model: AppModel) {
        let dashboardWindow: NSWindow
        if let existing = window {
            dashboardWindow = existing
        } else {
            let hosting = NSHostingController(
                rootView: AnyView(
                    RootDashboardView()
                        .environmentObject(model)
                )
            )
            let created = NSWindow(contentViewController: hosting)
            created.title = "MyCue Dashboard"
            created.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            created.isReleasedWhenClosed = false
            created.setContentSize(NSSize(width: 1440, height: 405))
            window = created
            dashboardWindow = created
        }

        if let hosting = dashboardWindow.contentViewController as? NSHostingController<AnyView> {
            hosting.rootView = AnyView(
                RootDashboardView()
                    .environmentObject(model)
            )
        }

        dashboardWindow.orderFrontRegardless()
        dashboardWindow.makeKeyAndOrderFront(nil)
    }
}

@MainActor
final class EdgeControlAppDelegate: NSObject, NSApplicationDelegate {
    private let model: AppModel
    private let dashboardWindowController = DashboardWindowController()

    init(model: AppModel) {
        self.model = model
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = buildMainMenu()
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
        }
        dashboardWindowController.show(model: model)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.forEach { window in
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    @objc private func openSettings(_ sender: Any?) {
        model.openSettingsWindow()
    }

    @objc private func previousPage(_ sender: Any?) {
        model.selectAdjacentPage(offset: -1)
    }

    @objc private func nextPage(_ sender: Any?) {
        model.selectAdjacentPage(offset: 1)
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Settings...",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit MyCue",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let pagesMenuItem = NSMenuItem(title: "Pages", action: nil, keyEquivalent: "")
        let pagesMenu = NSMenu(title: "Pages")
        let previousItem = NSMenuItem(
            title: "Previous Page",
            action: #selector(previousPage(_:)),
            keyEquivalent: "["
        )
        previousItem.keyEquivalentModifierMask = [.command, .option]
        let nextItem = NSMenuItem(
            title: "Next Page",
            action: #selector(nextPage(_:)),
            keyEquivalent: "]"
        )
        nextItem.keyEquivalentModifierMask = [.command, .option]
        pagesMenu.addItem(previousItem)
        pagesMenu.addItem(nextItem)
        pagesMenuItem.submenu = pagesMenu
        mainMenu.addItem(pagesMenuItem)

        return mainMenu
    }
}

@main
enum EdgeControlExecutableApp {
    static func main() {
        signal(SIGPIPE, SIG_IGN)
        let model = AppModel()
        model.startIfNeeded()
        let app = NSApplication.shared
        let delegate = EdgeControlAppDelegate(model: model)
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
