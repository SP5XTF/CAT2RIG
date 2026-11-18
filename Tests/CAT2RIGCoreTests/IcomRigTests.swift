import XCTest
@testable import CAT2RIGCore

final class IcomRigTests: XCTestCase {

    // MARK: odczyt

    func testPollsFrequencyAndMode() {
        let radio = FakeRadio(freq: 144_174_000, mode: 0x05)       // FM
        let rig = makeRig(radio)
        XCTAssertTrue(waitUntil { rig.state.freq == 144_174_000 && rig.state.mode == "FM" })
        XCTAssertEqual(rig.state.width, 15_000)
    }

    func testNarrowFilterReportsNarrowWidth() {
        let radio = FakeRadio(mode: 0x03, filter: 3)                 // CW, filtr narrow
        let rig = makeRig(radio)
        XCTAssertTrue(waitUntil { rig.state.mode == "CW" })
        XCTAssertEqual(rig.state.width, 500)
    }

    func testOfflineBeforeFirstAnswer() {
        let radio = FakeRadio()
        radio.silent = true
        let rig = makeRig(radio, waitOnline: false)
        XCTAssertFalse(rig.state.online)
    }

    func testTransceiveFrameUpdatesStateWithoutPolling() {
        let radio = FakeRadio(freq: 14_074_000)
        // odpytywanie raz na minutę – zmiana może przyjść tylko z ramki transceive
        let rig = makeRig(radio, pollInterval: 60)
        XCTAssertEqual(rig.state.freq, 14_074_000)
        radio.turnDial(to: 7_074_000)
        XCTAssertTrue(waitUntil { rig.state.freq == 7_074_000 })
    }

    func testFragmentedFramesAreReassembled() {
        let radio = FakeRadio(freq: 145_500_000)
        radio.maxReadChunk = 1                                       // ramki przychodzą bajt po bajcie
        let rig = makeRig(radio)
        XCTAssertTrue(waitUntil { rig.state.freq == 145_500_000 })
    }

    func testGarbageBeforeFrameIsSkipped() {
        let radio = FakeRadio(freq: 14_074_000)
        let rig = makeRig(radio, pollInterval: 60)
        radio.inject([0x12, 0xFD, 0x00, 0xFE, 0x33]
                     + [0xFE, 0xFE, 0x00, 0x58, 0x00] + CIV.freqToBCD(10_136_000) + [0xFD])
        XCTAssertTrue(waitUntil { rig.state.freq == 10_136_000 })
    }

    func testTruncatedFrameDuringScanDoesNotBreakParser() {
        let radio = FakeRadio(freq: 145_000_000)
        let rig = makeRig(radio, pollInterval: 60)
        // ramka urwana przez kolizję (brak FD), zaraz po niej poprawna
        radio.inject([0xFE, 0xFE, 0x00, 0x58, 0x00, 0x00, 0x50, 0x07])
        radio.inject([0xFE, 0xFE, 0x00, 0x58, 0x00] + CIV.freqToBCD(145_025_000) + [0xFD])
        XCTAssertTrue(waitUntil { rig.state.freq == 145_025_000 })
    }

    func testCorruptedFramesAreIgnored() {
        let radio = FakeRadio(freq: 145_000_000)
        let rig = makeRig(radio, pollInterval: 60)
        radio.inject([0xFE, 0xFE, 0x00, 0x58, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFD])      // nie-BCD
        radio.inject([0xFE, 0xFE, 0x00, 0x58, 0x00] + [UInt8](repeating: 0x99, count: 10) + [0xFD])
        radio.inject([0xFE, 0xFE, 0x00, 0x58, 0x01, 0x01, 0x02, 0x03, 0x04, 0xFD])         // zła emisja
        radio.inject([0xFE, 0xFE, 0x00, 0x58, 0x00] + CIV.freqToBCD(145_050_000) + [0xFD])
        XCTAssertTrue(waitUntil { rig.state.freq == 145_050_000 })
        XCTAssertEqual(rig.state.mode, "USB")
    }

    func testScanFloodWithCollisions() {
        // radio skanuje: setki ramek transceive, część uszkodzona – program nie może się wywrócić
        let radio = FakeRadio(freq: 144_000_000)
        let rig = makeRig(radio, pollInterval: 0.05)
        var f = 144_000_000
        for i in 0..<300 {
            f += 12_500
            var frame: [UInt8] = [0xFE, 0xFE, 0x00, 0x58, 0x00] + CIV.freqToBCD(f) + [0xFD]
            if i % 7 == 0 { frame.removeLast() }                 // brak FD
            if i % 11 == 0 { frame[6] = 0xFC }                   // kolizja
            if i % 13 == 0 { frame.insert(0xFE, at: 3) }         // śmieci
            radio.inject(frame)
        }
        radio.turnDial(to: 145_500_000)
        XCTAssertTrue(waitUntil(timeout: 5) { rig.state.freq == 145_500_000 })
        XCTAssertTrue(rig.state.online)
    }

