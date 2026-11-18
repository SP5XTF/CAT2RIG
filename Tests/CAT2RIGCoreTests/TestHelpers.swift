import Foundation
import Darwin
import XCTest
@testable import CAT2RIGCore

/// Atrapa IC-706MKIIG podłączonej do magistrali CI-V.
/// Zachowuje się jak prawdziwe radio z interfejsem CT-17: każdą wysłaną ramkę
/// najpierw odsyła jako echo, potem odpowiada (dane, ACK albo NAK).
final class FakeRadio: SerialTransport {
    let addr: UInt8
    private let cond = NSCondition()
    private var rxBuffer: [UInt8] = []          // bajty czekające na odczyt przez IcomRig

    // stan radia
    private var _freq: Int
    private var _mode: UInt8
    private var _filter: UInt8 = 2
    private var _memoryMode = false
    private var _dataMode: UInt8 = 0
    private var _civPTT = false

    // scenariusz
    private var _silent = false
    private var _nakAll = false
    private var _echo = true
    private var _maxReadChunk = 64

    // obserwacja
    private var _rts = false
    private var _dtr = false
    private var _closed = false
    private var _written: [[UInt8]] = []

    init(addr: UInt8 = 0x58, freq: Int = 14_074_000, mode: UInt8 = 0x01, filter: UInt8 = 2) {
        self.addr = addr
        self._freq = freq
        self._mode = mode
        self._filter = filter
    }

    private func locked<T>(_ body: () -> T) -> T {
        cond.lock(); defer { cond.unlock() }
        return body()
    }

    var freq: Int { locked { _freq } }
    var dataMode: UInt8 { locked { _dataMode } }
    var civPTT: Bool { locked { _civPTT } }
    /// Tryb pamięci (V/M = MEMO). Jak w scenariuszu z prawdziwym radiem:
    /// w tym trybie radio odrzuca ustawienie częstotliwości (NAK).
    var memoryMode: Bool {
        get { locked { _memoryMode } }
        set { locked { _memoryMode = newValue } }
    }
    var mode: UInt8 { locked { _mode } }
    var rts: Bool { locked { _rts } }
    var dtr: Bool { locked { _dtr } }
    var closed: Bool { locked { _closed } }
    var writtenFrames: [[UInt8]] { locked { _written } }

    var silent: Bool {
        get { locked { _silent } }
        set { locked { _silent = newValue } }
    }
    var nakAll: Bool {
        get { locked { _nakAll } }
        set { locked { _nakAll = newValue } }
    }
    var echo: Bool {
        get { locked { _echo } }
        set { locked { _echo = newValue } }
    }
    /// Ile bajtów maksymalnie oddaje jeden read() – pozwala testować ramki pocięte na kawałki.
    var maxReadChunk: Int {
        get { locked { _maxReadChunk } }
        set { locked { _maxReadChunk = newValue } }
    }

    /// Symulacja kręcenia gałką: radio zmienia częstotliwość i nadaje ramkę transceive.
    func turnDial(to hz: Int) {
        locked {
            _freq = hz
            rxBuffer += [0xFE, 0xFE, 0x00, addr, 0x00] + CIV.freqToBCD(hz) + [0xFD]
            cond.broadcast()
        }
    }

    /// Wstrzyknięcie dowolnych bajtów na magistralę.
    func inject(_ bytes: [UInt8]) {
        locked {
            rxBuffer += bytes
            cond.broadcast()
        }
    }

    // MARK: SerialTransport

    func read(into buf: inout [UInt8]) -> Int {
        cond.lock(); defer { cond.unlock() }
        if rxBuffer.isEmpty && !_closed {
            _ = cond.wait(until: Date().addingTimeInterval(0.05))   // jak VTIME w termios
        }
        if _closed { return -1 }
        let n = min(rxBuffer.count, buf.count, _maxReadChunk)
        guard n > 0 else { return 0 }
        for i in 0..<n { buf[i] = rxBuffer[i] }
        rxBuffer.removeFirst(n)
        return n
    }

    func write(_ bytes: [UInt8]) -> Bool {
        cond.lock(); defer { cond.unlock() }
        if _closed { return false }
        _written.append(bytes)
        if _echo { rxBuffer += bytes }
        respond(to: bytes)
        cond.broadcast()
        return true
    }

    func setRTS(_ on: Bool) { locked { _rts = on } }
    func setDTR(_ on: Bool) { locked { _dtr = on } }

    func close() {
        locked {
            _closed = true
            cond.broadcast()
        }
    }

