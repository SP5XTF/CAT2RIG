import Foundation
@testable import CAT2RIGCore

/// Wspólna część atrap: bufor odczytu z czekaniem jak VTIME w termios.
class FakeSerialBase: SerialTransport {
    let cond = NSCondition()
    var rxBuffer: [UInt8] = []
    private var _rts = false, _dtr = false, _closed = false

    func locked<T>(_ body: () -> T) -> T {
        cond.lock(); defer { cond.unlock() }
        return body()
    }

    var rts: Bool { locked { _rts } }
    var dtr: Bool { locked { _dtr } }
    var closed: Bool { locked { _closed } }

    /// Wywoływane z zablokowanym `cond` dla każdego zapisu.
    func handle(_ bytes: [UInt8]) {}

    func read(into buf: inout [UInt8]) -> Int {
        cond.lock(); defer { cond.unlock() }
        if rxBuffer.isEmpty && !_closed {
            _ = cond.wait(until: Date().addingTimeInterval(0.05))
        }
        if _closed { return -1 }
        let n = min(rxBuffer.count, buf.count)
        guard n > 0 else { return 0 }
        for i in 0..<n { buf[i] = rxBuffer[i] }
        rxBuffer.removeFirst(n)
        return n
    }

    func write(_ bytes: [UInt8]) -> Bool {
        cond.lock(); defer { cond.unlock() }
        if _closed { return false }
        handle(bytes)
        cond.broadcast()
        return true
    }

    func inject(_ bytes: [UInt8]) {
        locked { rxBuffer += bytes; cond.broadcast() }
    }

    func setRTS(_ on: Bool) { locked { _rts = on } }
    func setDTR(_ on: Bool) { locked { _dtr = on } }
    func close() { locked { _closed = true; cond.broadcast() } }
}

/// Atrapa radia z tekstowym CAT – Kenwood/Elecraft albo nowsze Yaesu.
final class FakeTextRadio: FakeSerialBase {
    enum Kind { case kenwood, yaesu }
    let kind: Kind
    private var _freq: Int
    private var _mode: String          // kod emisji radia, np. "2"
    private var _ptt = false
    private var _aiOff = false
    private var _commands: [String] = []
    private var partial = ""
    /// Częstotliwości powyżej tej wartości radio odrzuca ("?;").
    var maxFreq = 470_000_000

    init(kind: Kind, freq: Int = 14_074_000, mode: String = "2") {
        self.kind = kind
        _freq = freq
        _mode = mode
    }

    var freq: Int { locked { _freq } }
    var modeCode: String { locked { _mode } }
    var catPTT: Bool { locked { _ptt } }
    var aiDisabled: Bool { locked { _aiOff } }
    var commands: [String] { locked { _commands } }

    private var digits: Int { kind == .kenwood ? 11 : 9 }
    private var modePrefix: String { kind == .kenwood ? "MD" : "MD0" }

    private func pad(_ v: Int) -> String {
        let s = String(v)
        return String(repeating: "0", count: max(0, digits - s.count)) + s
    }

    private func reply(_ s: String) { rxBuffer += Array(s.utf8) }

    override func handle(_ bytes: [UInt8]) {
        partial += String(decoding: bytes, as: UTF8.self)
        while let semi = partial.firstIndex(of: ";") {
            let cmd = String(partial[..<semi])
            partial.removeSubrange(...semi)
            _commands.append(cmd)
            execute(cmd)
        }
    }

    private func execute(_ cmd: String) {
        if cmd == "FA" { reply("FA" + pad(_freq) + ";"); return }
        if cmd.hasPrefix("FA"), let v = Int(cmd.dropFirst(2)) {
            if v > maxFreq { reply("?;") } else { _freq = v }
            return
        }
        if cmd == modePrefix { reply(modePrefix + _mode + ";"); return }
        if cmd.hasPrefix(modePrefix) { _mode = String(cmd.dropFirst(modePrefix.count)); return }
        switch cmd {
        case "AI0": _aiOff = true
        case "TX", "TX1": _ptt = true
        case "RX", "TX0": _ptt = false
        default: reply("?;")
        }
    }

    /// Komunikat Auto Information wysłany przez radio bez pytania.
    func sendAutoInfo(freq: Int) {
        locked { _freq = freq; reply("FA" + pad(freq) + ";"); cond.broadcast() }
    }
}

/// Atrapa Yaesu FT-817/857/897 – binarne komendy 5-bajtowe.
final class FakeFT817: FakeSerialBase {
    private var _freq: Int
    private var _mode: UInt8
    private var _ptt = false
    /// Czy radio odsyła bajt potwierdzenia po komendach ustawiających.
    var sendsAck = false

    init(freq: Int = 7_074_000, mode: UInt8 = 0x01) {
        _freq = freq
        _mode = mode
    }

    var freq: Int { locked { _freq } }
    var mode: UInt8 { locked { _mode } }
    var catPTT: Bool { locked { _ptt } }

    private var partial: [UInt8] = []

    override func handle(_ bytes: [UInt8]) {
        partial += bytes
        while partial.count >= 5 {
            let c = Array(partial.prefix(5))
            partial.removeFirst(5)
            switch c[4] {
            case 0x03:
                rxBuffer += YaesuBinaryRig.freqToBCD(_freq) + [_mode]
            case 0x01:
                if let f = YaesuBinaryRig.bcdToFreq(c[0..<4]) { _freq = f }
                if sendsAck { rxBuffer += [0x00] }
            case 0x07:
                _mode = c[0]
                if sendsAck { rxBuffer += [0x00] }
            case 0x08:
                rxBuffer += [_ptt ? 0xF0 : 0x00]
                _ptt = true
            case 0x88:
                rxBuffer += [_ptt ? 0x00 : 0xF0]
                _ptt = false
            default:
                break
            }
        }
    }
}
