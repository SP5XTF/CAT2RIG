import SwiftUI
import AppKit
import CAT2RIGCore

@main
struct CAT2RIGApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = BridgeModel()

    var body: some Scene {
        Window(Text(verbatim: "CAT2RIG"), id: "main") {
            ContentView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .help) {
                HelpMenuButton()
            }
        }

        Window("Pomoc CAT2RIG", id: "help") {
            HelpView()
        }
        .defaultSize(width: 640, height: 720)

        Settings {
            SettingsView()
        }
    }
}

/// Wersja z Info.plist (w .app) – przy `swift run` jej nie ma.
var appVersionString: String {
    let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    return "CAT2RIG " + (v ?? "dev")
}

struct HelpMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL
    var body: some View {
        Button("Pomoc CAT2RIG") { openWindow(id: "help") }
            .keyboardShortcut("?", modifiers: .command)
        Divider()
        Button("Wiki CAT2RIG") {
            openURL(LanguageSettings.effective == "en" ? ProjectLinks.wiki : ProjectLinks.wikiPL)
        }
        Button("Sprawdź nowe wersje…") { openURL(ProjectLinks.releases) }
        Button("Zgłoś problem…") { openURL(ProjectLinks.newIssue) }
        Button("Strona projektu na GitHubie") { openURL(ProjectLinks.repository) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // potrzebne, gdy program jest uruchomiony jako goły plik (swift run), a nie .app
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Model

struct LogLine: Identifiable {
    let id = UUID()
    let text: String
}

@MainActor
final class BridgeModel: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var ports: [String] = []
    /// Dane USB portów (nazwa urządzenia, numer seryjny) – do listy i rozpoznawania po restarcie.
    @Published var portInfos: [String: SerialPortInfo] = [:]
    /// Trwa zamykanie portów w tle (przycisk Start zablokowany).
    @Published var stopping = false

    func portLabel(_ path: String) -> String {
        portInfos[path]?.label ?? path
    }

    /// Odświeża listę portów razem z danymi USB.
    private func loadPorts() -> [SerialPortInfo] {
        let infos = SerialPort.portInfos()
        ports = infos.map(\.path)
        portInfos = Dictionary(infos.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
        return infos
    }

    /// Zapisany port (ścieżka + identyfikator USB) -> aktualna ścieżka; loguje zmianę nazwy.
    private func resolveSavedPort(pathKey: String, idKey: String, infos: [SerialPortInfo]) -> String? {
        guard let path = defaults.string(forKey: pathKey), !path.isEmpty else { return nil }
        let resolved = PortResolver.resolve(path: path, identity: defaults.string(forKey: idKey),
                                            available: infos)
        if let r = resolved, r != path {
            appendLog(L("Interfejs ma nową nazwę portu: %@ → %@", path, r))
        }
        return resolved
    }
    @Published var selectedPort: String
    /// Wybrany model radia; zmiana ustawia domyślne parametry portu i PTT.
    @Published var modelID: String {
        didSet { if modelID != oldValue { applyModelDefaults() } }
    }
    /// "native" = sterowniki CAT2RIG, "hamlib" = biblioteka Hamlib (wszystkie modele).
    @Published var driver: String {
        didSet {
            if driver == "hamlib" && hamlibModel == 0 && radioModel.hamlibID != 0 {
                hamlibModel = radioModel.hamlibID
            }
        }
    }
    /// Numer modelu Hamlib (rigctl -l).
    @Published var hamlibModel: Int
    @Published var baud: Int
    @Published var civAddr: String
    @Published var stopBits: Int
    @Published var rtsCts: Bool
    @Published var pttMethod: PTTMethod
    @Published var pttPort: String          // "" = ten sam co radio
    @Published var tcpPort: String
    @Published var lan: Bool

    @Published var running = false
    @Published var freqText = "---.---.---"
    @Published var modeText = ""
    @Published var statusText = L("Zatrzymany")
    @Published var tx = false
    @Published var scanning = false
    /// S-metr (dB wzgl. S9) i moc (%) – nil, gdy radio/sterownik nie podaje
    @Published var sMeterDB: Int?
    @Published var powerPercent: Int?
    @Published var logLines: [LogLine] = []
    @Published var errorMessage: String?
    @Published var testFreqMHz = "145.500"
    @Published var debugFrames = false {
        didSet { rig?.debugFrames = debugFrames }
    }
    /// Automatyczny start połączenia z radiem po uruchomieniu aplikacji.
    @Published var autoStart: Bool {
        didSet {
            defaults.set(autoStart, forKey: "autoStart")
            if autoStart {
                // zapamiętaj bieżące ustawienia, żeby autostart wiedział, czego użyć
                if !running { saveSettings() }
            } else {
                cancelAutoStart(log: true)
            }
        }
    }

    private var rig: RigBackend?

    var radioModel: RadioModel { RadioModel.find(modelID) ?? .defaultModel }

    var hamlib: HamlibLibrary? { HamlibLibrary.shared }
    var usesHamlib: Bool { driver == "hamlib" && hamlib != nil }
    var hamlibInfo: HamlibModelInfo? { hamlib?.model(hamlibModel) }

    /// Czy pokazać pole adresu CI-V (Icom/Xiegu – także przez Hamlib).
    var showsCIV: Bool {
        if usesHamlib {
            let maker = hamlibInfo?.manufacturer ?? ""
            return maker == "Icom" || maker == "Xiegu"
        }
        return radioModel.usesCIV
    }

    /// Czy proponować PTT przez CAT (przez Hamlib zawsze – Hamlib sam zgłosi brak obsługi).
    var offersCatPTT: Bool { usesHamlib || radioModel.catPTT }

    private func applyModelDefaults() {
        let r = radioModel
        baud = r.defaultBaud
        civAddr = String(format: "%02X", Int(r.civAddress))
        stopBits = r.stopBits
        rtsCts = r.rtsCts
        if r.catPTT {
            pttMethod = .cat
        } else if pttMethod == .cat {
            pttMethod = .off
        }
    }
    private var server: RigctlServer?
    private var timer: Timer?
    private var autoStartTimer: Timer?
    /// Blokada App Nap: bez niej macOS spowalnia program w tle (okno zakryte przez WSJT-X),
    /// przez co komendy z WSJT-X docierają do radia z opóźnieniem.
    private var activity: NSObjectProtocol?
    private var autoStartWaitingFor: String?

    /// Jednorazowe przeniesienie ustawień z poprzedniej nazwy programu (Civ2Rig ≤ 1.2).
    private static func migrateSettingsFromCiv2Rig() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "migratedFromCiv2Rig") else { return }
        d.set(true, forKey: "migratedFromCiv2Rig")
        guard d.object(forKey: "port") == nil,
              let old = d.persistentDomain(forName: "pl.hamradio.civ2rig") else { return }
        for key in ["port", "baud", "civAddr", "ptt", "pttPort", "tcpPort", "lan", "autoStart",
                    "AppleLanguages"] {
            if let v = old[key] { d.set(v, forKey: key) }
        }
    }

    init() {
        Self.migrateSettingsFromCiv2Rig()
        selectedPort = defaults.string(forKey: "port") ?? ""
        let model = RadioModel.find(defaults.string(forKey: "model")) ?? .defaultModel
        modelID = model.id
        baud = defaults.object(forKey: "baud") as? Int ?? model.defaultBaud
        civAddr = defaults.string(forKey: "civAddr") ?? String(format: "%02X", Int(model.civAddress))
        stopBits = defaults.object(forKey: "stopBits") as? Int ?? model.stopBits
        driver = defaults.string(forKey: "driver") ?? "native"
        hamlibModel = defaults.integer(forKey: "hamlibModel")
        rtsCts = defaults.object(forKey: "rtsCts") as? Bool ?? model.rtsCts
        pttMethod = PTTMethod(rawValue: defaults.string(forKey: "ptt") ?? "") ?? .off
        pttPort = defaults.string(forKey: "pttPort") ?? ""
        tcpPort = defaults.string(forKey: "tcpPort") ?? "4532"
        lan = defaults.bool(forKey: "lan")
        autoStart = defaults.bool(forKey: "autoStart")

        refreshPorts()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if autoStart {
            // chwila na zbudowanie okna, potem pierwsza próba
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                Task { @MainActor in self?.attemptAutoStart() }
            }
        }
    }

    // MARK: autostart

    /// Startuje z zapisanymi ustawieniami. Gdy interfejsu nie ma (np. USB jeszcze
    /// niepodłączony), ponawia próbę co 5 s aż do skutku, ręcznego Startu albo wyłączenia opcji.
    private func attemptAutoStart() {
        guard autoStart, !running else {
            cancelAutoStart(log: false)
            return
        }
        guard !stopping else { scheduleAutoStartRetry(); return }
        let infos = loadPorts()

        // zawsze interfejs zapisany przy ostatnim udanym starcie – rozpoznawany po numerze
        // seryjnym USB, nawet jeśli po restarcie dostał inną nazwę; nigdy "pierwszy z listy"
        let savedPort = defaults.string(forKey: "port") ?? ""
        let savedPtt = defaults.string(forKey: "pttPort") ?? ""
        let wantedPort = resolveSavedPort(pathKey: "port", idKey: "portID", infos: infos)
        let needsPtt = (pttMethod == .rts || pttMethod == .dtr) && !savedPtt.isEmpty
        let wantedPtt = needsPtt ? resolveSavedPort(pathKey: "pttPort", idKey: "pttPortID", infos: infos) : ""
        var missing = [String]()
        let dummy = driver == "hamlib" && hamlibModel == 1
        if wantedPort == nil && !dummy { missing.append(savedPort) }
        if needsPtt && wantedPtt == nil { missing.append(savedPtt) }

        if missing.isEmpty {
            selectedPort = wantedPort ?? ""
            pttPort = wantedPtt ?? ""
            if start(interactive: false) {
                cancelAutoStart(log: false)
                return
            }
            statusText = L("Autostart: ponowna próba za 5 s…")
        } else {
            let what = missing.map { $0.isEmpty ? L("(nie wybrano portu)") : $0 }.joined(separator: ", ")
            if autoStartWaitingFor != what {
                autoStartWaitingFor = what
                appendLog(L("Autostart: czekam na port %@", what))
            }
            statusText = L("Autostart: czekam na interfejs…")
        }
        scheduleAutoStartRetry()
    }

    private func scheduleAutoStartRetry() {
        guard autoStartTimer == nil else { return }
        autoStartTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.attemptAutoStart() }
        }
    }

    private func cancelAutoStart(log: Bool) {
        let wasPending = autoStartTimer != nil
        autoStartTimer?.invalidate()
        autoStartTimer = nil
        autoStartWaitingFor = nil
        if wasPending && !running {
            statusText = L("Zatrzymany")
            if log { appendLog(L("Autostart anulowany")) }
        }
    }

    func refreshPorts() {
        let infos = loadPorts()
        // zapisany interfejs mógł dostać nową nazwę (restart, inne gniazdo USB)
        if !ports.contains(selectedPort),
           let r = resolveSavedPort(pathKey: "port", idKey: "portID", infos: infos) {
            selectedPort = r
        }
        if !ports.contains(selectedPort) {
            selectedPort = ports.first ?? ""
        }
        if !pttPort.isEmpty && !ports.contains(pttPort) {
            pttPort = resolveSavedPort(pathKey: "pttPort", idKey: "pttPortID", infos: infos) ?? ""
        }
        if ports.isEmpty {
            appendLog(L("Nie znaleziono portów – podłącz interfejs CI-V i kliknij Odśwież"))
        }
    }

    /// interactive = true: błędy w okienku (przycisk Start); false: tylko w logu (autostart).
    @discardableResult
    func start(interactive: Bool = true) -> Bool {
        if interactive { cancelAutoStart(log: false) }
        func fail(_ msg: String) -> Bool {
            if interactive {
                errorMessage = msg
            } else if autoStartWaitingFor != msg {      // ten sam błąd logujemy tylko raz
                autoStartWaitingFor = msg
                appendLog(L("Autostart: %@ – ponowię za 5 s", msg))
            }
            return false
        }
        if stopping {
            return fail(L("Trwa zatrzymywanie – spróbuj za chwilę."))
        }
        let viaHamlib = driver == "hamlib"
        if viaHamlib && hamlib == nil {
            return fail(L("Biblioteka Hamlib nie jest dostępna."))
        }
        if viaHamlib && hamlibModel <= 0 {
            return fail(L("Wybierz model Hamlib."))
        }
        // model Hamlib „Dummy” (1) to symulator – nie potrzebuje portu
        guard !selectedPort.isEmpty || (viaHamlib && hamlibModel == 1) else {
            return fail(L("Wybierz port radia."))
        }
        // adres CI-V zawsze szesnastkowo: "58", "0x58" albo "58h"
        let addrText = civAddr.lowercased()
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "h", with: "")
            .trimmingCharacters(in: .whitespaces)
        let model = radioModel
        var addr: UInt8 = 0
        if showsCIV {
            guard let a = UInt8(addrText, radix: 16) else {
                return fail(L("Niepoprawny adres CI-V (np. 58)."))
            }
            addr = a
        }
        if pttMethod == .cat && !offersCatPTT {
            return fail(L("To radio nie obsługuje PTT przez CAT – wybierz RTS, DTR albo brak / VOX."))
        }
        if rtsCts && pttMethod == .rts && (pttPort.isEmpty || pttPort == selectedPort) {
            return fail(L("RTS/CTS i PTT linią RTS na tym samym porcie wykluczają się – wybierz PTT CAT, osobny port PTT albo wyłącz RTS/CTS."))
        }
        guard let tcp = UInt16(tcpPort.trimmingCharacters(in: .whitespaces)), tcp > 0 else {
            return fail(L("Niepoprawny port TCP."))
        }

        let logger: (String) -> Void = { [weak self] msg in
            Task { @MainActor in self?.appendLog(msg) }
        }

        do {
            let r: RigBackend
            if viaHamlib {
                r = try RigFactory.openHamlib(
                    model: hamlibModel, portPath: selectedPort, baud: baud, stopBits: stopBits,
                    rtsCts: rtsCts, civAddress: showsCIV ? addr : nil, pttMethod: pttMethod,
                    pttPortPath: pttPort.isEmpty ? nil : pttPort, log: logger)
            } else {
                r = try RigFactory.open(
                    model: model, portPath: selectedPort, baud: baud, civAddress: addr,
                    stopBits: stopBits, rtsCts: rtsCts, pttMethod: pttMethod,
                    // port PTT otwieramy tylko dla RTS/DTR – inaczej może go używać WSJT-X
                    pttPortPath: pttPort.isEmpty ? nil : pttPort,
                    log: logger)
            }
            do {
                let s = try RigctlServer(rig: r, port: tcp, lan: lan, log: logger)
                s.onFailed = { [weak self] msg in
                    Task { @MainActor in
                        self?.stop()
                        self?.errorMessage = L("Serwer TCP nie wystartował – port %ld zajęty? (może działa flrig albo rigctld)", Int(tcp)) + "\n" + msg
                    }
                }
                s.start()
                r.debugFrames = debugFrames
                rig = r
                server = s
            } catch {
                r.close()
                throw error
            }
        } catch {
            return fail(error.localizedDescription)
        }

        saveSettings()
        if activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
                reason: "CAT2RIG: radio control in real time")
        }
        running = true
        statusText = L("Łączenie z radiem…")
        let civInfo = showsCIV ? ", CI-V \(addrText.uppercased())h" : ""
        let radioName: String
        if viaHamlib, let lib = hamlib {
            radioName = "\(lib.version): \(hamlibInfo?.displayName ?? "?") (#\(hamlibModel))"
        } else {
            radioName = model.displayName
        }
        appendLog("Start: \(radioName), \(selectedPort) @ \(baud) bd\(civInfo) → rigctl "
                  + "\(lan ? "0.0.0.0" : "127.0.0.1"):\(tcp)")
        return true
    }

    private func saveSettings() {
        defaults.set(selectedPort, forKey: "port")
        defaults.set(modelID, forKey: "model")
        // identyfikatory USB – żeby po restarcie znaleźć ten sam interfejs pod nową nazwą
        defaults.set(portInfos[selectedPort]?.identity, forKey: "portID")
        defaults.set(pttPort.isEmpty ? nil : portInfos[pttPort]?.identity, forKey: "pttPortID")
        defaults.set(driver, forKey: "driver")
        defaults.set(hamlibModel, forKey: "hamlibModel")
        defaults.set(baud, forKey: "baud")
        defaults.set(civAddr, forKey: "civAddr")
        defaults.set(stopBits, forKey: "stopBits")
        defaults.set(rtsCts, forKey: "rtsCts")
        defaults.set(pttMethod.rawValue, forKey: "ptt")
        defaults.set(pttPort, forKey: "pttPort")
        defaults.set(tcpPort, forKey: "tcpPort")
        defaults.set(lan, forKey: "lan")
    }

    /// Zatrzymuje serwer i zamyka radio. Zamykanie portów idzie w tle, żeby okno nie
    /// zawisło, gdy radio nie odpowiada. wait = true (zamykanie programu): czeka do 3 s.
    func stop(wait: Bool = false) {
        guard rig != nil || server != nil else { return }
        let r = rig, s = server
        rig = nil
        server = nil
        running = false
        stopping = true
        statusText = L("Zatrzymywanie…")
        freqText = "---.---.---"
        modeText = ""
        tx = false
        sMeterDB = nil
        powerPercent = nil
        scanning = false

        let work: @Sendable () -> Void = {
            s?.stop()
            r?.close()                 // PTT wyłączane przed zamknięciem portu
        }
        if wait {
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async { work(); group.leave() }
            _ = group.wait(timeout: .now() + 3)
            finishStop()
        } else {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                work()
                Task { @MainActor in self?.finishStop() }
            }
        }
    }

    private func finishStop() {
        if let a = activity {
            ProcessInfo.processInfo.endActivity(a)
            activity = nil
        }
        stopping = false
        if !running { statusText = L("Zatrzymany") }
        appendLog(L("Zatrzymano"))
    }

    // MARK: test sterowania bez klienta

    func testSetFreq() {
        guard let rig = rig else { return }
        let txt = testFreqMHz.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let mhz = Double(txt), mhz > 0 else {
            errorMessage = L("Podaj częstotliwość w MHz, np. 145.500")
            return
        }
        let hz = Int((mhz * 1_000_000).rounded())
        appendLog(L("Test: ustawiam %ld Hz…", hz))
        DispatchQueue.global().async { [weak self] in
            let rc = rig.setFreq(hz)
            Task { @MainActor in
                self?.appendLog(rc == .ok ? L("Test: radio przyjęło częstotliwość (ACK)")
                                          : L("Test: błąd %ld – radio odrzuciło lub nie odpowiedziało", rc.rawValue))
            }
        }
    }

    func testPTT(_ on: Bool) {
        guard let rig = rig else { return }
        DispatchQueue.global().async { _ = rig.setPTT(on) }
    }

    private func tick() {
        guard let rig = rig else { return }
        let s = rig.state
        if s.online {
            freqText = Self.formatFreq(s.freq)
            modeText = s.mode
            statusText = L("Radio połączone")
        } else {
            statusText = L("Brak odpowiedzi radia…")
        }
        tx = s.ptt
        sMeterDB = s.online ? s.sMeterDB : nil
        powerPercent = s.online ? s.powerPercent : nil
        if s.scanning != scanning {
            scanning = s.scanning
            appendLog(scanning ? L("SCAN: szybkie zmiany częstotliwości (radio skanuje)")
                               : L("SCAN: częstotliwość ustabilizowana"))
        }
    }

    func appendLog(_ msg: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        logLines.append(LogLine(text: "\(f.string(from: Date()))  \(msg)"))
        if logLines.count > 300 { logLines.removeFirst(logLines.count - 300) }
    }

    static func formatFreq(_ hz: Int) -> String {
        String(format: "%d.%03d.%03d", hz / 1_000_000, (hz / 1000) % 1000, hz % 1000)
    }
}

