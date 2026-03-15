import CoreGraphics
import Testing
@testable import EdgeControlShared

@Test
func dwellCalibrationRequiresStableHoldBeforeAdvancing() {
    var dwell = DwellCalibrationState()
    let point = CGPoint(x: 1200, y: 800)

    #expect(dwell.activeCorner == .topLeft)
    #expect(dwell.update(point: point, pressed: true, delta: 0.4) == false)
    #expect(dwell.update(point: point, pressed: true, delta: 0.4) == false)
    #expect(dwell.update(point: point, pressed: true, delta: 0.3) == true)

    dwell.advance()
    #expect(dwell.activeCorner == .topRight)
    #expect(dwell.awaitingRelease == true)
}
