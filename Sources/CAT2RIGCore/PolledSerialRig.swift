import Foundation

/// Wspólna część sterowników „pytanie–odpowiedź” (Yaesu, Kenwood/Elecraft, FT-817):
/// wątek odpytujący radio, pierwszeństwo komend klientów, stan, wykrywanie SCAN,
/// PTT liniami RTS/DTR i log. Podklasy implementują tylko sam protokół.
class PolledSerialRig: RigBackend, @unchecked Sendable {
    let port: SerialTransport
    let pttPort: SerialTransport?
    let pttMethod: PTTMethod
    let pollInterval: TimeInterval
    let responseTimeout: TimeInterval
    let log: (String) -> Void
    /// true: log RX/TX jako tekst (protokoły tekstowe), false: szesnastkowo.
    let textProtocol: Bool

    private let lock = NSLock()               // stan
    private let ioLock = NSLock()             // jedna transakcja z radiem naraz
    private var running = true
    private var clientWaiting = 0
    private var _debugFrames = false

    private var freq = 0
    private var mode = "USB"
    private var width = 2400
    private var ptt = false
    private var lastSeen = Date.distantPast
    private var changeTimes: [Date] = []
    private var commandedFreq: Int?
    private var sMeter: Int?
    private var power: Int?

    /// Bajty odebrane, a jeszcze nieprzetworzone (dostęp tylko pod ioLock).
    var pending: [UInt8] = []

    init(transport: SerialTransport, pttTransport: SerialTransport?, pollInterval: TimeInterval,
         responseTimeout: TimeInterval, pttMethod: PTTMethod, textProtocol: Bool,
         log: @escaping (String) -> Void) {
        self.port = transport
        self.pttPort = pttTransport
        self.pollInterval = pollInterval
        self.responseTimeout = responseTimeout
        self.pttMethod = pttMethod
        self.textProtocol = textProtocol
        self.log = log

        let poller = Thread { [weak self] in self?.pollerLoop() }
        poller.name = "cat2rig.cat-poller"
        poller.qualityOfService = .userInteractive
        poller.start()
    }

    // MARK: do nadpisania w podklasach (wywoływane pod ioLock)

    /// Jednorazowo przed pierwszym odpytaniem (np. wyłączenie Auto Information).
    func prepare() {}
    /// Odczyt częstotliwości i emisji – woła updateFreq/updateMode.
    func pollOnce() {}
    func doSetFreq(_ hz: Int) -> HamlibErr { .enavail }
    func doSetMode(_ name: String) -> HamlibErr { .enavail }
    func doCatPTT(_ on: Bool) -> HamlibErr { .enavail }

