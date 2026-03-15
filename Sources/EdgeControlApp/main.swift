import EdgeControlHost
import AppKit
import SwiftUI

@main
struct EdgeControlExecutableApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("MyCue Dashboard", id: "dashboard") {
            RootDashboardView()
                .environmentObject(model)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    model.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Pages") {
                Button("Previous Page") {
                    model.selectAdjacentPage(offset: -1)
                }
                .keyboardShortcut("[", modifiers: [.command, .option])

                Button("Next Page") {
                    model.selectAdjacentPage(offset: 1)
                }
                .keyboardShortcut("]", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit MyCue") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
}
