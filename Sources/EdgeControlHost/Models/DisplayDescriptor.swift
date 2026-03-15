import AppKit
import CoreGraphics
import Foundation

public struct DisplayDescriptor: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let width: Int
    public let height: Int
    public let isMain: Bool
    public let scale: Double

    public var summary: String {
        "\(name) • \(width)x\(height)\(isMain ? " • Main" : "")"
    }
}

extension NSScreen {
    var displayIdentifier: String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = deviceDescription[key] as? NSNumber {
            return "\(number.uint32Value)"
        }
        return localizedName
    }

    var displayDescriptor: DisplayDescriptor {
        let frame = frame.integral
        return DisplayDescriptor(
            id: displayIdentifier,
            name: localizedName,
            width: Int(frame.width),
            height: Int(frame.height),
            isMain: self == NSScreen.main,
            scale: backingScaleFactor
        )
    }
}
