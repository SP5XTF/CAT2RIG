import XCTest
@testable import CAT2RIGCore

final class MetersTests: XCTestCase {

    func testConversions() {
        XCTAssertEqual(Meters.interpolate(120, Meters.icomSMeter), 0)          // S9
        XCTAssertEqual(Meters.interpolate(0, Meters.icomSMeter), -54)          // S0
        XCTAssertEqual(Meters.interpolate(241, Meters.icomSMeter), 60)
        XCTAssertEqual(Meters.interpolate(300, Meters.icomSMeter), 60)         // poza skalą
        XCTAssertEqual(Meters.interpolate(130, Meters.yaesuSMeter), 0)
        XCTAssertEqual(Meters.interpolate(143, Meters.icomPower), 50)
        XCTAssertEqual(Meters.interpolate(205, Meters.yaesuPower), 100)
        XCTAssertEqual(Meters.ft817SMeter(9), 0)
        XCTAssertEqual(Meters.ft817SMeter(0), -54)
        XCTAssertEqual(Meters.ft817SMeter(15), 60)
        XCTAssertEqual(Meters.bcd2(0x01, 0x20), 120)
        XCTAssertNil(Meters.bcd2(0x0A, 0x00))
    }

    func testTextAndScale() {
        XCTAssertEqual(Meters.sText(-54), "S0")
        XCTAssertEqual(Meters.sText(-12), "S7")
        XCTAssertEqual(Meters.sText(0), "S9")
        XCTAssertEqual(Meters.sText(20), "S9+20")
        XCTAssertEqual(Meters.sFraction(-54), 0)
        XCTAssertEqual(Meters.sFraction(0), 0.6, accuracy: 1e-9)
        XCTAssertEqual(Meters.sFraction(60), 1)
        XCTAssertEqual(Meters.sFraction(99), 1)
    }
}

final class MeterReadingTests: XCTestCase {

    func testIcomSMeterAndRigctl() {
        let radio = FakeRadio(addr: 0x94)
        radio.sRaw = 120
        let rig = makeBackend("ic7300", radio, pttMethod: .cat)
        XCTAssertTrue(waitUntil { rig.state.sMeterDB == 0 })
        XCTAssertEqual(RigctlProtocol.dispatch(rig, "l STRENGTH"), "0\n")
        radio.sRaw = 0
        XCTAssertTrue(waitUntil { rig.state.sMeterDB == -54 })
    }

    func testIcomPowerDuringTX() {
        let radio = FakeRadio(addr: 0x94)
        radio.poRaw = 143
        let rig = makeBackend("ic7300", radio, pttMethod: .cat)
        XCTAssertNil(rig.state.powerPercent, "moc tylko podczas nadawania")
        XCTAssertEqual(RigctlProtocol.dispatch(rig, "l RFPOWER_METER"), "0.000000\n")
        _ = rig.setPTT(true)
        XCTAssertTrue(waitUntil { rig.state.powerPercent == 50 })
        XCTAssertNil(rig.state.sMeterDB, "S-metr nie jest pokazywany podczas nadawania")
        XCTAssertEqual(RigctlProtocol.dispatch(rig, "l RFPOWER_METER"), "0.500000\n")
        _ = rig.setPTT(false)
    }

    func testIC706HasNoPowerMeter() {
        let radio = FakeRadio(addr: 0x58)
        let rig = makeBackend("ic706mk2g", radio, pttMethod: .rts)
        XCTAssertTrue(waitUntil { rig.state.sMeterDB != nil }, "IC-706MKIIG podaje S-metr (15 02)")
        _ = rig.setPTT(true)
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertNil(rig.state.powerPercent)
        XCTAssertFalse(radio.writtenFrames.contains { $0.count > 5 && $0[4] == 0x15 && $0[5] == 0x11 },
                       "do IC-706 nie wysyłamy 15 11")
        _ = rig.setPTT(false)
    }

    func testYaesuMeters() {
        let radio = FakeTextRadio(kind: .yaesu)
        radio.sRaw = 172                                               // S9+20
        radio.poRaw = 147                                              // 50 %
        let rig = makeBackend("ft710", radio, pttMethod: .cat)
        XCTAssertTrue(waitUntil { rig.state.sMeterDB == 20 })
        _ = rig.setPTT(true)
        XCTAssertTrue(waitUntil { rig.state.powerPercent == 50 })
        _ = rig.setPTT(false)
    }

    func testKenwoodHasNoMetersYet() {
        let radio = FakeTextRadio(kind: .kenwood)
        let rig = makeBackend("ts590", radio)
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertNil(rig.state.sMeterDB)
        XCTAssertEqual(RigctlProtocol.dispatch(rig, "l STRENGTH"), "RPRT -11\n")
    }

    func testFT817Meters() {
        let radio = FakeFT817()
        radio.sNibble = 12                                             // S9+30
        radio.poNibble = 15
        let rig = makeBackend("ft817", radio, pttMethod: .cat)
        XCTAssertTrue(waitUntil { rig.state.sMeterDB == 30 })
        _ = rig.setPTT(true)
        XCTAssertTrue(waitUntil { rig.state.powerPercent == 100 })
        _ = rig.setPTT(false)
        XCTAssertTrue(waitUntil { rig.state.freq == 7_074_000 }, "odczyt nie może się rozjechać")
    }
}
