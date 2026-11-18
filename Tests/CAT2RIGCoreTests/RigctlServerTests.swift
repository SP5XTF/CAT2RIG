import XCTest
@testable import CAT2RIGCore

/// Testy przez prawdziwe połączenie TCP – tak jak łączy się Hamlib "NET rigctl".
final class RigctlServerTests: XCTestCase {
    private var radio: FakeRadio!
    private var rig: IcomRig!
    private var server: RigctlServer!
    private var port: UInt16 = 0

    override func setUpWithError() throws {
        try super.setUpWithError()
        radio = FakeRadio(freq: 144_174_000, mode: 0x01)
        rig = makeRig(radio, pttMethod: .rts)

        server = try RigctlServer(rig: rig, port: 0, lan: false)    // 0 = dowolny wolny port
        let ready = expectation(description: "serwer nasłuchuje")
        server.onReady = { [weak self] p in
            self?.port = p
            ready.fulfill()
        }
        server.onFailed = { msg in XCTFail("serwer nie wystartował: \(msg)") }
        server.start()
        wait(for: [ready], timeout: 5)
        XCTAssertNotEqual(port, 0)
    }

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    /// Sekwencja otwarcia, którą wykonuje netrigctl_open() w Hamlib.
    func testHamlibOpenSequence() throws {
        let c = try TestTCPClient(port: port)
        c.send("\\chk_vfo\n")
        XCTAssertEqual(c.readLines(1), ["0"])

        c.send("\\dump_state\n")
        let state = c.readLines(until: "done")
        XCTAssertEqual(state.first, "1")
        XCTAssertEqual(state.last, "done")
        XCTAssertEqual(state.joined(separator: "\n") + "\n", RigctlProtocol.dumpState)

        c.send("f\n")
        XCTAssertEqual(c.readLines(1), ["144174000"])
        c.send("m\n")
        XCTAssertEqual(c.readLines(2), ["USB", "2400"])
    }

    func testSetFreqModeAndPTTOverTCP() throws {
        let c = try TestTCPClient(port: port)
        c.send("F 145500000\n")
        XCTAssertEqual(c.readLines(1), ["RPRT 0"])
        XCTAssertEqual(radio.freq, 145_500_000)

        c.send("M FM 15000\n")
        XCTAssertEqual(c.readLines(1), ["RPRT 0"])
        XCTAssertEqual(radio.mode, 0x05)

        c.send("T 1\n")
        XCTAssertEqual(c.readLines(1), ["RPRT 0"])
        XCTAssertTrue(radio.rts)
        c.send("T 0\n")
        XCTAssertEqual(c.readLines(1), ["RPRT 0"])
        XCTAssertFalse(radio.rts)
    }

    func testSeveralCommandsInOnePacket() throws {
        let c = try TestTCPClient(port: port)
        c.send("f\nv\nt\n")
        XCTAssertEqual(c.readLines(3), ["144174000", "VFOA", "0"])
    }

    func testCommandSplitAcrossPackets() throws {
        let c = try TestTCPClient(port: port)
        c.send("F 70")
        Thread.sleep(forTimeInterval: 0.1)
        c.send("74000\r\n")                                         // także CRLF
        XCTAssertEqual(c.readLines(1), ["RPRT 0"])
        XCTAssertEqual(radio.freq, 7_074_000)
    }

    func testQuitClosesConnection() throws {
        let c = try TestTCPClient(port: port)
        c.send("q\n")
        XCTAssertTrue(c.isClosedByPeer())
    }

    func testMultipleClientsAtOnce() throws {
        let a = try TestTCPClient(port: port)
        let b = try TestTCPClient(port: port)
        a.send("F 3573000\n")
        XCTAssertEqual(a.readLines(1), ["RPRT 0"])
        b.send("f\n")
        XCTAssertEqual(b.readLines(1), ["3573000"])
    }

    func testReconnectAfterDisconnect() throws {
        do {
            let c = try TestTCPClient(port: port)
            c.send("f\n")
            XCTAssertEqual(c.readLines(1), ["144174000"])
        }   // klient zamknięty (deinit)
        let c2 = try TestTCPClient(port: port)
        c2.send("f\n")
        XCTAssertEqual(c2.readLines(1), ["144174000"])
    }

    func testStopRefusesNewConnections() throws {
        server.stop()
        server = nil
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertThrowsError(try TestTCPClient(port: port))
    }
}
