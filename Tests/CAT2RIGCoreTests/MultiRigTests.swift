import XCTest
@testable import CAT2RIGCore

private func model(_ id: String) -> RadioModel {
    RadioModel.find(id)!
}

extension XCTestCase {
    func makeBackend(_ id: String, _ transport: SerialTransport, pttMethod: PTTMethod = .off,
                     file: StaticString = #filePath, line: UInt = #line) -> RigBackend {
        let rig = RigFactory.make(model: model(id), transport: transport, pttMethod: pttMethod,
                                  pollInterval: 0.05, responseTimeout: 0.3)
        XCTAssertTrue(waitUntil { rig.state.online }, "radio \(id) nie odpowiedziało", file: file, line: line)
        addTeardownBlock { rig.close() }
        return rig
    }
}

// MARK: - Kenwood / Elecraft

final class KenwoodTests: XCTestCase {

    func testPollsFrequencyAndMode() {
        let radio = FakeTextRadio(kind: .kenwood, freq: 7_074_000, mode: "2")
        let rig = makeBackend("ts590", radio)
        XCTAssertTrue(waitUntil { rig.state.freq == 7_074_000 && rig.state.mode == "USB" })
        XCTAssertTrue(radio.aiDisabled, "Auto Information powinno zostać wyłączone (AI0;)")
    }

    func testSetFreqUsesElevenDigits() {
        let radio = FakeTextRadio(kind: .kenwood)
        let rig = makeBackend("k3", radio)
        XCTAssertEqual(rig.setFreq(14_074_000), .ok)
        XCTAssertEqual(radio.freq, 14_074_000)
        XCTAssertTrue(radio.commands.contains("FA00014074000"))
    }

    func testRejectedFrequency() {
        let radio = FakeTextRadio(kind: .kenwood)
        radio.maxFreq = 60_000_000
        let rig = makeBackend("ts480", radio)
        XCTAssertEqual(rig.setFreq(145_500_000), .erjcted)
    }

    func testSetMode() {
        let radio = FakeTextRadio(kind: .kenwood, mode: "2")
        let rig = makeBackend("ts2000", radio)
        XCTAssertEqual(rig.setMode("CW"), .ok)
        XCTAssertEqual(radio.modeCode, "3")
        XCTAssertEqual(rig.setMode("PKTUSB"), .ok)                  // brak trybu DATA -> USB
        XCTAssertEqual(radio.modeCode, "2")
        XCTAssertEqual(rig.setMode("XYZ"), .einval)
    }

    func testCatPTT() {
        let radio = FakeTextRadio(kind: .kenwood)
        let rig = makeBackend("ts590", radio, pttMethod: .cat)
        XCTAssertEqual(rig.setPTT(true), .ok)
        XCTAssertTrue(radio.catPTT)
        XCTAssertTrue(rig.state.ptt)
        XCTAssertEqual(rig.setPTT(false), .ok)
        XCTAssertFalse(radio.catPTT)
    }

    func testUnsolicitedMessagesAreSkipped() {
        let radio = FakeTextRadio(kind: .kenwood, freq: 3_573_000)
        let rig = makeBackend("ts590", radio)
        radio.inject(Array("IF00003573000     +00000000002000000;".utf8))   // inny komunikat
        radio.sendAutoInfo(freq: 3_574_000)
        XCTAssertTrue(waitUntil { rig.state.freq == 3_574_000 })
        XCTAssertEqual(rig.setFreq(7_074_000), .ok)
    }
}

// MARK: - Yaesu (nowsze, tekstowy CAT)

final class YaesuTextTests: XCTestCase {

    func testPollsFrequencyAndDataMode() {
        let radio = FakeTextRadio(kind: .yaesu, freq: 50_313_000, mode: "C")   // DATA-USB
        let rig = makeBackend("ft991", radio)
        XCTAssertTrue(waitUntil { rig.state.freq == 50_313_000 && rig.state.mode == "PKTUSB" })
    }

    func testSetFreqUsesNineDigits() {
        let radio = FakeTextRadio(kind: .yaesu)
        let rig = makeBackend("ft891", radio)
        XCTAssertEqual(rig.setFreq(7_074_000), .ok)
        XCTAssertTrue(radio.commands.contains("FA007074000"))
        XCTAssertEqual(radio.freq, 7_074_000)
    }

    func testSetModes() {
        let radio = FakeTextRadio(kind: .yaesu, mode: "2")
        let rig = makeBackend("ft710", radio)
        XCTAssertEqual(rig.setMode("PKTUSB"), .ok)
        XCTAssertEqual(radio.modeCode, "C")
        XCTAssertEqual(rig.state.mode, "PKTUSB")
        XCTAssertEqual(rig.setMode("FM"), .ok)
        XCTAssertEqual(radio.modeCode, "4")
    }

    func testCatPTT() {
        let radio = FakeTextRadio(kind: .yaesu)
        let rig = makeBackend("ftdx10", radio, pttMethod: .cat)
        _ = rig.setPTT(true)
        XCTAssertTrue(radio.commands.contains("TX1"))
        XCTAssertTrue(radio.catPTT)
        _ = rig.setPTT(false)
        XCTAssertTrue(radio.commands.contains("TX0"))
        XCTAssertFalse(radio.catPTT)
    }

