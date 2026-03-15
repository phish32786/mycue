import CoreGraphics
import Foundation

public struct RawTouchSample: Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var pressed: Bool

    public init(x: Int = 0, y: Int = 0, pressed: Bool = false) {
        self.x = x
        self.y = y
        self.pressed = pressed
    }
}

public struct CalibrationModel: Equatable, Codable, Sendable {
    public enum Corner: String, CaseIterable, Hashable, Codable, Sendable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight

        public var label: String {
            switch self {
            case .topLeft: "TL"
            case .topRight: "TR"
            case .bottomLeft: "BL"
            case .bottomRight: "BR"
            }
        }
    }

    private var points: [Corner: CGPoint] = [:]

    public init() {}

    public mutating func set(_ corner: Corner, point: CGPoint) {
        points[corner] = point
    }

    public func point(for corner: Corner) -> CGPoint? {
        points[corner]
    }

    public var missingCornersSummary: String {
        let missing = Corner.allCases.filter { points[$0] == nil }.map(\.label)
        if missing.isEmpty {
            return summary
        }
        return "Missing: \(missing.joined(separator: ", "))"
    }

    public var summary: String {
        Corner.allCases.compactMap { corner in
            guard let point = points[corner] else { return nil }
            return "\(corner.label)(\(Int(point.x)),\(Int(point.y)))"
        }
        .joined(separator: " ")
    }

    public func validationError() -> String? {
        guard let topLeft = points[.topLeft],
              let topRight = points[.topRight],
              let bottomLeft = points[.bottomLeft],
              let bottomRight = points[.bottomRight] else {
            return "Calibration incomplete"
        }

        let topWidth = distance(topLeft, topRight)
        let bottomWidth = distance(bottomLeft, bottomRight)
        let leftHeight = distance(topLeft, bottomLeft)
        let rightHeight = distance(topRight, bottomRight)

        if topWidth < 500 || bottomWidth < 500 || leftHeight < 500 || rightHeight < 500 {
            return "Calibration invalid: collapsed edges"
        }

        let diagonalOne = distance(topLeft, bottomRight)
        let diagonalTwo = distance(topRight, bottomLeft)
        if diagonalOne < 500 || diagonalTwo < 500 {
            return "Calibration invalid: collapsed quadrilateral"
        }

        let topMid = midpoint(topLeft, topRight)
        let bottomMid = midpoint(bottomLeft, bottomRight)
        if distance(topMid, bottomMid) < 500 {
            return "Calibration invalid: top and bottom overlap"
        }

        return nil
    }

    public func mappedPoint(for rawPoint: CGPoint, in bounds: CGRect) -> CGPoint? {
        guard validationError() == nil,
              let topLeft = points[.topLeft],
              let topRight = points[.topRight],
              let bottomLeft = points[.bottomLeft],
              let bottomRight = points[.bottomRight] else {
            return nil
        }

        guard let uv = invertBilinear(
            point: rawPoint,
            topLeft: topLeft,
            topRight: topRight,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight
        ) else {
            return nil
        }

        let clampedU = min(max(uv.x, 0), 1)
        let clampedV = min(max(uv.y, 0), 1)

        return CGPoint(
            x: bounds.minX + clampedU * bounds.width,
            y: bounds.minY + clampedV * bounds.height
        )
    }

    private func invertBilinear(
        point: CGPoint,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) -> CGPoint? {
        var u: CGFloat = 0.5
        var v: CGFloat = 0.5

        for _ in 0..<18 {
            let current = bilinear(
                u: u,
                v: v,
                topLeft: topLeft,
                topRight: topRight,
                bottomLeft: bottomLeft,
                bottomRight: bottomRight
            )
            let fx = current.x - point.x
            let fy = current.y - point.y

            if abs(fx) + abs(fy) < 0.5 {
                return CGPoint(x: u, y: v)
            }

            let du = bilinearDerivativeU(v: v, topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
            let dv = bilinearDerivativeV(u: u, topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
            let determinant = du.x * dv.y - du.y * dv.x
            if abs(determinant) < 0.0001 {
                return nil
            }

            let deltaU = (fx * dv.y - fy * dv.x) / determinant
            let deltaV = (fy * du.x - fx * du.y) / determinant
            u -= deltaU
            v -= deltaV
        }

        return CGPoint(x: u, y: v)
    }

    private func bilinear(
        u: CGFloat,
        v: CGFloat,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) -> CGPoint {
        let top = interpolate(from: topLeft, to: topRight, t: u)
        let bottom = interpolate(from: bottomLeft, to: bottomRight, t: u)
        return interpolate(from: top, to: bottom, t: v)
    }

    private func bilinearDerivativeU(
        v: CGFloat,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) -> CGPoint {
        CGPoint(
            x: (1 - v) * (topRight.x - topLeft.x) + v * (bottomRight.x - bottomLeft.x),
            y: (1 - v) * (topRight.y - topLeft.y) + v * (bottomRight.y - bottomLeft.y)
        )
    }

    private func bilinearDerivativeV(
        u: CGFloat,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) -> CGPoint {
        CGPoint(
            x: (1 - u) * (bottomLeft.x - topLeft.x) + u * (bottomRight.x - topRight.x),
            y: (1 - u) * (bottomLeft.y - topLeft.y) + u * (bottomRight.y - topRight.y)
        )
    }

    private func interpolate(from start: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * t,
            y: start.y + (end.y - start.y) * t
        )
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }
}

