import CoreGraphics
import Testing
@testable import EdgeControlShared

@Test
func calibrationRejectsCollapsedEdges() {
    var calibration = CalibrationModel()
    calibration.set(.topLeft, point: CGPoint(x: 100, y: 100))
    calibration.set(.topRight, point: CGPoint(x: 120, y: 100))
    calibration.set(.bottomLeft, point: CGPoint(x: 100, y: 130))
    calibration.set(.bottomRight, point: CGPoint(x: 120, y: 130))

    #expect(calibration.validationError() == "Calibration invalid: collapsed edges")
}

@Test
func calibrationMapsValidPointIntoBounds() {
    var calibration = CalibrationModel()
    calibration.set(.topLeft, point: CGPoint(x: 153, y: 387))
    calibration.set(.topRight, point: CGPoint(x: 16191, y: 387))
    calibration.set(.bottomLeft, point: CGPoint(x: 83, y: 9479))
    calibration.set(.bottomRight, point: CGPoint(x: 16230, y: 9239))

    let mapped = calibration.mappedPoint(for: CGPoint(x: 8200, y: 4900), in: CGRect(x: 0, y: 0, width: 2560, height: 720))
    #expect(mapped != nil)
    #expect(mapped!.x > 0)
    #expect(mapped!.y > 0)
}
