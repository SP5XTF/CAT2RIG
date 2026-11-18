import XCTest
@testable import CAT2RIGCore

final class RigctlProtocolTests: XCTestCase {
    private var radio: FakeRadio!
    private var rig: IcomRig!

    override func setUp() {
        super.setUp()
        radio = FakeRadio(freq: 14_074_000, mode: 0x01)
        rig = makeRig(radio, pttMethod: .rts)
    }

    private func cmd(_ line: String) -> String? {
        RigctlProtocol.dispatch(rig, line)
    }

    // MARK: odczyt

    func testGetFreq() {
        XCTAssertEqual(cmd("f"), "14074000\n")
        XCTAssertEqual(cmd("\\get_freq"), "14074000\n")
        XCTAssertEqual(cmd("+f"), "14074000\n")                       // prefiks trybu rozszerzonego
    }

    func testGetMode() {
        XCTAssertEqual(cmd("m"), "USB\n2400\n")
        XCTAssertEqual(cmd("\\get_mode"), "USB\n2400\n")
    }

    func testOfflineRigReturnsTimeout() {
        let silent = FakeRadio()
        silent.silent = true
        let offline = makeRig(silent, waitOnline: false)
        XCTAssertEqual(RigctlProtocol.dispatch(offline, "f"), "RPRT -5\n")
        XCTAssertEqual(RigctlProtocol.dispatch(offline, "m"), "RPRT -5\n")
    }

    // MARK: ustawianie

    func testSetFreq() {
        XCTAssertEqual(cmd("F 7074000"), "RPRT 0\n")
        XCTAssertEqual(radio.freq, 7_074_000)
        XCTAssertEqual(cmd("f"), "7074000\n")
    }

    func testSetFreqVariants() {
        XCTAssertEqual(cmd("F 3573000.000000"), "RPRT 0\n")           // format "%f" z Hamlib
        XCTAssertEqual(radio.freq, 3_573_000)
        XCTAssertEqual(cmd("\\set_freq 10136000"), "RPRT 0\n")
        XCTAssertEqual(radio.freq, 10_136_000)
        XCTAssertEqual(cmd("F VFOA 18100000"), "RPRT 0\n")            // Hamlib z argumentem VFO
        XCTAssertEqual(radio.freq, 18_100_000)
        XCTAssertEqual(cmd("F currVFO 21074000"), "RPRT 0\n")
        XCTAssertEqual(radio.freq, 21_074_000)
    }

    func testSetFreqInvalid() {
        XCTAssertEqual(cmd("F"), "RPRT -1\n")
        XCTAssertEqual(cmd("F abc"), "RPRT -1\n")
        XCTAssertEqual(cmd("F 0"), "RPRT -1\n")
    }

    func testSetMode() {
        XCTAssertEqual(cmd("M CW 500"), "RPRT 0\n")
        XCTAssertEqual(radio.mode, 0x03)
        XCTAssertEqual(cmd("M PKTUSB 0"), "RPRT 0\n")
        XCTAssertEqual(radio.mode, 0x01)
        XCTAssertEqual(cmd("M VFOA FM -1"), "RPRT 0\n")
        XCTAssertEqual(radio.mode, 0x05)
        XCTAssertEqual(cmd("M XYZ 0"), "RPRT -1\n")
        XCTAssertEqual(cmd("M"), "RPRT -1\n")
    }

    func testSetFreqRejectedByRadio() {
        radio.nakAll = true
        XCTAssertEqual(cmd("F 7074000"), "RPRT -9\n")
    }

    // MARK: PTT

    func testPTT() {
        XCTAssertEqual(cmd("t"), "0\n")
        XCTAssertEqual(cmd("T 1"), "RPRT 0\n")
        XCTAssertTrue(radio.rts)
        XCTAssertEqual(cmd("t"), "1\n")
        XCTAssertEqual(cmd("\\set_ptt 0"), "RPRT 0\n")
        XCTAssertFalse(radio.rts)
        XCTAssertEqual(cmd("T VFOA 1"), "RPRT 0\n")
        XCTAssertTrue(radio.rts)
        XCTAssertEqual(cmd("T 0"), "RPRT 0\n")
        XCTAssertEqual(cmd("T"), "RPRT -1\n")
    }

    // MARK: VFO / split / inne

    func testVfoAndSplit() {
        XCTAssertEqual(cmd("v"), "VFOA\n")
        XCTAssertEqual(cmd("V VFOA"), "RPRT 0\n")
        XCTAssertEqual(cmd("\\set_vfo VFOB"), "RPRT 0\n")
        XCTAssertEqual(cmd("s"), "0\nVFOA\n")
        XCTAssertEqual(cmd("S 0 VFOA"), "RPRT 0\n")
        XCTAssertEqual(cmd("S 1 VFOB"), "RPRT -11\n")                 // split niedostępny
    }

