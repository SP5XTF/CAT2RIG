import Foundation

/// Rodzina protokołu CAT.
public enum RigProtocolKind: String {
    case icom          // CI-V (Icom, Xiegu)
    case yaesuText     // nowsze Yaesu: FA…; MD0…;
    case yaesuBinary   // FT-817/818, FT-857, FT-897
    case kenwood       // Kenwood, Elecraft: FA…; MD…;
}

/// Model radia z ustawieniami domyślnymi. Wszystkie (poza rodziną protokołu)
/// można zmienić w oknie programu.
public struct RadioModel: Identifiable, Hashable {
    public let id: String
    public let manufacturer: String
    public let name: String
    public let kind: RigProtocolKind
    public let civAddress: UInt8
    public let defaultBaud: Int
    public let stopBits: Int
    public let rtsCts: Bool
    /// Radio przyjmuje PTT komendą CAT.
    public let catPTT: Bool
    /// Icom: tryb DATA komendą 1A 06.
    public let icomDataMode: Bool
    /// Tekstowe protokoły: liczba cyfr częstotliwości w FA.
    public let freqDigits: Int
    /// Numer modelu w Hamlib (`rigctl -l`) – do dokumentacji i przyszłego sterownika Hamlib.
    /// 0 = brak odpowiednika (np. „inny model CI-V”).
    public let hamlibID: Int
    /// Sprawdzone na prawdziwym radiu (a nie tylko na symulatorze protokołu).
    public let verified: Bool

    public var displayName: String { "\(manufacturer) \(name)" }
    public var usesCIV: Bool { kind == .icom }

    static func icom(_ id: String, _ name: String, _ addr: UInt8, hamlib: Int, baud: Int = 19200,
                     ptt: Bool = true, data: Bool = true, maker: String = "Icom",
                     verified: Bool = false) -> RadioModel {
        RadioModel(id: id, manufacturer: maker, name: name, kind: .icom, civAddress: addr,
                   defaultBaud: baud, stopBits: 1, rtsCts: false, catPTT: ptt,
                   icomDataMode: data, freqDigits: 10, hamlibID: hamlib, verified: verified)
    }

    static func yaesu(_ id: String, _ name: String, hamlib: Int, baud: Int = 38400, digits: Int = 9,
                      rtsCts: Bool = true, verified: Bool = false) -> RadioModel {
        RadioModel(id: id, manufacturer: "Yaesu", name: name, kind: .yaesuText, civAddress: 0,
                   defaultBaud: baud, stopBits: 2, rtsCts: rtsCts, catPTT: true,
                   icomDataMode: false, freqDigits: digits, hamlibID: hamlib, verified: verified)
    }

    static func yaesuOld(_ id: String, _ name: String, hamlib: Int) -> RadioModel {
        RadioModel(id: id, manufacturer: "Yaesu", name: name, kind: .yaesuBinary, civAddress: 0,
                   defaultBaud: 4800, stopBits: 2, rtsCts: false, catPTT: true,
                   icomDataMode: false, freqDigits: 8, hamlibID: hamlib, verified: false)
    }

    static func kenwood(_ id: String, _ name: String, hamlib: Int, baud: Int,
                        maker: String = "Kenwood") -> RadioModel {
        RadioModel(id: id, manufacturer: maker, name: name, kind: .kenwood, civAddress: 0,
                   defaultBaud: baud, stopBits: 1, rtsCts: false, catPTT: true,
                   icomDataMode: false, freqDigits: 11, hamlibID: hamlib, verified: false)
    }