public struct DwellCalibrationState: Equatable, Sendable {
    public private(set) var activeCornerIndex = 0
    public private(set) var stableSample: CGPoint?
    public private(set) var holdProgress: TimeInterval = 0
    public private(set) var awaitingRelease = false
    public let requiredHoldDuration: TimeInterval = 1.0

    public init() {}

    public var activeCorner: CalibrationModel.Corner? {
        guard activeCornerIndex < CalibrationModel.Corner.allCases.count else { return nil }
        return CalibrationModel.Corner.allCases[activeCornerIndex]
    }

    public mutating func markComplete() {
        activeCornerIndex = CalibrationModel.Corner.allCases.count
        stableSample = nil
        holdProgress = requiredHoldDuration
        awaitingRelease = false
    }

    public mutating func advance() {
        activeCornerIndex += 1
        if activeCornerIndex >= CalibrationModel.Corner.allCases.count {
            markComplete()
            return
        }
        stableSample = nil
        holdProgress = 0
        awaitingRelease = true
    }

    public mutating func update(point: CGPoint?, pressed: Bool, delta: TimeInterval) -> Bool {
        guard activeCorner != nil else { return false }

        if awaitingRelease {
            if !pressed {
                awaitingRelease = false
            }
            stableSample = nil
            holdProgress = 0
            return false
        }

        guard pressed, let point else {
            stableSample = nil
            holdProgress = 0
            return false
        }

        if let stableSample, hypot(stableSample.x - point.x, stableSample.y - point.y) <= 160 {
            holdProgress += delta
        } else {
            stableSample = point
            holdProgress = delta
        }

        return holdProgress >= requiredHoldDuration
    }

    public var statusText: String {
        if awaitingRelease {
            return "Lift finger before next corner"
        }
        guard let activeCorner else {
            return "Calibration complete"
        }
        let percent = Int(min(max(holdProgress / requiredHoldDuration, 0), 1) * 100)
        return "Touch and hold \(activeCorner.label) (\(percent)%)"
    }
}

public enum CalibrationPersistence {
    public static func load() -> CalibrationModel? {
        let url = calibrationURL()
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CalibrationModel.self, from: data)
    }

    public static func save(_ model: CalibrationModel) throws {
        let url = calibrationURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(model)
        try data.write(to: url, options: .atomic)
    }

    public static func clear() throws {
        let url = calibrationURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public static func calibrationURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("MyCue", isDirectory: true)
            .appendingPathComponent("calibration.json")
    }
}
