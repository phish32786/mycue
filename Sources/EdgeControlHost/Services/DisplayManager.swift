import AppKit
import Foundation

@MainActor
public final class DisplayManager {
    public init() {}

    public func availableDisplays() -> [DisplayDescriptor] {
        NSScreen.screens.map(\.displayDescriptor)
    }

    public func hardwareTargetScreen() -> NSScreen? {
        if let named = NSScreen.screens.first(where: { $0.localizedName.localizedCaseInsensitiveContains("XENEON EDGE") }) {
            return named
        }

        if let exact = NSScreen.screens.first(where: {
            let frame = $0.frame.integral
            return Int(frame.width) == 2560 && Int(frame.height) == 720
        }) {
            return exact
        }

        return nil
    }

    public func preferredWindowedScreen() -> NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }

    public func selectedScreen(for settings: AppSettings) -> NSScreen? {
        if let hardware = hardwareTargetScreen() {
            if let selectedID = settings.selectedDisplayID,
               let explicit = NSScreen.screens.first(where: { $0.displayIdentifier == selectedID }),
               explicit.displayIdentifier == hardware.displayIdentifier {
                return explicit
            }
            return hardware
        }

        if let selectedID = settings.selectedDisplayID,
           let explicit = NSScreen.screens.first(where: { $0.displayIdentifier == selectedID }) {
            return explicit
        }

        return preferredWindowedScreen()
    }
}