    func testScanDetectedFromPolling() {
        let radio = FakeTextRadio(kind: .yaesu, freq: 145_000_000, mode: "4")
        let rig = makeBackend("ft991", radio)
        for i in 1...8 {
            radio.sendAutoInfo(freq: 145_000_000 + i * 12_500)
            Thread.sleep(forTimeInterval: 0.08)
        }
        XCTAssertTrue(waitUntil { rig.state.scanning })
    }
}

// MARK: - Yaesu FT-817/857/897 (binarny)

final class YaesuBinaryTests: XCTestCase {

    func testBCD() {
        XCTAssertEqual(YaesuBinaryRig.freqToBCD(14_074_000), [0x01, 0x40, 0x74, 0x00])
        XCTAssertEqual(YaesuBinaryRig.freqToBCD(145_500_000), [0x14, 0x55, 0x00, 0x00])
        XCTAssertEqual(YaesuBinaryRig.bcdToFreq([0x43, 0x21, 0x00, 0x00]), 432_100_000)
        XCTAssertNil(YaesuBinaryRig.bcdToFreq([0xFF, 0x00, 0x00, 0x00]))
    }

    func testPollsStatus() {
        let radio = FakeFT817(freq: 10_136_000, mode: 0x0A)          // DIG
        let rig = makeBackend("ft817", radio)
        XCTAssertTrue(waitUntil { rig.state.freq == 10_136_000 && rig.state.mode == "PKTUSB" })
    }

    func testSetFreqAndMode() {
        for ack in [false, true] {
            let radio = FakeFT817()
            radio.sendsAck = ack
            let rig = makeBackend("ft857", radio)
            XCTAssertEqual(rig.setFreq(21_074_000), .ok, "ack=\(ack)")
            XCTAssertEqual(radio.freq, 21_074_000)
            XCTAssertEqual(rig.setMode("CW"), .ok)
            XCTAssertEqual(radio.mode, 0x02)
            // po potwierdzeniu odczyt dalej się zgadza (bajt ACK nie przesunął ramki)
            XCTAssertTrue(waitUntil { rig.state.freq == 21_074_000 && rig.state.mode == "CW" })
        }
    }

    func testCatPTT() {
        let radio = FakeFT817()
        let rig = makeBackend("ft897", radio, pttMethod: .cat)
        XCTAssertEqual(rig.setPTT(true), .ok)
        XCTAssertTrue(radio.catPTT)
        XCTAssertEqual(rig.setPTT(false), .ok)
        XCTAssertFalse(radio.catPTT)
        XCTAssertTrue(waitUntil { rig.state.freq == 7_074_000 }, "odczyt po PTT nie może się rozjechać")
    }
}

// MARK: - Icom: PTT przez CI-V i tryb DATA

final class IcomExtrasTests: XCTestCase {

    func testCivPTT() {
        let radio = FakeRadio(addr: 0x94)
        let rig = makeBackend("ic7300", radio, pttMethod: .cat)
        XCTAssertEqual(rig.setPTT(true), .ok)
        XCTAssertTrue(radio.civPTT)
        XCTAssertEqual(rig.setPTT(false), .ok)
        XCTAssertFalse(radio.civPTT)
    }

    func testDataMode() {
        let radio = FakeRadio(addr: 0xA4, mode: 0x01)
        let rig = makeBackend("ic705", radio)
        XCTAssertEqual(rig.setMode("PKTUSB"), .ok)
        XCTAssertEqual(radio.dataMode, 1)
        XCTAssertEqual(rig.state.mode, "PKTUSB")
        XCTAssertEqual(rig.setMode("USB"), .ok)
        XCTAssertEqual(radio.dataMode, 0)
        XCTAssertTrue(waitUntil { rig.state.mode == "USB" })
    }

    func testXieguUsesCIV() {
        let radio = FakeRadio(addr: 0x70, freq: 7_074_000)
        let rig = makeBackend("x6100", radio)
        XCTAssertTrue(waitUntil { rig.state.freq == 7_074_000 })
        XCTAssertEqual(rig.setFreq(14_074_000), .ok)
        XCTAssertEqual(radio.freq, 14_074_000)
    }
}

// MARK: - Katalog modeli

final class RadioModelTests: XCTestCase {

    func testCatalogue() {
        let ids = RadioModel.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "zdublowane id modeli")
        XCTAssertEqual(RadioModel.defaultModel.id, "ic706mk2g", "domyślny model = dotychczasowe radio")
        for m in RadioModel.all {
            if m.usesCIV { XCTAssertNotEqual(m.civAddress, 0, m.id) }
            XCTAssertTrue([1, 2].contains(m.stopBits), m.id)
            XCTAssertGreaterThan(m.defaultBaud, 0, m.id)
        }
        XCTAssertFalse(model("ic706mk2g").catPTT, "IC-706MKIIG nie ma PTT po CI-V")
        XCTAssertEqual(RadioModel.manufacturers, ["Icom", "Xiegu", "Yaesu", "Kenwood", "Elecraft"])
    }

    func testFactoryPicksDriver() {
        func make(_ id: String) -> RigBackend {
            let r = RigFactory.make(model: model(id), transport: FakeSerialBase())
            addTeardownBlock { r.close() }
            return r
        }
        XCTAssertTrue(make("ic7300") is IcomRig)
        XCTAssertTrue(make("g90") is IcomRig)
        XCTAssertTrue(make("ft991") is TextCatRig)
        XCTAssertTrue(make("ts590") is TextCatRig)
        XCTAssertTrue(make("ft817") is YaesuBinaryRig)
    }
}