    func testFramesFromOtherAddressesAreIgnored() {
        let radio = FakeRadio(freq: 14_074_000)
        let rig = makeRig(radio, pollInterval: 60)
        // inne radio (adres 0x5C) na tej samej magistrali
        radio.inject([0xFE, 0xFE, 0x00, 0x5C, 0x00] + CIV.freqToBCD(3_573_000) + [0xFD])
        // ramka z kolizją (FC)
        radio.inject([0xFE, 0xFE, 0x00, 0x58, 0x00, 0xFC, 0xFD])
        // potem poprawna – dowód, że parser nie zgubił synchronizacji
        radio.inject([0xFE, 0xFE, 0x00, 0x58, 0x00] + CIV.freqToBCD(18_100_000) + [0xFD])
        XCTAssertTrue(waitUntil { rig.state.freq == 18_100_000 })
    }

    // MARK: SCAN (szybkie zmiany częstotliwości)

    func testRapidFrequencyChangesAreDetectedAsScan() {
        let radio = FakeRadio(freq: 145_000_000)
        let rig = makeRig(radio, pollInterval: 60)
        XCTAssertFalse(rig.state.scanning)
        for i in 1...6 {                                             // radio skanuje co 25 kHz
            radio.turnDial(to: 145_000_000 + i * 25_000)
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertTrue(waitUntil { rig.state.scanning }, "SCAN nie wykryty")
        XCTAssertTrue(waitUntil(timeout: IcomRig.scanWindow + 2) { !rig.state.scanning },
                      "wskaźnik SCAN nie zgasł po ustaniu zmian")
    }

    func testOccasionalChangesAreNotScan() {
        let radio = FakeRadio(freq: 14_074_000)
        let rig = makeRig(radio, pollInterval: 60)
        radio.turnDial(to: 14_075_000)
        radio.turnDial(to: 14_076_000)
        XCTAssertTrue(waitUntil { rig.state.freq == 14_076_000 })
        XCTAssertFalse(rig.state.scanning)
    }

    func testClientFrequencyChangesAreNotScan() {
        let radio = FakeRadio()
        let rig = makeRig(radio)                                     // szybkie odpytywanie
        for f in [7_074_000, 14_074_000, 21_074_000, 28_074_000, 50_313_000, 144_174_000] {
            XCTAssertEqual(rig.setFreq(f), .ok)
        }
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertFalse(rig.state.scanning, "zmiany zlecone przez WSJT-X to nie SCAN")
    }

    // MARK: sterowanie

    func testSetFreqSendsCorrectFrame() {
        let radio = FakeRadio()
        let rig = makeRig(radio)
        XCTAssertEqual(rig.setFreq(3_573_000), .ok)
        XCTAssertEqual(radio.freq, 3_573_000)
        XCTAssertEqual(rig.state.freq, 3_573_000)
        let expected: [UInt8] = [0xFE, 0xFE, 0x58, 0xE0, 0x05, 0x00, 0x30, 0x57, 0x03, 0x00, 0xFD]
        XCTAssertTrue(radio.writtenFrames.contains(expected), "brak ramki \(expected)")
    }

    func testSetFreqLeavesMemoryMode() {
        let radio = FakeRadio(freq: 145_500_000)
        radio.memoryMode = true                                      // V/M ustawione na pamięć
        let rig = makeRig(radio)
        XCTAssertEqual(rig.setFreq(7_074_000), .ok)
        XCTAssertFalse(radio.memoryMode, "radio powinno zostać przełączone na VFO")
        XCTAssertEqual(radio.freq, 7_074_000)
        // kolejność: najpierw 0x07 (VFO), potem 0x05 (częstotliwość)
        let cmds = radio.writtenFrames.compactMap { $0.count > 4 ? $0[4] : nil }
            .filter { $0 == 0x07 || $0 == 0x05 }
        XCTAssertEqual(Array(cmds.prefix(2)), [0x07, 0x05])
    }

    func testClientCommandsAreFastDespitePolling() {
        let radio = FakeRadio()
        let rig = makeRig(radio, pollInterval: 0.01)                // bardzo intensywne odpytywanie
        for i in 0..<20 {
            let t0 = Date()
            XCTAssertEqual(rig.setFreq(14_000_000 + i * 1_000), .ok)
            XCTAssertLessThan(Date().timeIntervalSince(t0), 0.3, "komenda klienta czekała za długo")
        }
        XCTAssertTrue(rig.state.online)
    }

    func testSetFreqRejectsInvalidValues() {
        let radio = FakeRadio()
        let rig = makeRig(radio)
        XCTAssertEqual(rig.setFreq(0), .einval)
        XCTAssertEqual(rig.setFreq(-5), .einval)
        XCTAssertFalse(radio.writtenFrames.contains { $0.count > 4 && $0[4] == 0x05 })
    }

    func testSetModeMapsHamlibNames() {
        let radio = FakeRadio(mode: 0x05)
        let rig = makeRig(radio)
        XCTAssertEqual(rig.setMode("PKTUSB"), .ok)
        XCTAssertEqual(radio.mode, 0x01)
        XCTAssertEqual(rig.state.mode, "USB")
        XCTAssertEqual(rig.setMode("lsb"), .ok)                      // wielkość liter bez znaczenia
        XCTAssertEqual(radio.mode, 0x00)
        XCTAssertEqual(rig.setMode("FM"), .ok)
        XCTAssertEqual(radio.mode, 0x05)
    }

    func testSetModeRejectsUnknownMode() {
        let radio = FakeRadio()
        let rig = makeRig(radio)
        XCTAssertEqual(rig.setMode("FOO"), .einval)
        XCTAssertFalse(radio.writtenFrames.contains { $0.count > 4 && $0[4] == 0x06 })
    }

    func testNakIsReportedAsRejected() {
        let radio = FakeRadio()
        let rig = makeRig(radio)
        radio.nakAll = true
        XCTAssertEqual(rig.setFreq(7_074_000), .erjcted)
        XCTAssertEqual(rig.setMode("CW"), .erjcted)
    }

    func testSilentRadioTimesOut() {
        let radio = FakeRadio()
        radio.silent = true
        let rig = makeRig(radio, waitOnline: false)
        let t0 = Date()
        XCTAssertEqual(rig.setFreq(7_074_000), .etimeout)
        XCTAssertLessThan(Date().timeIntervalSince(t0), 3.0)        // 3 próby po 0,2 s + zapas
    }

    func testWorksWithoutEcho() {
        // interfejsy, które nie odsyłają echa (np. kabel USB z odseparowanym TX/RX)
        let radio = FakeRadio(freq: 21_074_000)
        radio.echo = false
        let rig = makeRig(radio)
        XCTAssertTrue(waitUntil { rig.state.freq == 21_074_000 })
        XCTAssertEqual(rig.setFreq(24_915_000), .ok)
    }

    // MARK: PTT

    func testPTTOnRTSSamePort() {
        let radio = FakeRadio()
        let rig = makeRig(radio, pttMethod: .rts)
        XCTAssertEqual(rig.setPTT(true), .ok)
        XCTAssertTrue(radio.rts)
        XCTAssertFalse(radio.dtr)
        XCTAssertTrue(rig.state.ptt)
        XCTAssertEqual(rig.setPTT(false), .ok)
        XCTAssertFalse(radio.rts)
        XCTAssertFalse(rig.state.ptt)
    }

    func testPTTOnSeparatePortUsesThatPortOnly() {
        let radio = FakeRadio()
        let pttPort = FakeRadio()                                    // drugi port interfejsu
        let rig = makeRig(radio, pttTransport: pttPort, pttMethod: .rts)
        XCTAssertEqual(rig.setPTT(true), .ok)
        XCTAssertTrue(pttPort.rts)
        XCTAssertFalse(radio.rts, "port CI-V nie może być kluczowany")
        _ = rig.setPTT(false)
        XCTAssertFalse(pttPort.rts)
    }

    func testPTTOnDTR() {
        let radio = FakeRadio()
        let pttPort = FakeRadio()
        let rig = makeRig(radio, pttTransport: pttPort, pttMethod: .dtr)
        _ = rig.setPTT(true)
        XCTAssertTrue(pttPort.dtr)
        XCTAssertFalse(pttPort.rts)
    }

    func testPTTOffMethodDoesNotTouchLines() {
        let radio = FakeRadio()
        let rig = makeRig(radio, pttMethod: .off)
        XCTAssertEqual(rig.setPTT(true), .ok)
        XCTAssertTrue(rig.state.ptt)                                 // stan zgłaszany klientowi (VOX)
        XCTAssertFalse(radio.rts)
        XCTAssertFalse(radio.dtr)
    }

    func testCloseReleasesPTTAndClosesPorts() {
        let radio = FakeRadio()
        let pttPort = FakeRadio()
        let rig = makeRig(radio, pttTransport: pttPort, pttMethod: .rts)
        _ = rig.setPTT(true)
        rig.close()
        XCTAssertFalse(pttPort.rts, "po zamknięciu nadajnik nie może zostać na nadawaniu")
        XCTAssertTrue(radio.closed)
        XCTAssertTrue(pttPort.closed)
    }
}
