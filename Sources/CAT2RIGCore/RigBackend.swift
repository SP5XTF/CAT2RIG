import Foundation

/// Sposób kluczowania nadajnika.
public enum PTTMethod: String, CaseIterable, Identifiable {
    case off = "none"   // brak / VOX
    case cat            // komendą CAT (CI-V 1C 00, Yaesu TX1;, Kenwood TX;, FT-817 0x08)
    case rts, dtr       // linią RTS/DTR interfejsu
    public var id: String { rawValue }
}

/// Kody błędów Hamlib (RPRT n).
public enum HamlibErr: Int {
    case ok = 0, einval = -1, etimeout = -5, erjcted = -9, enavail = -11
}

public struct RigState: Equatable {
    public var freq = 0
    public var mode = "USB"
    public var width = 2400
    public var ptt = false
    public var online = false
    /// Szybkie zmiany częstotliwości – radio skanuje (SCAN) albo ktoś szybko kręci gałką.
    public var scanning = false
}

/// Wspólny interfejs sterowników radia (Icom/Xiegu CI-V, Yaesu, Kenwood/Elecraft).
/// Używa go serwer rigctl i okno programu.
public protocol RigBackend: AnyObject, Sendable {
    var state: RigState { get }
    var debugFrames: Bool { get set }
    func setFreq(_ hz: Int) -> HamlibErr
    func setMode(_ name: String) -> HamlibErr
    func setPTT(_ on: Bool) -> HamlibErr
    func close()
}

/// Wykrywanie SCAN – wspólne dla wszystkich sterowników.
public enum ScanDetection {
    public static let window: TimeInterval = 2.0
    public static let minChanges = 4
}

/// Przybliżone szerokości filtrów do raportowania klientom.
public enum ModeWidths {
    public static func width(for mode: String, narrow: Bool = false) -> Int {
        let base = mode.hasPrefix("PKT") ? String(mode.dropFirst(3)) : mode
        switch base {
        case "LSB", "USB": return narrow ? 1800 : (mode.hasPrefix("PKT") ? 3000 : 2400)
        case "CW", "CWR": return narrow ? 500 : 2400
        case "RTTY", "RTTYR": return narrow ? 500 : 2400
        case "AM": return narrow ? 2400 : 9000
        case "FM": return narrow ? 6000 : 15000
        case "WFM": return 230000
        default: return 2400
        }
    }
}
