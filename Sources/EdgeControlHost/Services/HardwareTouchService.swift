import CoreGraphics
import EdgeControlShared
import Foundation
import IOKit.hid
import SwiftUI

private enum TouchLogger {
    private static let logURL: URL = {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library", isDirectory: true)
        let directory = base.appendingPathComponent("Logs/MyCue", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("touch.log")
    }()

    static func log(_ message: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
            return
        }
        try? data.write(to: logURL, options: .atomic)
    }
}

@MainActor
protocol TouchInputSource: AnyObject {
    var onSample: ((RawTouchSample) -> Void)? { get set }
    var onOpenStatus: ((String) -> Void)? { get set }
    func start()
    func stop()
}

@MainActor
final class HIDTouchInputSource: NSObject, TouchInputSource {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    var onSample: ((RawTouchSample) -> Void)?
    var onOpenStatus: ((String) -> Void)?
    private var sample = RawTouchSample()
    private var started = false
    private var openedDevices: [IOHIDDevice] = []

    func start() {
        guard !started else { return }
        started = true
        TouchLogger.log("touch source start")

        let matchings: [[String: Any]] = [
            [
                kIOHIDVendorIDKey as String: 10176,
                kIOHIDProductIDKey as String: 2137,
                kIOHIDPrimaryUsagePageKey as String: 1,
                kIOHIDPrimaryUsageKey as String: 2
            ],
            [
                kIOHIDVendorIDKey as String: 10176,
                kIOHIDProductIDKey as String: 2137,
                kIOHIDPrimaryUsagePageKey as String: 13,
                kIOHIDPrimaryUsageKey as String: 4
            ],
            [
                kIOHIDVendorIDKey as String: 10176,
                kIOHIDProductIDKey as String: 2137,
                kIOHIDPrimaryUsagePageKey as String: 65290,
                kIOHIDPrimaryUsageKey as String: 255
            ]
        ]

        IOHIDManagerSetDeviceMatchingMultiple(manager, matchings as CFArray)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            let source = Unmanaged<HIDTouchInputSource>.fromOpaque(context).takeUnretainedValue()
            source.handle(value: value)
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
            guard let context else { return }
            let source = Unmanaged<HIDTouchInputSource>.fromOpaque(context).takeUnretainedValue()
            source.openMatchedDevicesIfNeeded()
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, _ in
            guard let context else { return }
            let source = Unmanaged<HIDTouchInputSource>.fromOpaque(context).takeUnretainedValue()
            source.refreshOpenStatus()
        }, Unmanaged.passUnretained(self).toOpaque())

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if result != kIOReturnSuccess {
            let status = "manager open failed (\(result))"
            TouchLogger.log(status)
            onOpenStatus?(status)
            return
        }

        openMatchedDevicesIfNeeded()
    }

    func stop() {
        guard started else { return }
        TouchLogger.log("touch source stop")
        openedDevices.forEach { device in
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        openedDevices.removeAll()
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        started = false
    }

    private func openMatchedDevicesIfNeeded() {
        let devices = ((IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? [])
            .sorted { lhs, rhs in
                usageSortKey(lhs) < usageSortKey(rhs)
            }

        openedDevices = devices.filter { device in
            guard !openedDevices.contains(where: { $0 === device }) else { return true }
            IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
            let usage = usageDescription(device)
            let success = result == kIOReturnSuccess
            TouchLogger.log("device \(usage) open \(success ? "ok" : "failed (\(result))")")
            if !success {
                IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            }
            return success
        }

        refreshOpenStatus()
    }

    private func refreshOpenStatus() {
        let devices = ((IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? [])
        let held = openedDevices.filter { current in
            devices.contains(where: { $0 === current })
        }
        openedDevices = held

        let total = devices.count
        let active = held.count
        let status: String
        switch (active, total) {
        case (_, 0):
            status = "no XENEON HID devices found"
        case let (active, total) where active == total:
            status = "seize active (\(active)/\(total))"
        case (0, let total):
            status = "seize failed (0/\(total))"
        default:
            status = "partial seize (\(active)/\(total))"
        }
        TouchLogger.log(status)
        onOpenStatus?(status)
    }

    private func usageSortKey(_ device: IOHIDDevice) -> String {
        usageDescription(device)
    }

    private func usageDescription(_ device: IOHIDDevice) -> String {
        let usagePage = (IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? NSNumber)?.intValue ?? -1
        let usage = (IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? NSNumber)?.intValue ?? -1
        return "u\(usagePage):\(usage)"
    }

    private func handle(value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        switch (IOHIDElementGetUsagePage(element), IOHIDElementGetUsage(element)) {
        case (1, 48):
            sample.x = IOHIDValueGetIntegerValue(value)
        case (1, 49):
            sample.y = IOHIDValueGetIntegerValue(value)
        case (9, 1):
            sample.pressed = IOHIDValueGetIntegerValue(value) != 0
        default:
            return
        }

        onSample?(sample)
    }
}

@MainActor
public final class HardwareTouchService: ObservableObject {
    @Published public private(set) var state = TouchRuntimeState()

    private var touchSource: TouchInputSource?
    private var calibration = CalibrationModel()
    private var dwellCalibration = DwellCalibrationState()
    private var latestSample = RawTouchSample()
    private var renderBounds = CGRect(x: 0, y: 0, width: 2560, height: 720)
    private var timer: Timer?
    private var hidStatus = "starting"
    private var eventSequence = 0
    private var pressSequence = 0
    private var previousPressed = false

    public init() {}

    public func start() {
        stop()
        TouchLogger.log("hardware touch service start")

        if let saved = CalibrationPersistence.load() {
            calibration = saved
            if saved.validationError() == nil {
                dwellCalibration.markComplete()
            }
        }

        let source = HIDTouchInputSource()
        source.onSample = { [weak self] sample in
            self?.handle(sample: sample)
        }
        source.onOpenStatus = { [weak self] status in
            guard let self else { return }
            self.hidStatus = status
            self.eventSequence += 1
            self.refreshState()
        }
        source.start()
        touchSource = source

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickCalibration(delta: 1.0 / 30.0)
            }
        }
        refreshState()
    }

    public func stop() {
        TouchLogger.log("hardware touch service stop")
        timer?.invalidate()
        timer = nil
        touchSource?.stop()
        touchSource = nil
        latestSample = RawTouchSample()
        hidStatus = "inactive"
        eventSequence = 0
        pressSequence = 0
        previousPressed = false
        state = TouchRuntimeState()
    }

    public func updateRenderBounds(_ bounds: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        renderBounds = bounds
        refreshState()
    }

    public func resetCalibration() {
        calibration = CalibrationModel()
        dwellCalibration = DwellCalibrationState()
        try? CalibrationPersistence.clear()
        refreshState()
    }

    private func handle(sample: RawTouchSample) {
        if sample.pressed && !previousPressed {
            pressSequence += 1
        }
        previousPressed = sample.pressed
        eventSequence += 1
        latestSample = sample
        refreshState()
    }

    private func tickCalibration(delta: TimeInterval) {
        if let corner = dwellCalibration.activeCorner {
            let rawPoint = CGPoint(x: latestSample.x, y: latestSample.y)
            if dwellCalibration.update(point: rawPoint, pressed: latestSample.pressed, delta: delta) {
                calibration.set(corner, point: rawPoint)
                try? CalibrationPersistence.save(calibration)
                dwellCalibration.advance()
            }
            refreshState()
        }
    }

    private func refreshState() {
        let rawPoint = CGPoint(x: latestSample.x, y: latestSample.y)
        let validation = calibration.validationError()
        let mappedPoint = validation == nil ? calibration.mappedPoint(for: rawPoint, in: renderBounds) : nil
        state = TouchRuntimeState(
            rawSample: latestSample,
            mappedPoint: mappedPoint,
            hidStatus: hidStatus,
            calibrationStatus: dwellCalibration.statusText,
            calibrationValidation: validation ?? "Calibrated",
            calibrationSummary: calibration.summary,
            isCalibrated: validation == nil,
            isPressed: latestSample.pressed,
            sequence: eventSequence,
            pressSequence: pressSequence
        )
    }
}