    /// Wywoływane z zablokowanym `cond`.
    private func respond(to f: [UInt8]) {
        guard !_silent, f.count >= 6, f[0] == 0xFE, f[1] == 0xFE, f.last == 0xFD, f[2] == addr else {
            return
        }
        let ctl = f[3], cmd = f[4]
        let data = Array(f[5..<(f.count - 1)])
        func reply(_ payload: [UInt8]) {
            rxBuffer += [0xFE, 0xFE, ctl, addr] + payload + [0xFD]
        }
        if _nakAll {
            reply([0xFA])
            return
        }
        switch cmd {
        case 0x03:
            reply([0x03] + CIV.freqToBCD(_freq))
        case 0x04:
            reply([0x04, _mode, _filter])
        case 0x05:
            if !_memoryMode, let f = CIV.bcdToFreq(data) {
                _freq = f
                reply([0xFB])
            } else {
                reply([0xFA])
            }
        case 0x07:
            if data.isEmpty { _memoryMode = false }
            reply([0xFB])
        case 0x1A where data.first == 0x06:
            if data.count == 1 {
                reply([0x1A, 0x06, _dataMode, _dataMode == 0 ? 0 : 1])   // odczyt trybu DATA
            } else {
                _dataMode = data[1]
                reply([0xFB])
            }
        case 0x1C where data.first == 0x00 && data.count == 2:
            _civPTT = data[1] != 0
            reply([0xFB])
        case 0x08:
            _memoryMode = true
            reply([0xFB])
        case 0x06:
            if let m = data.first, CIV.modes[m] != nil {
                _mode = m
                reply([0xFB])
            } else {
                reply([0xFA])
            }
        default:
            reply([0xFA])
        }
    }
}

/// Czeka (aktywnie, co 10 ms), aż warunek będzie spełniony.
@discardableResult
func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        Thread.sleep(forTimeInterval: 0.01)
    }
    return condition()
}

/// Najprostszy klient TCP (gniazdo BSD) – tak jak łączy się Hamlib.
final class TestTCPClient {
    private let fd: Int32
    private var pending: [UInt8] = []

    init(port: UInt16) throws {
        fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SerialError.open("socket()") }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard rc == 0 else {
            Darwin.close(fd)
            throw SerialError.open("connect() na porcie \(port): \(String(cString: strerror(errno)))")
        }
        var tv = timeval(tv_sec: 3, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    deinit { Darwin.close(fd) }

    func send(_ text: String) {
        let bytes = Array(text.utf8)
        _ = bytes.withUnsafeBytes { Darwin.send(fd, $0.baseAddress, $0.count, 0) }
    }

    /// Czyta dokładnie `count` linii (bez znaków nowej linii). Pusta tablica przy timeoucie.
    func readLines(_ count: Int) -> [String] {
        var lines: [String] = []
        var chunk = [UInt8](repeating: 0, count: 4096)
        while lines.count < count {
            if let nl = pending.firstIndex(of: 0x0A) {
                lines.append(String(decoding: pending[..<nl], as: UTF8.self))
                pending.removeSubrange(...nl)
                continue
            }
            let n = chunk.withUnsafeMutableBytes { Darwin.recv(fd, $0.baseAddress, $0.count, 0) }
            if n <= 0 { break }
            pending += chunk[0..<n]
        }
        return lines
    }

    /// Czyta linie aż do (włącznie) linii równej `terminator`.
    func readLines(until terminator: String, max: Int = 500) -> [String] {
        var lines: [String] = []
        while lines.count < max {
            let l = readLines(1)
            if l.isEmpty { break }
            lines += l
            if l[0] == terminator { break }
        }
        return lines
    }

    /// true, gdy serwer zamknął połączenie.
    func isClosedByPeer() -> Bool {
        var b = [UInt8](repeating: 0, count: 16)
        let n = b.withUnsafeMutableBytes { Darwin.recv(fd, $0.baseAddress, $0.count, 0) }
        return n == 0
    }
}

extension XCTestCase {
    /// Tworzy IcomRig na atrapie radia i czeka, aż radio "odpowie".
    func makeRig(_ radio: FakeRadio, pttTransport: SerialTransport? = nil,
                 pttMethod: PTTMethod = .off, pollInterval: TimeInterval = 0.05,
                 waitOnline: Bool = true,
                 file: StaticString = #filePath, line: UInt = #line) -> IcomRig {
        let rig = IcomRig(transport: radio, pttTransport: pttTransport, rigAddr: radio.addr,
                          pollInterval: pollInterval, responseTimeout: 0.2, pttMethod: pttMethod)
        if waitOnline {
            XCTAssertTrue(waitUntil { rig.state.online }, "radio nie odpowiedziało", file: file, line: line)
        }
        addTeardownBlock { rig.close() }
        return rig
    }
}
