import Foundation

/// Przeliczanie surowych odczytów S-metra i mocy z radia.
/// Konwencja jak w Hamlib: siła sygnału w dB względem S9 (S0 = -54, S9 = 0, S9+60 = +60),
/// moc w procentach mocy maksymalnej (0–100).
public enum Meters {

    /// Tabela kalibracji: pary (odczyt surowy, wartość), rosnąco wg odczytu.
    public typealias Cal = [(raw: Double, value: Double)]

    /// Interpolacja liniowa w tabeli kalibracji (poza zakresem – wartości skrajne).
    public static func interpolate(_ raw: Double, _ cal: Cal) -> Double {
        guard let first = cal.first, let last = cal.last else { return raw }
        if raw <= first.raw { return first.value }
        if raw >= last.raw { return last.value }
        for i in 1..<cal.count where raw <= cal[i].raw {
            let a = cal[i - 1], b = cal[i]
            return a.value + (raw - a.raw) * (b.value - a.value) / (b.raw - a.raw)
        }
        return last.value
    }

    // Kalibracje wg Hamlib 4.7 (IC-7300, FT-710/FT-991).
    /// Icom 15 02: 0–255 (0 = S0, 120 = S9, 241 = S9+60)
    public static let icomSMeter: Cal = [(0, -54), (10, -48), (30, -36), (60, -24), (90, -12),
                                         (120, 0), (241, 60)]
    /// Icom 15 11 (Po): 0–255 -> % mocy
    public static let icomPower: Cal = [(0, 0), (21, 5), (43, 10), (65, 15), (83, 20), (95, 25),
                                        (105, 30), (114, 35), (124, 40), (143, 50), (183, 75),
                                        (213, 100)]
    /// Yaesu SM0: 0–255
    public static let yaesuSMeter: Cal = [(0, -54), (12, -48), (27, -42), (40, -36), (55, -30),
                                          (65, -24), (80, -18), (95, -12), (112, -6), (130, 0),
                                          (150, 10), (172, 20), (190, 30), (220, 40), (240, 50),
                                          (255, 60)]
    /// Yaesu RM5: 0–255 -> % mocy (radia 100 W)
    public static let yaesuPower: Cal = [(0, 0), (27, 5), (94, 25), (147, 50), (176, 75), (205, 100)]

    /// FT-817/857/897: S-metr 0–15 (0–9 = S0–S9, 10–15 = S9+10…+60).
    public static func ft817SMeter(_ n: Int) -> Int {
        n <= 9 ? (n - 9) * 6 : (n - 9) * 10
    }

    /// Tekst S-metra: "S7", "S9", "S9+20".
    public static func sText(_ db: Int) -> String {
        if db > 0 { return "S9+\(db)" }
        let s = max(0, min(9, Int((Double(db + 54) / 6).rounded())))
        return "S\(s)"
    }

    /// Położenie na skali 0…1: S0–S9 zajmuje 60 % skali, +60 dB pozostałe 40 %.
    public static func sFraction(_ db: Int) -> Double {
        let d = Double(max(-54, min(60, db)))
        return d <= 0 ? 0.6 * (d + 54) / 54 : 0.6 + 0.4 * d / 60
    }

    /// Dwa bajty BCD (Icom 15 xx): [0x01, 0x20] -> 120
    public static func bcd2(_ hi: UInt8, _ lo: UInt8) -> Int? {
        let digits = [hi >> 4, hi & 0x0F, lo >> 4, lo & 0x0F]
        guard digits.allSatisfy({ $0 <= 9 }) else { return nil }
        return digits.reduce(0) { $0 * 10 + Int($1) }
    }
}
