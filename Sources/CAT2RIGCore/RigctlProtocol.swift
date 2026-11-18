import Foundation

/// Protokół rigctld (to, czego używa Hamlib "NET rigctl", model 2).
public enum RigctlProtocol {
    // Odpowiedź na \dump_state (protokół 1) – wspólna dla wszystkich radiów. Maska emisji Hamlib:
    // AM=1 CW=2 USB=4 LSB=8 RTTY=0x10 FM=0x20 WFM=0x40 CWR=0x80 RTTYR=0x100
    // PKTLSB=0x400 PKTUSB=0x800 PKTFM=0x1000  ->  0x1dff
    public static let dumpState: String = [
        "1",                                                    // wersja protokołu
        "2",                                                    // model: NET rigctl
        "0",                                                    // (dawniej region ITU)
        // zakresy RX: start stop emisje min_moc max_moc vfo antena
        "30000.000000 199999999.000000 0x1dff -1 -1 0x3 0x0",
        "400000000.000000 470000000.000000 0x1dff -1 -1 0x3 0x0",
        "1240000000.000000 1300000000.000000 0x1dff -1 -1 0x3 0x0",
        "0 0 0 0 0 0 0",
        // zakresy TX (moc w mW)
        "1800000.000000 54000000.000000 0x1dff 5000 100000 0x3 0x0",
        "70000000.000000 70500000.000000 0x1dff 5000 50000 0x3 0x0",
        "144000000.000000 148000000.000000 0x1dff 5000 50000 0x3 0x0",
        "430000000.000000 440000000.000000 0x1dff 5000 20000 0x3 0x0",
        "1240000000.000000 1300000000.000000 0x1dff 5000 10000 0x3 0x0",
        "0 0 0 0 0 0 0",
        // kroki strojenia
        "0x1dff 1", "0x1dff 10", "0x1dff 100", "0x1dff 1000",
        "0 0",
        // filtry
        "0x1c 2400", "0x1c 1800", "0x2 2400", "0x2 500",
        "0x1 9000", "0x1 2400", "0x20 15000", "0x20 6000", "0x40 230000",
        "0 0",
        "0",            // max RIT
        "0",            // max XIT
        "0",            // max IF shift
        "0",            // announces
        "10",           // preamp
        "20",           // tłumik
        "0x0", "0x0",   // funkcje get/set
        "0x0", "0x0",   // poziomy get/set
        "0x0", "0x0",   // parametry get/set
        "vfo_ops=0x0",
        "ptt_type=0x1", // RIG_PTT_RIG – klient wysyła PTT do nas
        "targetable_vfo=0x0",
        "has_set_vfo=1",
        "has_get_vfo=1",
        "has_set_freq=1",
        "has_get_freq=1",
        "has_set_mode=1",
        "has_get_mode=1",
        "has_set_ptt=1",
        "has_get_ptt=1",
        "timeout=1000",
        "done",
    ].joined(separator: "\n") + "\n"

    static let longNames: [String: String] = [
        "\\get_freq": "f", "\\set_freq": "F",
        "\\get_mode": "m", "\\set_mode": "M",
        "\\get_vfo": "v", "\\set_vfo": "V",
        "\\get_ptt": "t", "\\set_ptt": "T",
        "\\get_split_vfo": "s", "\\set_split_vfo": "S",
        "\\quit": "q",
    ]

    static func rprt(_ e: HamlibErr) -> String { "RPRT \(e.rawValue)\n" }

    /// Zwraca odpowiedź albo nil, gdy klient kończy sesję.
    public static func dispatch(_ rig: RigBackend, _ line: String) -> String? {
        let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard var cmd = parts.first else { return rprt(.einval) }
        // prefiksy trybu rozszerzonego (+ ; | ,) – odpowiadamy zwykłym formatem
        let stripped = String(cmd.drop(while: { "+;|,".contains($0) }))
        if !stripped.isEmpty { cmd = stripped }
        cmd = longNames[cmd] ?? cmd
        var args = Array(parts.dropFirst())
        // niektóre wersje Hamlib dodają VFO jako pierwszy argument (np. "F VFOA 14074000") – pomijamy go
        let vfoNames: Set<String> = ["VFOA", "VFOB", "VFOC", "currVFO", "VFO", "Main", "Sub",
                                     "MainA", "MainB", "SubA", "SubB", "TX", "RX", "MEM", "None"]
        if let first = args.first, vfoNames.contains(first), cmd != "V" {
            args.removeFirst()
        }

        switch cmd {
        case "q", "Q":
            return nil
        case "\\dump_state":
            return dumpState
        case "\\chk_vfo":
            return "0\n"
        case "\\get_powerstat":
            return "1\n"
        case "\\get_lock_mode":                 // Hamlib 4.7 pyta o to co kilka sekund
            return "0\n"
        case "\\set_lock_mode":
            return rprt(.ok)

        case "f":
            let s = rig.state
            return s.online ? "\(s.freq)\n" : rprt(.etimeout)
        case "F":
            guard let a = args.first, let v = Double(a) else { return rprt(.einval) }
            return rprt(rig.setFreq(Int(v.rounded())))

        case "m":
            let s = rig.state
            return s.online ? "\(s.mode)\n\(s.width)\n" : rprt(.etimeout)
        case "M":
            guard let a = args.first else { return rprt(.einval) }
            return rprt(rig.setMode(a))

        case "t":
            return rig.state.ptt ? "1\n" : "0\n"
        case "T":
            guard let a = args.first else { return rprt(.einval) }
            return rprt(rig.setPTT(a != "0"))

        case "v":
            return "VFOA\n"
        case "V":
            return rprt(.ok)
        case "s":
            return "0\nVFOA\n"
        case "S":
            return rprt((args.first ?? "0") == "0" ? .ok : .enavail)

        default:
            return rprt(.enavail)
        }
    }
}
