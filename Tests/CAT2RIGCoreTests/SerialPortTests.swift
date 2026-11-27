import XCTest
import Darwin
@testable import CAT2RIGCore

final class PortResolverTests: XCTestCase {
    private let radio = SerialPortInfo(path: "/dev/cu.usbserial-8", product: "Dual RS232",
                                       vendorID: 0x0403, productID: 0x6010, serialNumber: "AB12", interface: 0)
    private var radioID: String { radio.identity! }

    func testSamePathSameDevice() {
        XCTAssertEqual(PortResolver.resolve(path: radio.path, identity: radioID, available: [radio]), radio.path)
    }

    func testRenamedAfterReboot() {
        let renamed = SerialPortInfo(path: "/dev/cu.usbserial-21", product: "Dual RS232", vendorID: 0x0403,
                                     productID: 0x6010, serialNumber: "AB12", interface: 0)
        let other = SerialPortInfo(path: "/dev/cu.usbserial-8", product: "Other", vendorID: 0x10C4,
                                   productID: 0xEA60, serialNumber: "ZZ", interface: 0)
        XCTAssertEqual(PortResolver.resolve(path: radio.path, identity: radioID, available: [other, renamed]),
                       "/dev/cu.usbserial-21", "ten sam interfejs pod nową nazwą")
    }

    func testOtherDeviceUnderOldNameIsNotOpened() {
        let other = SerialPortInfo(path: radio.path, vendorID: 0x10C4, productID: 0xEA60, serialNumber: "ZZ")
        XCTAssertNil(PortResolver.resolve(path: radio.path, identity: radioID, available: [other]),
                     "nie otwieramy innego urządzenia tylko dlatego, że ma starą nazwę")
    }

    func testSecondPortOfSameDeviceIsDistinguished() {
        let pttPort = SerialPortInfo(path: "/dev/cu.usbserial-7", vendorID: 0x0403, productID: 0x6010,
                                     serialNumber: "AB12", interface: 1)
        XCTAssertNotEqual(pttPort.identity, radioID)
        XCTAssertEqual(PortResolver.resolve(path: "/dev/cu.x", identity: pttPort.identity,
                                            available: [radio, pttPort]), pttPort.path)
    }

    func testWithoutIdentityUsesPath() {
        let bt = SerialPortInfo(path: "/dev/cu.Bluetooth")
        XCTAssertNil(bt.identity)
        XCTAssertEqual(PortResolver.resolve(path: bt.path, identity: nil, available: [bt]), bt.path)
        XCTAssertNil(PortResolver.resolve(path: "/dev/cu.gone", identity: nil, available: [bt]))
    }

    func testLabel() {
        XCTAssertEqual(radio.label, "/dev/cu.usbserial-8  –  Dual RS232 (AB12)")
        XCTAssertEqual(SerialPortInfo(path: "/dev/cu.x").label, "/dev/cu.x")
    }
}

/// Port szeregowy na pseudoterminalu: urządzenie, które nie odbiera danych, nie może
/// zablokować programu (wcześniej Stop zawieszał aplikację, gdy radio nie odpowiadało).
final class SerialPortTimeoutTests: XCTestCase {

    private func makePty() throws -> (master: Int32, path: String) {
        let master = posix_openpt(O_RDWR | O_NOCTTY)
        guard master >= 0, grantpt(master) == 0, unlockpt(master) == 0, let name = ptsname(master) else {
            throw XCTSkip("brak pseudoterminala")
        }
        return (master, String(cString: name))
    }

    func testWriteGivesUpWhenDeviceDoesNotRead() throws {
        let pty = try makePty()
        defer { Darwin.close(pty.master) }
        let port = SerialPort(path: pty.path)
        try port.open(baud: 9600)

        let chunk = [UInt8](repeating: 0x55, count: 4096)
        let t0 = Date()
        var ok = true
        var count = 0
        while ok && count < 500 {              // nikt nie czyta drugiej strony – bufor się zapełni
            ok = port.write(chunk)
            count += 1
        }
        XCTAssertFalse(ok, "zapis powinien się poddać, a nie blokować")
        XCTAssertLessThan(Date().timeIntervalSince(t0), 5)

        let t1 = Date()
        port.close()
        XCTAssertLessThan(Date().timeIntervalSince(t1), 1, "close() nie może czekać na wysłanie danych")
    }

    func testReadReturnsQuicklyWithoutData() throws {
        let pty = try makePty()
        defer { Darwin.close(pty.master) }
        let port = SerialPort(path: pty.path)
        try port.open(baud: 9600)
        defer { port.close() }

        var buf = [UInt8](repeating: 0, count: 64)
        let t0 = Date()
        XCTAssertEqual(port.read(into: &buf), 0)
        XCTAssertLessThan(Date().timeIntervalSince(t0), 0.5)

        _ = [UInt8](arrayLiteral: 0xFE, 0xFE).withUnsafeBytes { Darwin.write(pty.master, $0.baseAddress, 2) }
        XCTAssertTrue(waitUntil(timeout: 1) { port.read(into: &buf) == 2 })
    }

    func testIcomRigClosesQuicklyWhenRadioIsSilent() throws {
        let pty = try makePty()
        defer { Darwin.close(pty.master) }
        let port = SerialPort(path: pty.path)
        try port.open(baud: 9600)
        let rig = IcomRig(transport: port, rigAddr: 0x58, pollInterval: 0.05, responseTimeout: 0.2)
        Thread.sleep(forTimeInterval: 0.5)     // kilka nieudanych odpytań
        let t0 = Date()
        rig.close()
        XCTAssertLessThan(Date().timeIntervalSince(t0), 2, "Stop nie może zawiesić programu")
    }
}