    // MARK: stan

    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return running
    }

    var debugFrames: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _debugFrames }
        set { lock.lock(); _debugFrames = newValue; lock.unlock() }
    }

    var state: RigState {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        let online = now.timeIntervalSince(lastSeen) < max(3.0, pollInterval * 3)
        let recent = changeTimes.filter { now.timeIntervalSince($0) <= ScanDetection.window }.count
        return RigState(freq: freq, mode: mode, width: width, ptt: ptt, online: online,
                        scanning: recent >= ScanDetection.minChanges,
                        sMeterDB: ptt ? nil : sMeter, powerPercent: ptt ? power : nil)
    }

    func updateFreq(_ f: Int) {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        // pierwszy odczyt i zmiany zlecone przez klienta to nie SCAN
        if freq != 0 && f != freq && f != commandedFreq {
            changeTimes.append(now)
            changeTimes.removeAll { now.timeIntervalSince($0) > ScanDetection.window }
        }
        freq = f
        lastSeen = now
    }

    func updateMode(_ m: String, narrow: Bool = false, width w: Int? = nil) {
        lock.lock(); defer { lock.unlock() }
        mode = m
        if let w = w, w > 0 {
            width = w
        } else {
            width = ModeWidths.width(for: m, narrow: narrow)
        }
        lastSeen = Date()
    }

    /// Odczyty mierników z podklas (nil = brak odczytu).
    func updateSMeter(_ db: Int?) {
        lock.lock(); sMeter = db; lock.unlock()
    }

    func updatePower(_ percent: Int?) {
        lock.lock(); power = percent.map { max(0, min(100, $0)) }; lock.unlock()
    }

    /// Czy radio nadaje (do wyboru, który miernik odpytywać).
    var isTransmitting: Bool {
        lock.lock(); defer { lock.unlock() }
        return ptt
    }

    /// Zapamiętuje stan PTT (dla podklas, które same obsługują setPTT).
    func recordPTT(_ on: Bool) {
        lock.lock(); ptt = on; lock.unlock()
    }

    func markCommanded(_ hz: Int) {
        lock.lock(); commandedFreq = hz; lock.unlock()
    }

    // MARK: wejście/wyjście (wywoływać pod ioLock – w pollOnce/doSet…)

    func send(_ bytes: [UInt8]) -> Bool {
        if debugFrames { log("TX  " + describe(bytes)) }
        return port.write(bytes)
    }

    func send(_ text: String) -> Bool {
        send(Array(text.utf8))
    }

    /// Doczytuje dane z portu (czeka najwyżej ok. 0,1 s).
    func readChunk() {
        var chunk = [UInt8](repeating: 0, count: 128)
        let n = port.read(into: &chunk)
        guard n > 0 else { return }
        if debugFrames { log("RX  " + describe(Array(chunk[0..<n]))) }
        pending.append(contentsOf: chunk[0..<n])
        if pending.count > 2048 { pending.removeFirst(pending.count - 2048) }
    }

    /// Protokoły tekstowe: następna odpowiedź zaczynająca się od `prefix` (bez średnika).
    /// Inne komunikaty (np. Auto Information) i „?;” (radio odrzuciło wcześniejszą komendę)
    /// są pomijane. nil: brak odpowiedzi w czasie.
    func readText(prefix: String, timeout: TimeInterval? = nil) -> String? {
        let deadline = Date().addingTimeInterval(timeout ?? responseTimeout)
        while true {
            while let semi = pending.firstIndex(of: 0x3B) {          // ';'
                let token = String(decoding: pending[..<semi], as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                pending.removeSubrange(...semi)
                if token.hasPrefix(prefix) { return token }
            }
            if Date() >= deadline || !isRunning { return nil }
            readChunk()
        }
    }

    /// Protokoły binarne: dokładnie `count` bajtów albo nil po czasie.
    func readBytes(count: Int, timeout: TimeInterval? = nil) -> [UInt8]? {
        let deadline = Date().addingTimeInterval(timeout ?? responseTimeout)
        while pending.count < count {
            if Date() >= deadline || !isRunning { return nil }
            readChunk()
        }
        let r = Array(pending.prefix(count))
        pending.removeFirst(count)
        return r
    }

    private func describe(_ bytes: [UInt8]) -> String {
        if textProtocol, bytes.allSatisfy({ $0 >= 0x20 && $0 < 0x7F }) {
            return String(decoding: bytes, as: UTF8.self)
        }
        return bytes.map { String(format: "%02X", Int($0)) }.joined(separator: " ")
    }

    // MARK: wątek odpytujący

    private var isClientWaiting: Bool {
        lock.lock(); defer { lock.unlock() }
        return clientWaiting > 0
    }

    /// Transakcja z radiem. client = true: komenda klienta, ma pierwszeństwo przed odpytywaniem.
    func withIO<T>(client: Bool, _ body: () -> T) -> T {
        if client { lock.lock(); clientWaiting += 1; lock.unlock() }
        defer { if client { lock.lock(); clientWaiting -= 1; lock.unlock() } }
        ioLock.lock(); defer { ioLock.unlock() }
        return body()
    }

    private func pollerLoop() {
        withIO(client: false) { prepare() }
        var wasOnline: Bool? = nil
        while isRunning {
            while isRunning && isClientWaiting {
                Thread.sleep(forTimeInterval: 0.01)
            }
            guard isRunning else { break }
            withIO(client: false) { pollOnce() }
            let s = state
            if s.online != wasOnline && isRunning {
                wasOnline = s.online
                log(s.online ? L("Radio odpowiada: %ld Hz %@", s.freq, s.mode)
                             : L("Radio nie odpowiada – sprawdź kabel, prędkość i ustawienia CAT"))
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }

    // MARK: RigBackend

    func setFreq(_ hz: Int) -> HamlibErr {
        guard hz > 0, hz < 10_000_000_000 else { return .einval }
        markCommanded(hz)
        return withIO(client: true) { doSetFreq(hz) }
    }

    func setMode(_ name: String) -> HamlibErr {
        withIO(client: true) { doSetMode(name.uppercased()) }
    }

    func setPTT(_ on: Bool) -> HamlibErr {
        let p = pttPort ?? port
        switch pttMethod {
        case .rts: p.setRTS(on)
        case .dtr: p.setDTR(on)
        case .cat:
            let rc = withIO(client: true) { doCatPTT(on) }
            guard rc == .ok else {
                log("PTT \(on ? "ON" : "OFF") (cat): RPRT \(rc.rawValue)")
                return rc
            }
        case .off: break
        }
        lock.lock(); ptt = on; lock.unlock()
        log("PTT \(on ? "ON" : "OFF") (\(pttMethod.rawValue))")
        return .ok
    }

    func close() {
        if state.ptt { _ = setPTT(false) }
        lock.lock(); running = false; lock.unlock()
        ioLock.lock(); ioLock.unlock()             // poczekaj na trwającą transakcję
        Thread.sleep(forTimeInterval: 0.15)
        port.close()
        pttPort?.close()
    }
}
