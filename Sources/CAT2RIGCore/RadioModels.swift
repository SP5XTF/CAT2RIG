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

    public var displayName: String { "\(manufacturer) \(name)" }
    public var usesCIV: Bool { kind == .icom }

    static func icom(_ id: String, _ name: String, _ addr: UInt8, baud: Int = 19200,
                     ptt: Bool = true, data: Bool = true, maker: String = "Icom") -> RadioModel {
        RadioModel(id: id, manufacturer: maker, name: name, kind: .icom, civAddress: addr,
                   defaultBaud: baud, stopBits: 1, rtsCts: false, catPTT: ptt,
                   icomDataMode: data, freqDigits: 10)
    }

    static func yaesu(_ id: String, _ name: String, baud: Int = 38400, digits: Int = 9,
                      rtsCts: Bool = true) -> RadioModel {
        RadioModel(id: id, manufacturer: "Yaesu", name: name, kind: .yaesuText, civAddress: 0,
                   defaultBaud: baud, stopBits: 2, rtsCts: rtsCts, catPTT: true,
                   icomDataMode: false, freqDigits: digits)
    }

    static func yaesuOld(_ id: String, _ name: String) -> RadioModel {
        RadioModel(id: id, manufacturer: "Yaesu", name: name, kind: .yaesuBinary, civAddress: 0,
                   defaultBaud: 4800, stopBits: 2, rtsCts: false, catPTT: true,
                   icomDataMode: false, freqDigits: 8)
    }

    static func kenwood(_ id: String, _ name: String, baud: Int, maker: String = "Kenwood") -> RadioModel {
        RadioModel(id: id, manufacturer: maker, name: name, kind: .kenwood, civAddress: 0,
                   defaultBaud: baud, stopBits: 1, rtsCts: false, catPTT: true,
                   icomDataMode: false, freqDigits: 11)
    }

    public static let all: [RadioModel] = [
        // Icom – adresy CI-V domyślne z fabryki (sprawdź w menu radia)
        icom("ic706mk2g", "IC-706MKIIG", 0x58, ptt: false, data: false),
        icom("ic7000", "IC-7000", 0x70, data: false),
        icom("ic7100", "IC-7100", 0x88),
        icom("ic7300", "IC-7300", 0x94),
        icom("ic705", "IC-705", 0xA4),
        icom("ic9700", "IC-9700", 0xA2),
        icom("ic7610", "IC-7610", 0x98),
        icom("ic718", "IC-718", 0x5E, baud: 9600, ptt: false, data: false),
        icom("icom", L("(inny model CI-V)"), 0x94, data: false),
        // Xiegu – CI-V zgodne z Icom
        icom("g90", "G90", 0x88, data: false, maker: "Xiegu"),
        icom("x6100", "X6100", 0x70, data: false, maker: "Xiegu"),
        icom("x5105", "X5105", 0x70, data: false, maker: "Xiegu"),
        // Yaesu – nowszy protokół tekstowy
        yaesu("ft991", "FT-991/991A"),
        yaesu("ft891", "FT-891"),
        yaesu("ft710", "FT-710"),
        yaesu("ftdx10", "FTDX10"),
        yaesu("ftdx101", "FTDX101D/MP"),
        yaesu("ft950", "FT-950", digits: 8),
        yaesu("ft450", "FT-450D", digits: 8),
        // Yaesu – starszy protokół binarny
        yaesuOld("ft817", "FT-817/818"),
        yaesuOld("ft857", "FT-857/857D"),
        yaesuOld("ft897", "FT-897/897D"),
        // Kenwood i Elecraft
        kenwood("ts590", "TS-590S/SG", baud: 115200),
        kenwood("ts480", "TS-480", baud: 57600),
        kenwood("ts2000", "TS-2000", baud: 57600),
        kenwood("k3", "K3/K3S", baud: 38400, maker: "Elecraft"),
        kenwood("kx3", "KX2/KX3", baud: 38400, maker: "Elecraft"),
        kenwood("k4", "K4", baud: 38400, maker: "Elecraft"),
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
                           dataModeCommand: model.icomDataMode, log: log)
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
