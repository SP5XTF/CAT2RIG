import Foundation

/// Odmiana tekstowego protokołu CAT (komendy zakończone średnikiem).
public struct TextCatDialect {
    /// Liczba cyfr częstotliwości w komendzie FA (Kenwood/Elecraft 11, Yaesu 9 lub 8).
    public let freqDigits: Int
    /// Zapytanie o emisję i prefiks odpowiedzi/ustawienia ("MD" Kenwood, "MD0" Yaesu).
    public let modeQuery: String
    public let modePrefix: String
    /// kod emisji radia -> nazwa Hamlib
    public let modes: [String: String]
    /// nazwa Hamlib -> kod emisji radia
    public let setModes: [String: String]
    public let pttOn: String
    public let pttOff: String
    /// Komendy wysyłane raz po połączeniu (np. wyłączenie Auto Information).
    public let prepare: [String]
    /// Mierniki (nil – brak): zapytanie S-metra i mocy, prefiks odpowiedzi i kalibracja.
    public let sMeterQuery: (query: String, prefix: String, cal: Meters.Cal)?
    public let powerQuery: (query: String, prefix: String, cal: Meters.Cal)?

    /// Kenwood (TS-590, TS-480, TS-2000) i Elecraft (K3, KX2/KX3, K4).
    public static func kenwood(freqDigits: Int = 11) -> TextCatDialect {
        TextCatDialect(
            freqDigits: freqDigits, modeQuery: "MD;", modePrefix: "MD",
            modes: ["1": "LSB", "2": "USB", "3": "CW", "4": "FM", "5": "AM",
                    "6": "RTTY", "7": "CWR", "9": "RTTYR"],
            setModes: ["LSB": "1", "USB": "2", "CW": "3", "FM": "4", "AM": "5",
                       "RTTY": "6", "CWR": "7", "RTTYR": "9",
                       "PKTUSB": "2", "PKTLSB": "1", "PKTFM": "4"],
            pttOn: "TX;", pttOff: "RX;",
            prepare: ["AI0;"],
            sMeterQuery: nil, powerQuery: nil)       // skale S-metra różnią się między modelami
    }

    /// Nowsze Yaesu (FT-991/991A, FT-891, FT-710, FTDX10, FTDX101, FT-950, FT-450).
    public static func yaesu(freqDigits: Int = 9) -> TextCatDialect {
        TextCatDialect(
            freqDigits: freqDigits, modeQuery: "MD0;", modePrefix: "MD0",
            modes: ["1": "LSB", "2": "USB", "3": "CW", "4": "FM", "5": "AM",
                    "6": "RTTY", "7": "CWR", "8": "PKTLSB", "9": "RTTYR",
                    "A": "PKTFM", "B": "FM", "C": "PKTUSB", "D": "AM", "E": "FM"],
            setModes: ["LSB": "1", "USB": "2", "CW": "3", "FM": "4", "AM": "5",
                       "RTTY": "6", "CWR": "7", "PKTLSB": "8", "RTTYR": "9",
                       "PKTFM": "A", "PKTUSB": "C"],
            pttOn: "TX1;", pttOff: "TX0;",
            prepare: ["AI0;"],
            sMeterQuery: ("SM0;", "SM0", Meters.yaesuSMeter),
            powerQuery: ("RM5;", "RM5", Meters.yaesuPower))
    }
}

/// Sterownik tekstowego CAT: Yaesu (nowsze) oraz Kenwood/Elecraft.
/// Odpowiedzi: "FA00014074000;", "MD2;" (Kenwood) albo "FA014074000;", "MD02;" (Yaesu).
final class TextCatRig: PolledSerialRig, @unchecked Sendable {
    let dialect: TextCatDialect

    init(dialect: TextCatDialect, transport: SerialTransport, pttTransport: SerialTransport? = nil,
         pollInterval: TimeInterval = 0.5, responseTimeout: TimeInterval = 0.5,
         pttMethod: PTTMethod = .off, log: @escaping (String) -> Void = { _ in }) {
        self.dialect = dialect
        super.init(transport: transport, pttTransport: pttTransport, pollInterval: pollInterval,
                   responseTimeout: responseTimeout, pttMethod: pttMethod, textProtocol: true, log: log)
    }

    override func prepare() {
        for cmd in dialect.prepare { _ = send(cmd) }
    }

    override func pollOnce() {
        if let f = queryFreq() { updateFreq(f) }
        if let m = queryMode() { updateMode(m) }
        if isTransmitting {
            if let q = dialect.powerQuery { updatePower(readMeter(q).map { Int($0.rounded()) }) }
        } else if let q = dialect.sMeterQuery {
            updateSMeter(readMeter(q).map { Int($0.rounded()) })
        }
    }

    /// Odczyt miernika: pierwsze 3 cyfry po prefiksie (np. "SM0130", "RM5147000").
    private func readMeter(_ q: (query: String, prefix: String, cal: Meters.Cal)) -> Double? {
        guard send(q.query), let r = readText(prefix: q.prefix) else { return nil }
        let digits = r.dropFirst(q.prefix.count).prefix(3)
        guard let raw = Int(digits) else { return nil }
        return Meters.interpolate(Double(raw), q.cal)
    }

    private func queryFreq() -> Int? {
        guard send("FA;"), let r = readText(prefix: "FA") else { return nil }
        return Int(r.dropFirst(2))
    }

    private func queryMode() -> String? {
        guard send(dialect.modeQuery), let r = readText(prefix: dialect.modePrefix) else { return nil }
        let code = String(r.dropFirst(dialect.modePrefix.count))
        return dialect.modes[code]
    }

    override func doSetFreq(_ hz: Int) -> HamlibErr {
        let digits = String(hz)
        guard digits.count <= dialect.freqDigits else { return .einval }
        let cmd = "FA" + String(repeating: "0", count: dialect.freqDigits - digits.count) + digits + ";"
        guard send(cmd) else { return .etimeout }
        // te radia nie potwierdzają ustawienia – sprawdzamy odczytem
        guard let f = queryFreq() else { return .etimeout }
        updateFreq(f)
        return abs(f - hz) <= 10 ? .ok : .erjcted
    }

    override func doSetMode(_ name: String) -> HamlibErr {
        guard let code = dialect.setModes[name] else { return .einval }
        guard send(dialect.modePrefix + code + ";") else { return .etimeout }
        guard let m = queryMode() else { return .etimeout }
        updateMode(m)
        return .ok
    }

    override func doCatPTT(_ on: Bool) -> HamlibErr {
        send(on ? dialect.pttOn : dialect.pttOff) ? .ok : .etimeout
    }
}
