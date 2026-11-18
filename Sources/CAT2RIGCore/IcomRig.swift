import Foundation

public enum CIV {
    static let trxFreq: UInt8 = 0x00   // transceive: radio -> adres 00
    static let trxMode: UInt8 = 0x01
    static let readFreq: UInt8 = 0x03
    static let readMode: UInt8 = 0x04
    static let setFreq: UInt8 = 0x05
    static let setMode: UInt8 = 0x06
    static let selectVFO: UInt8 = 0x07       // bez danych: przejście z trybu pamięci do VFO
    static let selectMemory: UInt8 = 0x08
    static let dataMode: UInt8 = 0x1A       // 1A 06 = tryb DATA (USB-D…)
    static let ptt: UInt8 = 0x1C            // 1C 00 = PTT (nie w IC-706)
    static let ack: UInt8 = 0xFB
    static let nak: UInt8 = 0xFA
    static let collision: UInt8 = 0xFC

    static let modes: [UInt8: String] = [
        0x00: "LSB", 0x01: "USB", 0x02: "AM", 0x03: "CW",
        0x04: "RTTY", 0x05: "FM", 0x06: "WFM",
    ]
    static let hamlibToCiv: [String: UInt8] = [
        "LSB": 0x00, "USB": 0x01, "AM": 0x02, "CW": 0x03, "RTTY": 0x04, "FM": 0x05, "WFM": 0x06,
        // emisje Hamlib, których 706 nie ma – najbliższe odpowiedniki
        "PKTUSB": 0x01, "PKTLSB": 0x00, "PKTFM": 0x05, "CWR": 0x03, "RTTYR": 0x04,
    ]
    // przybliżone szerokości – tylko do raportowania klientom
    static let normalWidth: [String: Int] = ["LSB": 2400, "USB": 2400, "AM": 9000, "CW": 2400,
                                             "RTTY": 2400, "FM": 15000, "WFM": 230000]
    static let narrowWidth: [String: Int] = ["LSB": 1800, "USB": 1800, "AM": 2400, "CW": 500,
                                             "RTTY": 500, "FM": 6000, "WFM": 230000]

    /// 14074000 -> 5 bajtów BCD, najmłodsza para cyfr pierwsza.
    public static func freqToBCD(_ hz: Int) -> [UInt8] {
        var v = hz
        var out: [UInt8] = []
        for _ in 0..<5 {
            let lo = v % 10; v /= 10
            let hi = v % 10; v /= 10
            out.append(UInt8(hi << 4 | lo))
        }
        return out
    }

    /// BCD -> Hz. Zwraca nil dla danych, które nie są poprawną częstotliwością
    /// (zła długość, cyfra > 9) – np. ramka uszkodzona przez kolizję na magistrali CI-V
    /// podczas skanowania. Dzięki temu nie ma przepełnienia arytmetycznego.
    public static func bcdToFreq(_ data: [UInt8]) -> Int? {
        guard data.count == 4 || data.count == 5 else { return nil }
        var f = 0, mult = 1
        for b in data {
            let lo = Int(b & 0x0F), hi = Int(b >> 4)
            guard lo <= 9, hi <= 9 else { return nil }
            f += lo * mult; mult *= 10
            f += hi * mult; mult *= 10
        }
        return f
    }
}

/// Radio Icom na CI-V: wątek czytający port + wątek odpytujący radio.
/// Cały stan jest chroniony blokadami (stateLock, xferLock, respCond),
/// więc obiekt można bezpiecznie używać z wielu wątków – stąd @unchecked Sendable.
public final class IcomRig: RigBackend, @unchecked Sendable {
    private let port: SerialTransport
    private let pttPort: SerialTransport?
    private let rigAddr: UInt8
    private let ctlAddr: UInt8 = 0xE0
    private let pollInterval: TimeInterval
    private let responseTimeout: TimeInterval
    private let pttMethod: PTTMethod
    /// Radio ma tryb DATA ustawiany komendą 0x1A 0x06 (IC-7300, IC-705, IC-7100, IC-9700…).
    private let dataModeCommand: Bool
    private var dataMode = false
    private let log: (String) -> Void

    private let stateLock = NSLock()
    private var freq = 0
    private var mode = "USB"
    private var width = 2400
    private var ptt = false
    private var lastSeen = Date.distantPast
    private var freqChangeTimes: [Date] = []
    private var commandedFreq: Int?          // ostatnia częstotliwość zlecona przez klienta
    private var clientWaiting = 0             // komendy klientów czekające na magistralę CI-V