    /// Katalog modeli. Numery Hamlib i nazwy wg listy Hamlib 4.7.1
    /// (github.com/Hamlib/Hamlib/wiki/Supported-Radios). Adresy CI-V i prędkości to wartości
    /// fabryczne – użytkownik może je zmienić w oknie programu.
    public static let all: [RadioModel] = [
        // Icom – CI-V
        icom("ic706mk2g", "IC-706MKIIG", 0x58, hamlib: 3011, ptt: false, data: false, verified: true),
        icom("ic718", "IC-718", 0x5E, hamlib: 3013, baud: 9600, ptt: false, data: false),
        icom("ic746pro", "IC-746PRO", 0x66, hamlib: 3046, ptt: false, data: false),
        icom("ic756pro3", "IC-756PROIII", 0x6E, hamlib: 3057, ptt: false, data: false),
        icom("ic7000", "IC-7000", 0x70, hamlib: 3060, data: false),
        icom("ic7200", "IC-7200", 0x76, hamlib: 3061, data: false),
        icom("ic7410", "IC-7410", 0x80, hamlib: 3067, data: false),
        icom("ic7600", "IC-7600", 0x7A, hamlib: 3063, data: false),
        icom("ic9100", "IC-9100", 0x7C, hamlib: 3068, data: false),
        icom("ic7100", "IC-7100", 0x88, hamlib: 3070),
        icom("ic7300", "IC-7300", 0x94, hamlib: 3073),
        icom("ic705", "IC-705", 0xA4, hamlib: 3085),
        icom("ic9700", "IC-9700", 0xA2, hamlib: 3081),
        icom("ic7610", "IC-7610", 0x98, hamlib: 3078),
        icom("icom", L("(inny model CI-V)"), 0x94, hamlib: 0, data: false),
        // Xiegu – CI-V zgodne z Icom
        icom("g90", "G90", 0x88, hamlib: 3088, data: false, maker: "Xiegu"),
        icom("x6100", "X6100", 0x70, hamlib: 3087, data: false, maker: "Xiegu"),
        icom("x5105", "X5105", 0x70, hamlib: 3089, data: false, maker: "Xiegu"),
        icom("x108g", "X108G", 0x70, hamlib: 3076, ptt: false, data: false, maker: "Xiegu"),
        // Yaesu – nowszy protokół tekstowy
        yaesu("ft991", "FT-991/991A", hamlib: 1035),
        yaesu("ft891", "FT-891", hamlib: 1036),
        yaesu("ft710", "FT-710", hamlib: 1049),
        yaesu("ftdx10", "FTDX10", hamlib: 1042),
        yaesu("ftdx101", "FTDX101D/MP", hamlib: 1040),
        yaesu("ftdx5000", "FTDX5000", hamlib: 1032, digits: 8),
        yaesu("ftdx3000", "FTDX3000", hamlib: 1037, digits: 8),
        yaesu("ftdx1200", "FTDX1200", hamlib: 1034, digits: 8),
        yaesu("ft2000", "FT-2000", hamlib: 1029, digits: 8),
        yaesu("ft950", "FT-950", hamlib: 1028, digits: 8),
        yaesu("ft450", "FT-450/450D", hamlib: 1046, digits: 8),
        // Yaesu – starszy protokół binarny
        yaesuOld("ft817", "FT-817/818", hamlib: 1020),
        yaesuOld("ft857", "FT-857/857D", hamlib: 1022),
        yaesuOld("ft897", "FT-897/897D", hamlib: 1023),
        // Kenwood i radia z protokołem Kenwood
        kenwood("ts590", "TS-590S/SG", hamlib: 2031, baud: 115200),
        kenwood("ts480", "TS-480", hamlib: 2028, baud: 57600),
        kenwood("ts2000", "TS-2000", hamlib: 2014, baud: 57600),
        kenwood("k2", "K2", hamlib: 2021, baud: 4800, maker: "Elecraft"),
        kenwood("k3", "K3/K3S", hamlib: 2029, baud: 38400, maker: "Elecraft"),
        kenwood("kx3", "KX2/KX3", hamlib: 2045, baud: 38400, maker: "Elecraft"),
        kenwood("k4", "K4", hamlib: 2047, baud: 38400, maker: "Elecraft"),
        kenwood("qrplabs", "QDX/QCX/QMX", hamlib: 2052, baud: 9600, maker: "QRP Labs"),
        kenwood("trusdx", "(tr)uSDX", hamlib: 2055, baud: 38400, maker: "DL2MAN"),
    ]

    public static let defaultModel = all[0]

    public static func find(_ id: String?) -> RadioModel? {
        guard let id = id else { return nil }
        return all.first { $0.id == id }
    }

    public static var manufacturers: [String] {
        var seen = [String]()
        for m in all where !seen.contains(m.manufacturer) { seen.append(m.manufacturer) }
        return seen
    }
}

/// Tworzy sterownik odpowiedni dla modelu radia.
public enum RigFactory {

    /// Otwiera porty szeregowe i uruchamia sterownik.
    public static func open(model: RadioModel, portPath: String, baud: Int, civAddress: UInt8,
                            stopBits: Int, rtsCts: Bool, pttMethod: PTTMethod, pttPortPath: String?,
                            log: @escaping (String) -> Void) throws -> RigBackend {
        let port = SerialPort(path: portPath)
        try port.open(baud: baud, stopBits: stopBits, rtsCts: rtsCts)

        var ptt: SerialPort? = nil
        if pttMethod == .rts || pttMethod == .dtr,
           let p = pttPortPath, !p.isEmpty, p != portPath {
            let pp = SerialPort(path: p)
            do {
                try pp.open(baud: 9600, exclusive: false)   // WSJT-X może mieć ten port też otwarty
            } catch {
                port.close()
                throw error
            }
            ptt = pp
        }
        return make(model: model, transport: port, pttTransport: ptt, civAddress: civAddress,
                    pttMethod: pttMethod, log: log)
    }

    /// Sterownik na już otwartym transporcie (także w testach).
    public static func make(model: RadioModel, transport: SerialTransport,
                            pttTransport: SerialTransport? = nil, civAddress: UInt8? = nil,
                            pttMethod: PTTMethod = .off, pollInterval: TimeInterval = 0.5,
                            responseTimeout: TimeInterval = 0.5,
                            log: @escaping (String) -> Void = { _ in }) -> RigBackend {
        switch model.kind {
        case .icom:
            return IcomRig(transport: transport, pttTransport: pttTransport,
                           rigAddr: civAddress ?? model.civAddress, pollInterval: pollInterval,
                           responseTimeout: responseTimeout, pttMethod: pttMethod,
                           dataModeCommand: model.icomDataMode,
                           // miernik mocy 15 11 mają te same nowsze Icomy, co tryb DATA 1A 06
                           powerMeterCommand: model.icomDataMode, log: log)
        case .kenwood:
            return TextCatRig(dialect: .kenwood(freqDigits: model.freqDigits), transport: transport,
                              pttTransport: pttTransport, pollInterval: pollInterval,
                              responseTimeout: responseTimeout, pttMethod: pttMethod, log: log)
        case .yaesuText:
            return TextCatRig(dialect: .yaesu(freqDigits: model.freqDigits), transport: transport,
                              pttTransport: pttTransport, pollInterval: pollInterval,
                              responseTimeout: responseTimeout, pttMethod: pttMethod, log: log)
        case .yaesuBinary:
            return YaesuBinaryRig(transport: transport, pttTransport: pttTransport,
                                  pollInterval: pollInterval, responseTimeout: responseTimeout,
                                  pttMethod: pttMethod, log: log)
        }
    }
}