    func testSessionCommands() {
        XCTAssertEqual(cmd("\\chk_vfo"), "0\n")
        XCTAssertEqual(cmd("\\get_powerstat"), "1\n")
        XCTAssertEqual(cmd("\\get_lock_mode"), "0\n")
        XCTAssertEqual(cmd("\\set_lock_mode 0"), "RPRT 0\n")
        XCTAssertNil(cmd("q"))
        XCTAssertNil(cmd("Q"))
        XCTAssertNil(cmd("\\quit"))
    }

    func testUnknownCommandIsNotAvailable() {
        XCTAssertEqual(cmd("l STRENGTH"), "RPRT -11\n")
        XCTAssertEqual(cmd("\\foo_bar 1 2 3"), "RPRT -11\n")
    }
}

/// Sprawdza \dump_state tak, jak parsuje go netrigctl_open() w Hamlib.
final class DumpStateTests: XCTestCase {

    private func isZeroLine(_ l: String, fields: Int) -> Bool {
        let f = l.split(separator: " ")
        return f.count == fields && f.allSatisfy { Double($0) == 0 }
    }

    func testStructureMatchesHamlibParser() throws {
        let text = RigctlProtocol.dumpState
        XCTAssertTrue(text.hasSuffix("done\n"))
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let last = lines.removeLast()
        XCTAssertEqual(last, "", "brak końcowego znaku nowej linii")
        var i = 0
        func next() -> String { defer { i += 1 }; return lines[i] }

        XCTAssertEqual(next(), "1", "wersja protokołu")
        XCTAssertEqual(next(), "2", "model NET rigctl")
        XCTAssertEqual(next(), "0", "region ITU")

        // zakresy RX i TX: po 7 pól, zakończone linią z siedmioma zerami
        for name in ["RX", "TX"] {
            var count = 0
            while true {
                let l = next()
                if isZeroLine(l, fields: 7) { break }
                let f = l.split(separator: " ")
                XCTAssertEqual(f.count, 7, "\(name): \(l)")
                let start = try XCTUnwrap(Double(f[0])), end = try XCTUnwrap(Double(f[1]))
                XCTAssertLessThan(start, end)
                count += 1
            }
            XCTAssertGreaterThan(count, 0, "brak zakresów \(name)")
        }

        // kroki strojenia i filtry: po 2 pola, zakończone "0 0"
        for name in ["kroki strojenia", "filtry"] {
            var count = 0
            while true {
                let l = next()
                if isZeroLine(l, fields: 2) { break }
                let f = l.split(separator: " ")
                XCTAssertEqual(f.count, 2, "\(name): \(l)")
                XCTAssertTrue(f[0].hasPrefix("0x"), "\(name): maska emisji w hex")
                XCTAssertNotNil(Int(f[1]))
                count += 1
            }
            XCTAssertGreaterThan(count, 0, "brak: \(name)")
        }

        // rit, xit, ifshift, announces, preamp, att, 6 masek funkcji/poziomów/parametrów
        for _ in 0..<12 {
            let l = next()
            XCTAssertFalse(l.contains("="), "za mało linii przed sekcją klucz=wartość: \(l)")
        }

        // sekcja klucz=wartość aż do "done"
        var keys: [String: String] = [:]
        while true {
            let l = next()
            if l == "done" { break }
            let kv = l.split(separator: "=", maxSplits: 1).map(String.init)
            XCTAssertEqual(kv.count, 2, "zła linia: \(l)")
            keys[kv[0]] = kv[1]
        }
        XCTAssertEqual(i, lines.count, "dane po \"done\"")

        XCTAssertEqual(keys["ptt_type"], "0x1", "klient musi wysyłać PTT do nas (RIG_PTT_RIG)")
        XCTAssertEqual(keys["has_set_vfo"], "1", "bez tego WSJT-X nie ustawia częstotliwości")
        XCTAssertEqual(keys["has_set_freq"], "1")
        XCTAssertEqual(keys["has_set_ptt"], "1")
    }

    func testCoversIC706Bands() {
        let tx = RigctlProtocol.dumpState
        XCTAssertTrue(tx.contains("1800000.000000 54000000.000000"), "KF + 6 m")
        XCTAssertTrue(tx.contains("144000000.000000 148000000.000000"), "2 m")
        XCTAssertTrue(tx.contains("430000000.000000 440000000.000000"), "70 cm")
    }
}