// MARK: - Widok

struct ContentView: View {
    @EnvironmentObject var m: BridgeModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Radio") {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        Text("Sterownik:")
                        HStack {
                            Picker("", selection: $m.driver) {
                                Text("Wbudowany").tag("native")
                                Text(verbatim: m.hamlib?.version ?? "Hamlib").tag("hamlib")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 260)
                            .disabled(m.hamlib == nil)
                            .help("Wbudowany: sterowniki CAT2RIG (41 modeli). Hamlib: wszystkie radia obsługiwane przez bibliotekę Hamlib.")
                            if m.hamlib == nil {
                                Text("Hamlib niedostępny").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    GridRow {
                        Text("Model:")
                        HStack {
                            if m.usesHamlib, let lib = m.hamlib {
                                HamlibModelMenu(library: lib, selection: $m.hamlibModel)
                                    .frame(width: 260)
                            } else {
                            Picker("", selection: $m.modelID) {
                                ForEach(RadioModel.manufacturers, id: \.self) { maker in
                                    Section(maker) {
                                        ForEach(RadioModel.all.filter { $0.manufacturer == maker }) { r in
                                            Text(r.verified ? r.displayName + "  ✓" : r.displayName).tag(r.id)
                                        }
                                    }
                                }
                            }
                            .labelsHidden()
                            .frame(width: 260)
                            .help("✓ = sprawdzone na prawdziwym radiu; pozostałe modele przetestowano na symulatorach protokołów")
                            }
                            if m.showsCIV {
                                Text("Adres CI-V:")
                                TextField("58", text: $m.civAddr)
                                    .frame(width: 44)
                                Text("hex").foregroundStyle(.secondary)
                            }
                        }
                    }
                    GridRow {
                        Text("Port radia:")
                        HStack {
                            Picker("", selection: $m.selectedPort) {
                                if m.ports.isEmpty { Text("brak portów").tag("") }
                                ForEach(m.ports, id: \.self) { Text(verbatim: m.portLabel($0)).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 260)
                            Button("Odśwież") { m.refreshPorts() }
                                .fixedSize()
                        }
                    }
                    GridRow {
                        Text("Prędkość:")
                        HStack {
                            Picker("", selection: $m.baud) {
                                ForEach([1200, 4800, 9600, 19200, 38400, 57600, 115200], id: \.self) {
                                    Text(verbatim: "\($0)").tag($0)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)
                            Text("Bity stopu:")
                            Picker("", selection: $m.stopBits) {
                                Text(verbatim: "1").tag(1)
                                Text(verbatim: "2").tag(2)
                            }
                            .labelsHidden()
                            .frame(width: 50)
                            Toggle(isOn: $m.rtsCts) { Text(verbatim: "RTS/CTS") }
                                .help("Sprzętowa kontrola przepływu – dla Yaesu z włączonym „CAT RTS” w menu radia")
                        }
                    }
                    GridRow {
                        Text("PTT:")
                        HStack {
                            Picker("", selection: $m.pttMethod) {
                                Text("brak / VOX").tag(PTTMethod.off)
                                if m.offersCatPTT {
                                    Text(verbatim: "CAT").tag(PTTMethod.cat)
                                }
                                Text("RTS").tag(PTTMethod.rts)
                                Text("DTR").tag(PTTMethod.dtr)
                            }
                            .labelsHidden()
                            .frame(width: 120)
                            Text("Port PTT:")
                            Picker("", selection: $m.pttPort) {
                                Text("ten sam co radio").tag("")
                                ForEach(m.ports, id: \.self) { Text(verbatim: m.portLabel($0)).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 220)
                            .disabled(m.pttMethod == .off || m.pttMethod == .cat)
                        }
                    }
                }
                .padding(6)
            }
            .disabled(m.running)

            GroupBox("Serwer Hamlib NET rigctl") {
                HStack {
                    Text("Port TCP:")
                    TextField("4532", text: $m.tcpPort)
                        .frame(width: 60)
                    Toggle("dostęp z sieci lokalnej", isOn: $m.lan)
                    Spacer()
                }
                .padding(6)
            }
            .disabled(m.running)

            HStack {
                Button(m.running ? LocalizedStringKey("Stop") : LocalizedStringKey("Start")) {
                    if m.running { m.stop() } else { m.start() }
                }
                .keyboardShortcut(.defaultAction)
                .frame(width: 80)
                .disabled(m.stopping)
                Text(m.statusText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Toggle("Start automatycznie", isOn: $m.autoStart)
                    .toggleStyle(.checkbox)
                    .help("Po uruchomieniu aplikacji połącz się z radiem z ostatnimi ustawieniami. Gdy interfejs nie jest podłączony, próba co 5 s.")
                Toggle("Pokaż ramki CAT", isOn: $m.debugFrames)
                    .toggleStyle(.checkbox)
                    .help("Loguje surowe bajty wysyłane do radia (TX) i odbierane (RX)")
            }

            GroupBox("Test sterowania (bez klienta)") {
                HStack {
                    TextField("MHz", text: $m.testFreqMHz)
                        .frame(width: 90)
                    Text("MHz")
                    Button("Ustaw częstotliwość") { m.testSetFreq() }
                    Spacer()
                    Button(m.tx ? LocalizedStringKey("PTT: wyłącz") : LocalizedStringKey("PTT: nadawaj")) { m.testPTT(!m.tx) }
                        .help("Uwaga: radio naprawdę przejdzie na nadawanie – podłącz antenę lub sztuczne obciążenie")
                }
                .padding(6)
            }
            .disabled(!m.running)

            HStack(alignment: .firstTextBaseline) {
                Text(m.freqText)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                Text(m.modeText)
                    .font(.system(size: 18, design: .monospaced))
                Spacer()
                Text(verbatim: "SCAN")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(m.scanning ? Color.orange : Color.gray.opacity(0.2))
                    .foregroundColor(m.scanning ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .help("Zapala się przy szybkich zmianach częstotliwości, np. gdy radio skanuje (SCAN) albo przy szybkim kręceniu gałką")
                Text("TX")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(m.tx ? Color.red : Color.gray.opacity(0.2))
                    .foregroundColor(m.tx ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            MeterRow(tx: m.tx, sMeterDB: m.sMeterDB, powerPercent: m.powerPercent, running: m.running)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(m.logLines) { line in
                            Text(line.text)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }
                .frame(height: 140)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3)))
                .onChange(of: m.logLines.count) { _ in
                    if let last = m.logLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            HStack {
                Text(appVersionString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Link(destination: LanguageSettings.effective == "en" ? ProjectLinks.wiki : ProjectLinks.wikiPL) {
                    Label("Wiki", systemImage: "book")
                }
                .font(.callout)
                Button {
                    openWindow(id: "help")
                } label: {
                    Label("Pomoc", systemImage: "questionmark.circle")
                }
            }
        }
        .padding(16)
        .frame(width: 580)
        .alert("Błąd", isPresented: Binding(
            get: { m.errorMessage != nil },
            set: { if !$0 { m.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(m.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            m.stop(wait: true)
        }
    }
}


/// Wybór modelu Hamlib: menu z podmenu dla każdego producenta (ponad 300 radiów).
struct HamlibModelMenu: View {
    let library: HamlibLibrary
    @Binding var selection: Int

    var body: some View {
        Menu {
            ForEach(library.manufacturers, id: \.self) { maker in
                Menu(maker) {
                    ForEach(library.models.filter { $0.manufacturer == maker }) { info in
                        Button {
                            selection = info.id
                        } label: {
                            Text(verbatim: info.status == 3
                                 ? "\(info.name)  #\(info.id)"
                                 : "\(info.name)  #\(info.id)  (\(info.statusName))")
                        }
                    }
                }
            }
        } label: {
            if let info = library.model(selection) {
                Text(verbatim: "\(info.displayName)  #\(info.id)")
            } else {
                Text("Wybierz model…")
            }
        }
    }
}


// MARK: - Mierniki

/// Wskaźnik jak w radiu: S-metr podczas odbioru, moc podczas nadawania.
struct MeterRow: View {
    let tx: Bool
    let sMeterDB: Int?
    let powerPercent: Int?
    let running: Bool

    private static let sTicks: [(Double, String)] = [
        (-48, "1"), (-36, "3"), (-24, "5"), (-12, "7"), (0, "9"), (20, "+20"), (40, "+40"), (60, "+60"),
    ].map { (Meters.sFraction(Int($0.0)), $0.1) }
    private static let powerTicks: [(Double, String)] = [
        (0, "0"), (0.25, "25"), (0.5, "50"), (0.75, "75"), (1.0, "100%"),
    ]

    var body: some View {
        if tx {
            MeterBar(title: "PO",
                     fraction: powerPercent.map { Double($0) / 100 },
                     text: powerPercent.map { "\($0) %" } ?? "—",
                     color: .red, ticks: Self.powerTicks)
                .help("Moc wyjściowa w procentach mocy maksymalnej (gdy radio ją podaje)")
        } else {
            MeterBar(title: "S",
                     fraction: sMeterDB.map(Meters.sFraction),
                     text: sMeterDB.map(Meters.sText) ?? (running ? "—" : ""),
                     color: sMeterDB.map { $0 > 0 ? Color.orange : Color.green } ?? .green,
                     ticks: Self.sTicks)
                .help("S-metr odczytany z radia (gdy radio go podaje)")
        }
    }
}

struct MeterBar: View {
    let title: String
    let fraction: Double?
    let text: String
    let color: Color
    let ticks: [(Double, String)]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(verbatim: title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(width: 26, alignment: .leading)
            VStack(spacing: 1) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.18))
                        RoundedRectangle(cornerRadius: 3).fill(color)
                            .frame(width: max(0, g.size.width * CGFloat(min(1, fraction ?? 0))))
                    }
                }
                .frame(height: 10)
                GeometryReader { g in
                    ForEach(ticks.indices, id: \.self) { i in
                        Text(verbatim: ticks[i].1)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .position(x: g.size.width * CGFloat(ticks[i].0), y: 6)
                    }
                }
                .frame(height: 12)
            }
            Text(verbatim: text)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(width: 70, alignment: .trailing)
        }
        .animation(.linear(duration: 0.2), value: fraction)
    }
}
