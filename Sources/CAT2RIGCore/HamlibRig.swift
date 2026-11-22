import Foundation

/// Transport-atrapa: HamlibRig nie używa naszego portu szeregowego – port otwiera Hamlib.
final class NullTransport: SerialTransport {
    func read(into buf: inout [UInt8]) -> Int { Thread.sleep(forTimeInterval: 0.05); return 0 }
    func write(_ bytes: [UInt8]) -> Bool { true }
    func setRTS(_ on: Bool) {}
    func setDTR(_ on: Bool) {}
    func close() {}
}

/// Sterownik korzystający z biblioteki Hamlib – obsługuje każdy model z `rigctl -l`.
/// Odpytywanie, pierwszeństwo komend klientów, SCAN i log są wspólne z naszymi sterownikami
/// (PolledSerialRig); wszystkie wywołania Hamlib idą pod blokadą transakcji (withIO).
final class HamlibRig: PolledSerialRig, @unchecked Sendable {
    private let lib: HamlibLibrary
    private let rig: OpaquePointer
    let hamlibModel: Int
    private let hasSMeter: Bool
    private let hasPowerMeter: Bool

    /// Konfiguruje i otwiera radio przez Hamlib. Rzuca błąd z komunikatem Hamlib.
    static func open(library lib: HamlibLibrary, model: Int, portPath: String, baud: Int,
                     stopBits: Int, rtsCts: Bool, civAddress: UInt8?, pttMethod: PTTMethod,
                     pttPortPath: String?, pollInterval: TimeInterval = 0.5,
                     log: @escaping (String) -> Void) throws -> HamlibRig {
        guard model > 0, let rig = lib.rigInit(UInt32(model)) else {
            throw SerialError.open(L("Hamlib nie zna modelu %ld", model))
        }
        func conf(_ name: String, _ value: String) {
            let token = lib.rigTokenLookup(rig, name)
            guard token != 0 else { return }                 // parametr nieznany dla tego modelu
            _ = lib.rigSetConf(rig, token, value)
        }
        if !portPath.isEmpty { conf("rig_pathname", portPath) }
        conf("serial_speed", String(baud))
        conf("stop_bits", String(stopBits))
        conf("serial_handshake", rtsCts ? "Hardware" : "None")
        switch pttMethod {
        case .cat: conf("ptt_type", "RIG")
        case .rts: conf("ptt_type", "RTS")
        case .dtr: conf("ptt_type", "DTR")
        case .off: conf("ptt_type", "None")
        }
        if pttMethod == .rts || pttMethod == .dtr, let p = pttPortPath, !p.isEmpty {
            conf("ptt_pathname", p)
        }
        if let addr = civAddress {
            conf("civaddr", String(Int(addr)))                // dziesiętnie – Hamlib używa atoi
        }

        let rc = lib.rigOpen(rig)
        guard rc == 0 else {
            let msg = lib.errorText(rc)
            _ = lib.rigCleanup(rig)
            throw SerialError.open("Hamlib: \(msg)")
        }
        return HamlibRig(library: lib, rig: rig, model: model, pttMethod: pttMethod,
                         pollInterval: pollInterval, log: log)
    }

    private init(library: HamlibLibrary, rig: OpaquePointer, model: Int, pttMethod: PTTMethod,
                 pollInterval: TimeInterval, log: @escaping (String) -> Void) {
        self.lib = library
        self.rig = rig
        self.hamlibModel = model
        self.hasSMeter = library.rigHasGetLevel(rig, HamlibLibrary.levelStrength) != 0
        self.hasPowerMeter = library.rigHasGetLevel(rig, HamlibLibrary.levelPowerMeter) != 0
        super.init(transport: NullTransport(), pttTransport: nil, pollInterval: pollInterval,
                   responseTimeout: 1.0, pttMethod: pttMethod, textProtocol: false, log: log)
    }

    private func map(_ rc: Int32) -> HamlibErr {
        rc == 0 ? .ok : (HamlibErr(rawValue: Int(rc)) ?? .etimeout)
    }

    // MARK: PolledSerialRig

