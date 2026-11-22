import XCTest
@testable import CAT2RIGCore

/// Testy sterownika Hamlib. Wymagają zbudowanej biblioteki (bash scripts/build_hamlib.sh)
/// albo Hamlib z Homebrew; bez niej są pomijane. W GitHub Actions biblioteka jest budowana.
final class HamlibTests: XCTestCase {

    private func library() throws -> HamlibLibrary {
        guard let lib = HamlibLibrary.shared else {
            throw XCTSkip("Brak biblioteki Hamlib – uruchom: bash scripts/build_hamlib.sh")
        }
        return lib
    }

    func testLibraryLoads() throws {
        let lib = try library()
        XCTAssertTrue(lib.version.hasPrefix("Hamlib 4"), lib.version)
    }

    func testModelList() throws {
        let lib = try library()
        XCTAssertGreaterThan(lib.models.count, 200)
        XCTAssertEqual(lib.model(1)?.name, "Dummy")
        XCTAssertEqual(lib.model(1)?.manufacturer, "Hamlib")
        XCTAssertEqual(lib.model(3011)?.name, "IC-706MkIIG")
        XCTAssertEqual(lib.model(3011)?.manufacturer, "Icom")
        XCTAssertEqual(lib.model(1049)?.name, "FT-710")
        XCTAssertNil(lib.model(2), "NET rigctl jest ukryty (połączenie samego ze sobą)")
        XCTAssertTrue(lib.manufacturers.contains("Yaesu"))
    }

    /// Numery Hamlib w naszym katalogu muszą istnieć w bibliotece i wskazywać tego samego producenta.
    func testCatalogueNumbersExistInHamlib() throws {
        let lib = try library()
        for m in RadioModel.all where m.hamlibID != 0 {
            guard let info = lib.model(m.hamlibID) else {
                XCTFail("\(m.displayName): brak modelu #\(m.hamlibID) w \(lib.version)")
                continue
            }
            // "QRP Labs" ↔ "QRPLabs" – porównujemy bez spacji
            let maker = info.manufacturer.lowercased().replacingOccurrences(of: " ", with: "")
            let ours = m.manufacturer.lowercased().replacingOccurrences(of: " ", with: "")
            XCTAssertTrue(maker.contains(ours) || ours.contains(maker),
                          "\(m.displayName) -> \(info.displayName)")
        }
    }

    func testDummyRadio() throws {
        _ = try library()
        let rig = try RigFactory.openHamlib(model: 1, portPath: "", baud: 9600, stopBits: 1,
                                            rtsCts: false, civAddress: nil, pttMethod: .cat,
                                            pttPortPath: nil, pollInterval: 0.05, log: { _ in })
        addTeardownBlock { rig.close() }
        XCTAssertTrue(waitUntil { rig.state.online })

        XCTAssertEqual(rig.setFreq(14_074_000), .ok)
        XCTAssertTrue(waitUntil { rig.state.freq == 14_074_000 })

        XCTAssertEqual(rig.setMode("PKTUSB"), .ok)
        XCTAssertTrue(waitUntil { rig.state.mode == "PKTUSB" })
        XCTAssertEqual(rig.setMode("XYZ"), .einval)

        XCTAssertTrue(waitUntil { rig.state.sMeterDB != nil }, "Dummy podaje STRENGTH")

        XCTAssertEqual(rig.setPTT(true), .ok)
        XCTAssertTrue(rig.state.ptt)
        // Dummy losuje moc (0…~100 %) – sprawdzamy tylko, że odczyt jest i mieści się w skali
        XCTAssertTrue(waitUntil { rig.state.powerPercent != nil }, "Dummy podaje RFPOWER_METER")
        if let p = rig.state.powerPercent { XCTAssertTrue((0...100).contains(p), "\(p)") }
        XCTAssertEqual(rig.setPTT(false), .ok)
        XCTAssertFalse(rig.state.ptt)
    }

    func testRigctlCommandsThroughHamlib() throws {
        _ = try library()
        let rig = try RigFactory.openHamlib(model: 1, portPath: "", baud: 9600, stopBits: 1,
                                            rtsCts: false, civAddress: nil, pttMethod: .cat,
                                            pttPortPath: nil, pollInterval: 0.05, log: { _ in })
        addTeardownBlock { rig.close() }
        XCTAssertTrue(waitUntil { rig.state.online })
        XCTAssertEqual(RigctlProtocol.dispatch(rig, "F VFOA 7074000"), "RPRT 0\n")
        XCTAssertTrue(waitUntil { RigctlProtocol.dispatch(rig, "f") == "7074000\n" })
        XCTAssertEqual(RigctlProtocol.dispatch(rig, "M USB -1"), "RPRT 0\n")
        XCTAssertEqual(RigctlProtocol.dispatch(rig, "T 1"), "RPRT 0\n")
        XCTAssertEqual(RigctlProtocol.dispatch(rig, "t"), "1\n")
        XCTAssertEqual(RigctlProtocol.dispatch(rig, "T 0"), "RPRT 0\n")
    }

    func testMissingPortReportsError() throws {
        _ = try library()
        XCTAssertThrowsError(
            try RigFactory.openHamlib(model: 3011, portPath: "/dev/cu.does-not-exist", baud: 19200,
                                      stopBits: 1, rtsCts: false, civAddress: 0x58, pttMethod: .rts,
                                      pttPortPath: nil, log: { _ in })
        ) { error in
            XCTAssertTrue("\(error.localizedDescription)".contains("Hamlib"), "\(error)")
        }
    }

    func testUnknownModelThrows() throws {
        _ = try library()
        XCTAssertThrowsError(
            try RigFactory.openHamlib(model: 999_999, portPath: "", baud: 9600, stopBits: 1,
                                      rtsCts: false, civAddress: nil, pttMethod: .off,
                                      pttPortPath: nil, log: { _ in }))
    }
}