    /// Wykrywanie SCAN: co najmniej `scanMinChanges` zmian częstotliwości z radia
    /// w oknie `scanWindow` sekund. Zmiany zlecone przez klientów (setFreq) się nie liczą.
    public static let scanWindow: TimeInterval = ScanDetection.window
    public static let scanMinChanges = ScanDetection.minChanges
    private var running = true
    private var _debugFrames = false

    /// Diagnostyka: logowanie surowych bajtów RX/TX.
    public var debugFrames: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _debugFrames }
        set { stateLock.lock(); _debugFrames = newValue; stateLock.unlock() }
    }

    private static func hex<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
        bytes.map { String(format: "%02X", Int($0)) }.joined(separator: " ")
    }

    private let xferLock = NSLock()            // jedna transakcja CI-V naraz
    private let respCond = NSCondition()
    private var responses: [(cmd: UInt8, data: [UInt8])] = []

    /// Wersja z dowolnym (już otwartym) transportem – używana też w testach.
    public init(transport: SerialTransport, pttTransport: SerialTransport? = nil,
                rigAddr: UInt8 = 0x58, pollInterval: TimeInterval = 0.5,
                responseTimeout: TimeInterval = 0.5, pttMethod: PTTMethod = .off,
                dataModeCommand: Bool = false,
                log: @escaping (String) -> Void = { _ in }) {
        self.dataModeCommand = dataModeCommand
        self.port = transport
        self.pttPort = pttTransport
        self.rigAddr = rigAddr
        self.pollInterval = pollInterval
        self.responseTimeout = responseTimeout
        self.pttMethod = pttMethod
        self.log = log

        // Wątki I/O z najwyższym priorytetem: główny wątek (UI) czeka na nie przy
        // zamykaniu, a niższy priorytet powodowałby inwersję priorytetów.
        // Zużycie CPU jest znikome – wątki prawie cały czas śpią na read()/sleep.
        let reader = Thread { [weak self] in self?.readerLoop() }
        reader.name = "cat2rig.civ-reader"
        reader.qualityOfService = .userInteractive
        reader.start()

        let poller = Thread { [weak self] in self?.pollerLoop() }
        poller.name = "cat2rig.civ-poller"
        poller.qualityOfService = .userInteractive
        poller.start()
    }

    // MARK: stan

    private var isRunning: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return running
    }

    public var state: RigState {
        stateLock.lock(); defer { stateLock.unlock() }
        let now = Date()
        let online = now.timeIntervalSince(lastSeen) < max(3.0, pollInterval * 3)
        let recentChanges = freqChangeTimes.filter { now.timeIntervalSince($0) <= Self.scanWindow }.count
        let reported = dataMode && ["USB", "LSB", "FM"].contains(mode) ? "PKT" + mode : mode
        return RigState(freq: freq, mode: reported, width: width, ptt: ptt, online: online,
                        scanning: recentChanges >= Self.scanMinChanges)
    }

    // MARK: odbiór

    private func readerLoop() {
        var buf: [UInt8] = []
        var chunk = [UInt8](repeating: 0, count: 64)
        while isRunning {
            let n = port.read(into: &chunk)
            if n < 0 {
                if !isRunning { break }
                if errno == EINTR || errno == EAGAIN { continue }
                log(L("Błąd odczytu portu: %@", String(cString: strerror(errno))))
                Thread.sleep(forTimeInterval: 1)
                continue
            }
            if n == 0 { continue }
            if debugFrames { log("RX  " + Self.hex(chunk[0..<n])) }
            buf.append(contentsOf: chunk[0..<n])

            while true {
                guard let start = Self.findPreamble(buf) else {
                    if buf.count > 1 { buf = [buf[buf.count - 1]] }   // ewentualne pół preambuły
                    break
                }
                guard let end = buf[start...].firstIndex(of: 0xFD) else {
                    if start > 0 { buf.removeFirst(start) }
                    break
                }
                // Ramka bez własnego FD (kolizja) "skleja się" z następną: jeśli między
                // preambułą a FD jest kolejne FE FE, odrzucamy uszkodzony początek.
                var p = start
                while p < end && buf[p] == 0xFE { p += 1 }
                if let inner = Self.findPreamble(Array(buf[p..<end])) {
                    buf.removeFirst(p + inner)
                    continue
                }
                let frame = Array(buf[start...end])
                buf.removeFirst(end + 1)
                handleFrame(frame)
            }
            if buf.count > 512 { buf.removeAll() }   // śmieci bez końca ramki
        }
    }

    private static func findPreamble(_ b: [UInt8]) -> Int? {
        guard b.count >= 2 else { return nil }
        for i in 0..<(b.count - 1) where b[i] == 0xFE && b[i + 1] == 0xFE {
            return i
        }
        return nil
    }

    private func handleFrame(_ frame: [UInt8]) {
        guard frame.count >= 3 else { return }
        var body = Array(frame[2..<(frame.count - 1)])
        while body.first == 0xFE { body.removeFirst() }
        guard body.count >= 3, !body.contains(CIV.collision) else { return }
        let dst = body[0], src = body[1], cmd = body[2]
        let data = Array(body[3...])

        if src == ctlAddr { return }                         // echo naszych ramek
        guard src == rigAddr, dst == ctlAddr || dst == 0x00 else { return }

        updateState(cmd, data)
        if dst == ctlAddr {
            respCond.lock()
            responses.append((cmd, data))
            respCond.signal()
            respCond.unlock()
        }
    }

    private func updateState(_ cmd: UInt8, _ data: [UInt8]) {
        stateLock.lock(); defer { stateLock.unlock() }
        switch cmd {
        case CIV.trxFreq, CIV.readFreq:
            guard let newFreq = CIV.bcdToFreq(data) else { return }   // uszkodzona ramka
            let now = Date()
            // pierwszy odczyt i zmiany zlecone przez klienta to nie SCAN
            if freq != 0 && newFreq != freq && newFreq != commandedFreq {
                freqChangeTimes.append(now)
                freqChangeTimes.removeAll { now.timeIntervalSince($0) > Self.scanWindow }
            }
            freq = newFreq
            lastSeen = now
        case CIV.trxMode, CIV.readMode:
            guard let first = data.first, data.count <= 2 else { return }
            if let m = CIV.modes[first] {
                let filter = data.count > 1 ? data[1] : 2
                mode = m
                width = (filter == 3 ? CIV.narrowWidth[m] : CIV.normalWidth[m]) ?? 2400
            }
            lastSeen = Date()
        case CIV.dataMode:
            // odpowiedź na 1A 06: [06, dane 00–03, filtr]
            if data.count >= 2 && data[0] == 0x06 {
                dataMode = data[1] != 0
                lastSeen = Date()
            }
        case CIV.ack, CIV.nak:
            lastSeen = Date()
        default:
            break
        }
    }

    // MARK: nadawanie ramek

    private func xfer(_ cmd: UInt8, _ data: [UInt8] = [], timeout: TimeInterval? = nil,
                      retries: Int = 2, quiet: Bool = false) -> (HamlibErr, [UInt8]?) {
        let timeout = timeout ?? responseTimeout
        let frame: [UInt8] = [0xFE, 0xFE, rigAddr, ctlAddr, cmd] + data + [0xFD]
        xferLock.lock(); defer { xferLock.unlock() }

        for _ in 0...retries {
            guard isRunning else { return (.etimeout, nil) }
            respCond.lock(); responses.removeAll(); respCond.unlock()
            if debugFrames { log("TX  " + Self.hex(frame)) }
            guard port.write(frame) else { return (.etimeout, nil) }

            let deadline = Date().addingTimeInterval(timeout)
            var result: (HamlibErr, [UInt8]?)? = nil
            respCond.lock()
            while result == nil && isRunning {
                if responses.isEmpty {
                    if !respCond.wait(until: deadline) { break }
                    continue
                }
                let r = responses.removeFirst()
                if r.cmd == CIV.ack { result = (.ok, []) }
                else if r.cmd == CIV.nak { result = (.erjcted, nil) }
                else if r.cmd == cmd { result = (.ok, r.data) }
            }
            respCond.unlock()
            if let r = result { return r }
        }
        if !quiet {
            log(L("Brak odpowiedzi radia na komendę 0x%02X", Int(cmd)))
        }
        return (.etimeout, nil)
    }

    private func pollerLoop() {
        var wasOnline: Bool? = nil
        while isRunning {
            // Komendy klientów (WSJT-X) mają pierwszeństwo – odpytywanie czeka.
            pollUnlessClientWaiting(CIV.readFreq)
            pollUnlessClientWaiting(CIV.readMode)
            if dataModeCommand {
                pollUnlessClientWaiting(CIV.dataMode, [0x06])
            }
            let s = state
            if s.online != wasOnline && isRunning {
                wasOnline = s.online
                log(s.online ? L("Radio odpowiada: %ld Hz %@", s.freq, s.mode)
                             : L("Radio nie odpowiada – sprawdź kabel, prędkość i adres CI-V"))
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }

    private var isClientWaiting: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return clientWaiting > 0
    }

    private func pollUnlessClientWaiting(_ cmd: UInt8, _ data: [UInt8] = []) {
        while isRunning && isClientWaiting {
            Thread.sleep(forTimeInterval: 0.01)
        }
        guard isRunning else { return }
        _ = xfer(cmd, data, retries: 0, quiet: true)
    }

    /// Transakcja zlecona przez klienta – zgłasza oczekiwanie, żeby odpytywanie ustąpiło.
    private func clientXfer(_ cmd: UInt8, _ data: [UInt8] = [], timeout: TimeInterval? = nil,
                            retries: Int = 2, quiet: Bool = false) -> (HamlibErr, [UInt8]?) {
        stateLock.lock(); clientWaiting += 1; stateLock.unlock()
        defer { stateLock.lock(); clientWaiting -= 1; stateLock.unlock() }
        return xfer(cmd, data, timeout: timeout, retries: retries, quiet: quiet)
    }

    // MARK: API dla serwera rigctl

    public func setFreq(_ hz: Int) -> HamlibErr {
        guard hz > 0, hz < 10_000_000_000 else { return .einval }
        // W trybie pamięci (V/M = MEMO) radio nie przyjmie nowej częstotliwości –
        // najpierw przełączamy na VFO. Gdy radio już jest w VFO, komenda nic nie zmienia.
        _ = selectVFOMode()
        stateLock.lock(); commandedFreq = hz; stateLock.unlock()
        let (rc, _) = clientXfer(CIV.setFreq, CIV.freqToBCD(hz))
        if rc == .ok {
            stateLock.lock(); freq = hz; stateLock.unlock()
        }
        return rc
    }

    /// Przełącza radio z trybu pamięci na VFO (CI-V 0x07 bez danych).
    @discardableResult
    public func selectVFOMode() -> HamlibErr {
        // radio odpowiada w kilkadziesiąt ms – krótki timeout, żeby nie opóźniać zmiany częstotliwości
        clientXfer(CIV.selectVFO, timeout: 0.2, retries: 0, quiet: true).0
    }

    public func setMode(_ name: String) -> HamlibErr {
        let upper = name.uppercased()
        guard let code = CIV.hamlibToCiv[upper], let m = CIV.modes[code] else {
            return .einval
        }
        let (rc, _) = clientXfer(CIV.setMode, [code])
        guard rc == .ok else { return rc }
        stateLock.lock(); mode = m; width = CIV.normalWidth[m] ?? 2400; stateLock.unlock()

        if dataModeCommand {
            // PKTUSB/PKTLSB/PKTFM = tryb DATA (USB-D…), pozostałe emisje – DATA wyłączone
            let data = upper.hasPrefix("PKT")
            let (drc, _) = clientXfer(CIV.dataMode, [0x06, data ? 0x01 : 0x00, data ? 0x01 : 0x00])
            if drc == .ok {
                stateLock.lock(); dataMode = data; stateLock.unlock()
            }
        }
        return .ok
    }

    /// PTT: przez CI-V (komenda 1C 00 – nowsze Icomy i Xiegu) albo linią RTS/DTR interfejsu.
    /// IC-706MKIIG nie ma PTT przez CI-V.
    public func setPTT(_ on: Bool) -> HamlibErr {
        let p = pttPort ?? port
        switch pttMethod {
        case .rts: p.setRTS(on)
        case .dtr: p.setDTR(on)
        case .cat:
            let (rc, _) = clientXfer(CIV.ptt, [0x00, on ? 0x01 : 0x00])
            guard rc == .ok else {
                log("PTT \(on ? "ON" : "OFF") (cat): RPRT \(rc.rawValue)")
                return rc
            }
        case .off: break
        }
        stateLock.lock(); ptt = on; stateLock.unlock()
        log("PTT \(on ? "ON" : "OFF") (\(pttMethod.rawValue))")
        return .ok
    }

    public func close() {
        if state.ptt { _ = setPTT(false) }
        stateLock.lock(); running = false; stateLock.unlock()
        respCond.lock(); respCond.broadcast(); respCond.unlock()
        xferLock.lock(); xferLock.unlock()          // poczekaj na trwającą transakcję
        Thread.sleep(forTimeInterval: 0.15)         // wątek czytający kończy się po VTIME
        port.close()
        pttPort?.close()
    }
}
