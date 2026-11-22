import Foundation

/// Starsze Yaesu (FT-817/818, FT-857, FT-897): binarne komendy 5-bajtowe [P1 P2 P3 P4 KOD],
/// częstotliwość w BCD (big-endian, krok 10 Hz), port 8N2.
final class YaesuBinaryRig: PolledSerialRig, @unchecked Sendable {

    static let modes: [UInt8: String] = [
        0x00: "LSB", 0x01: "USB", 0x02: "CW", 0x03: "CWR", 0x04: "AM", 0x06: "WFM",
        0x08: "FM", 0x0A: "PKTUSB", 0x0C: "PKTFM",
        0x82: "CW", 0x83: "CWR", 0x84: "AM", 0x88: "FM",   // wersje wąskie
    ]
    static let setModes: [String: UInt8] = [
        "LSB": 0x00, "USB": 0x01, "CW": 0x02, "CWR": 0x03, "AM": 0x04, "FM": 0x08,
        "PKTUSB": 0x0A, "PKTLSB": 0x0A, "RTTY": 0x0A, "RTTYR": 0x0A, "PKTFM": 0x0C,
    ]

    init(transport: SerialTransport, pttTransport: SerialTransport? = nil,
         pollInterval: TimeInterval = 0.5, responseTimeout: TimeInterval = 0.5,
         pttMethod: PTTMethod = .off, log: @escaping (String) -> Void = { _ in }) {
        super.init(transport: transport, pttTransport: pttTransport, pollInterval: pollInterval,
                   responseTimeout: responseTimeout, pttMethod: pttMethod, textProtocol: false, log: log)
    }

    /// 14 074 000 Hz -> [01 40 74 00] (cyfry od najstarszej, w jednostkach 10 Hz)
    static func freqToBCD(_ hz: Int) -> [UInt8] {
        var v = hz / 10
        var out = [UInt8](repeating: 0, count: 4)
        for i in (0..<4).reversed() {
            let lo = v % 10; v /= 10
            let hi = v % 10; v /= 10
            out[i] = UInt8(hi << 4 | lo)
        }
        return out
    }

    static func bcdToFreq<C: Collection>(_ bytes: C) -> Int? where C.Element == UInt8 {
        guard bytes.count == 4 else { return nil }
        var v = 0
        for b in bytes {
            let hi = Int(b >> 4), lo = Int(b & 0x0F)
            guard hi <= 9, lo <= 9 else { return nil }
            v = v * 100 + hi * 10 + lo
        }
        return v * 10
    }

    private func command(_ p: [UInt8], _ code: UInt8) -> Bool {
        pending.removeAll()
        return send(p + [code])
    }

    /// Kod 0x03: 4 bajty częstotliwości + emisja.
    private func readStatus() -> (Int, String?)? {
        guard command([0, 0, 0, 0], 0x03), let r = readBytes(count: 5) else { return nil }
        guard let f = Self.bcdToFreq(r[0..<4]) else {
            pending.removeAll()                   // rozjechana ramka – zacznij od nowa
            return nil
        }
        return (f, Self.modes[r[4]])
    }

    /// Część radiów odsyła 1 bajt potwierdzenia po komendach ustawiających – zbieramy go,
    /// żeby nie przesunął następnej odpowiedzi.
    private func swallowAck() {
        _ = readBytes(count: 1, timeout: 0.1)
        pending.removeAll()
    }

    override func pollOnce() {
        guard let st = readStatus() else { return }
        updateFreq(st.0)
        if let m = st.1 { updateMode(m) }
        // 0xE7 – status odbioru (S-metr w młodszych 4 bitach), 0xF7 – nadawania (moc)
        if isTransmitting {
            if command([0, 0, 0, 0], 0xF7), let b = readBytes(count: 1), b[0] != 0xFF {
                updatePower(Int(b[0] & 0x0F) * 100 / 15)
            }
        } else if command([0, 0, 0, 0], 0xE7), let b = readBytes(count: 1) {
            updateSMeter(Meters.ft817SMeter(Int(b[0] & 0x0F)))
        }
    }

    override func doSetFreq(_ hz: Int) -> HamlibErr {
        guard hz / 10 < 100_000_000 else { return .einval }
        guard command(Self.freqToBCD(hz), 0x01) else { return .etimeout }
        swallowAck()
        guard let st = readStatus() else { return .etimeout }
        updateFreq(st.0)
        if let m = st.1 { updateMode(m) }
        return abs(st.0 - hz) <= 10 ? .ok : .erjcted
    }

    override func doSetMode(_ name: String) -> HamlibErr {
        guard let code = Self.setModes[name] else { return .einval }
        guard command([code, 0, 0, 0], 0x07) else { return .etimeout }
        swallowAck()
        if let st = readStatus(), let m = st.1 { updateMode(m) }
        return .ok
    }

    override func doCatPTT(_ on: Bool) -> HamlibErr {
        guard command([0, 0, 0, 0], on ? 0x08 : 0x88) else { return .etimeout }
        swallowAck()
        return .ok
    }
}