    override var debugFrames: Bool {
        get { super.debugFrames }
        set {
            super.debugFrames = newValue
            lib.globalLock.lock()
            lib.rigSetDebug(newValue ? HamlibLibrary.debugTrace : HamlibLibrary.debugErr)
            lib.globalLock.unlock()
            if newValue {
                log(L("Szczegółowy log Hamlib: %@", HamlibLibrary.logURL.path))
            }
        }
    }

    override func pollOnce() {
        var f: Double = 0
        if lib.rigGetFreq(rig, HamlibLibrary.vfoCurrent, &f) == 0, f > 0 {
            updateFreq(Int(f.rounded()))
        }
        var mode: UInt64 = 0
        var width: Int = 0
        if lib.rigGetMode(rig, HamlibLibrary.vfoCurrent, &mode, &width) == 0, mode != 0,
           let name = lib.rigStrRMode(mode) {
            updateMode(String(cString: name), width: width)
        }
        if isTransmitting {
            if hasPowerMeter, let v: Float = level(HamlibLibrary.levelPowerMeter) {
                updatePower(Int((v * 100).rounded()))
            }
        } else if hasSMeter, let v: Int32 = level(HamlibLibrary.levelStrength) {
            updateSMeter(Int(v))
        }
    }

    /// rig_get_level: value_t to 16-bajtowa unia – czytamy z niej Int32 albo Float.
    private func level<T>(_ which: UInt64) -> T? {
        var buf: (UInt64, UInt64) = (0, 0)
        let rc = withUnsafeMutableBytes(of: &buf) {
            lib.rigGetLevel(rig, HamlibLibrary.vfoCurrent, which, $0.baseAddress)
        }
        guard rc == 0 else { return nil }
        return withUnsafeBytes(of: &buf) { $0.load(as: T.self) }
    }

    override func doSetFreq(_ hz: Int) -> HamlibErr {
        let rc = lib.rigSetFreq(rig, HamlibLibrary.vfoCurrent, Double(hz))
        if rc == 0 { updateFreq(hz) }
        return map(rc)
    }

    override func doSetMode(_ name: String) -> HamlibErr {
        let mode = name.withCString { lib.rigParseMode($0) }
        guard mode != 0 else { return .einval }
        let rc = lib.rigSetMode(rig, HamlibLibrary.vfoCurrent, mode, HamlibLibrary.passbandNoChange)
        if rc == 0 { updateMode(name) }
        return map(rc)
    }

    /// PTT zawsze przez Hamlib – on sam kluczuje komendą CAT albo linią RTS/DTR (ptt_type).
    override func setPTT(_ on: Bool) -> HamlibErr {
        if pttMethod != .off {
            let rc = withIO(client: true) { lib.rigSetPTT(rig, HamlibLibrary.vfoCurrent, on ? 1 : 0) }
            guard rc == 0 else {
                log("PTT \(on ? "ON" : "OFF") (hamlib): \(lib.errorText(rc))")
                return map(rc)
            }
        }
        recordPTT(on)
        log("PTT \(on ? "ON" : "OFF") (hamlib, \(pttMethod.rawValue))")
        return .ok
    }

    override func close() {
        super.close()
        _ = lib.rigClose(rig)
        _ = lib.rigCleanup(rig)
        lib.globalLock.lock()
        lib.rigSetDebug(HamlibLibrary.debugErr)
        lib.globalLock.unlock()
    }
}

extension RigFactory {
    /// Sterownik Hamlib dla dowolnego modelu z `rigctl -l`. nil w `library` = Hamlib niedostępny.
    public static func openHamlib(model: Int, portPath: String, baud: Int, stopBits: Int,
                                  rtsCts: Bool, civAddress: UInt8?, pttMethod: PTTMethod,
                                  pttPortPath: String?, pollInterval: TimeInterval = 0.5,
                                  log: @escaping (String) -> Void) throws -> RigBackend {
        guard let lib = HamlibLibrary.shared else {
            throw SerialError.open(L("Biblioteka Hamlib nie jest dostępna."))
        }
        return try HamlibRig.open(library: lib, model: model, portPath: portPath, baud: baud,
                                  stopBits: stopBits, rtsCts: rtsCts, civAddress: civAddress,
                                  pttMethod: pttMethod, pttPortPath: pttPortPath,
                                  pollInterval: pollInterval, log: log)
    }
}
