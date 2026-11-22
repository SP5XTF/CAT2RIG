import Foundation
import Darwin

/// Model z biblioteki Hamlib (`rigctl -l`).
public struct HamlibModelInfo: Identifiable, Hashable {
    public let id: Int              // numer modelu Hamlib
    public let manufacturer: String
    public let name: String
    /// 0 alpha, 1 untested, 2 beta, 3 stable, 4 buggy
    public let status: Int

    public var displayName: String { "\(manufacturer) \(name)" }
    public var statusName: String {
        ["Alpha", "Untested", "Beta", "Stable", "Buggy"][min(max(status, 0), 4)]
    }
}

/// Biblioteka Hamlib wczytywana w czasie działania (dlopen). Szuka kolejno:
/// 1. zmiennej środowiskowej CAT2RIG_HAMLIB (pełna ścieżka – testy, eksperymenty),
/// 2. Contents/Frameworks/libhamlib.4.dylib w pakiecie aplikacji (dołączona do CAT2RIG),
/// 3. vendor/hamlib/lib w katalogu projektu (uruchamianie z Xcode),
/// 4. Homebrew (/opt/homebrew/lib, /usr/local/lib).
/// Gdy nie znajdzie – `shared` jest nil, a CAT2RIG działa na własnych sterownikach.
///
/// Typy argumentów zgodne z Hamlib 4.x (rig.h): rig_model_t = uint32, vfo_t = unsigned int,
/// freq_t = double, rmode_t = uint64, pbwidth_t = long, hamlib_token_t = long, ptt_t = int.
public final class HamlibLibrary: @unchecked Sendable {

    // MARK: stałe z rig.h
    static let vfoCurrent: UInt32 = 1 << 29            // RIG_VFO_CURR
    static let passbandNoChange: Int = -1              // RIG_PASSBAND_NOCHANGE
    static let debugNone: Int32 = 0, debugErr: Int32 = 2, debugTrace: Int32 = 5
    static let levelStrength: UInt64 = 1 << 30          // RIG_LEVEL_STRENGTH (int, dB wzgl. S9)
    static let levelPowerMeter: UInt64 = 1 << 32        // RIG_LEVEL_RFPOWER_METER (float 0…1)
    /// Modele, których nie pokazujemy: NET rigctl (2) – połączenie samego ze sobą.
    static let hiddenModels: Set<Int> = [2]

    // MARK: funkcje
    typealias RigPtr = OpaquePointer
    typealias ListCallback = @convention(c) (UnsafeRawPointer?, UnsafeMutableRawPointer?) -> Int32

    let rigInit: @convention(c) (UInt32) -> RigPtr?
    let rigOpen: @convention(c) (RigPtr?) -> Int32
    let rigClose: @convention(c) (RigPtr?) -> Int32
    let rigCleanup: @convention(c) (RigPtr?) -> Int32
    let rigTokenLookup: @convention(c) (RigPtr?, UnsafePointer<CChar>?) -> Int
    let rigSetConf: @convention(c) (RigPtr?, Int, UnsafePointer<CChar>?) -> Int32
    let rigSetFreq: @convention(c) (RigPtr?, UInt32, Double) -> Int32
    let rigGetFreq: @convention(c) (RigPtr?, UInt32, UnsafeMutablePointer<Double>?) -> Int32
    let rigSetMode: @convention(c) (RigPtr?, UInt32, UInt64, Int) -> Int32
    let rigGetMode: @convention(c) (RigPtr?, UInt32, UnsafeMutablePointer<UInt64>?,
                                    UnsafeMutablePointer<Int>?) -> Int32
    let rigSetPTT: @convention(c) (RigPtr?, UInt32, Int32) -> Int32
    let rigParseMode: @convention(c) (UnsafePointer<CChar>?) -> UInt64
    let rigStrRMode: @convention(c) (UInt64) -> UnsafePointer<CChar>?
    let rigSetDebug: @convention(c) (Int32) -> Void
    let rigSetDebugFile: @convention(c) (UnsafeMutablePointer<FILE>?) -> UnsafeMutablePointer<FILE>?
    let rigLoadAllBackends: @convention(c) () -> Int32
    let rigListForeach: @convention(c) (ListCallback?, UnsafeMutableRawPointer?) -> Int32
    let rigError: @convention(c) (Int32) -> UnsafePointer<CChar>?
    /// value_t to unia 16-bajtowa – przekazujemy wskaźnik na bufor
    let rigGetLevel: @convention(c) (RigPtr?, UInt32, UInt64, UnsafeMutableRawPointer?) -> Int32
    let rigHasGetLevel: @convention(c) (RigPtr?, UInt64) -> UInt64

    public let path: String
    /// np. "Hamlib 4.7.2"
    public let version: String

    private let handle: UnsafeMutableRawPointer
    /// Hamlib nie jest bezpieczny wielowątkowo na poziomie globalnym (lista modeli, debug).
    let globalLock = NSLock()

    // MARK: wczytywanie

    public static let shared: HamlibLibrary? = {
        for path in candidatePaths() {
            if let lib = HamlibLibrary(path: path) { return lib }
        }
        return nil
    }()

    static func candidatePaths() -> [String] {
        var paths: [String] = []
        if let env = ProcessInfo.processInfo.environment["CAT2RIG_HAMLIB"], !env.isEmpty {
            paths.append(env)
        }
        if let fw = Bundle.main.privateFrameworksURL {
            paths.append(fw.appendingPathComponent("libhamlib.4.dylib").path)
        }
        // uruchamianie z Xcode / swift run: vendor/hamlib w katalogu projektu
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        paths.append(projectRoot.appendingPathComponent("vendor/hamlib/lib/libhamlib.4.dylib").path)
        paths += ["/opt/homebrew/lib/libhamlib.4.dylib", "/usr/local/lib/libhamlib.4.dylib",
                  "/opt/homebrew/lib/libhamlib.dylib", "/usr/local/lib/libhamlib.dylib"]
        return paths
    }

    init?(path: String) {
        guard FileManager.default.fileExists(atPath: path),
              let h = dlopen(path, RTLD_NOW | RTLD_LOCAL) else { return nil }

        func sym<T>(_ name: String, _ type: T.Type) -> T? {
            guard let p = dlsym(h, name) else { return nil }
            return unsafeBitCast(p, to: type)
        }

        guard
            let rigInit = sym("rig_init", (@convention(c) (UInt32) -> RigPtr?).self),
            let rigOpen = sym("rig_open", (@convention(c) (RigPtr?) -> Int32).self),
            let rigClose = sym("rig_close", (@convention(c) (RigPtr?) -> Int32).self),
            let rigCleanup = sym("rig_cleanup", (@convention(c) (RigPtr?) -> Int32).self),
            let rigTokenLookup = sym("rig_token_lookup",
                                     (@convention(c) (RigPtr?, UnsafePointer<CChar>?) -> Int).self),
            let rigSetConf = sym("rig_set_conf",
                                 (@convention(c) (RigPtr?, Int, UnsafePointer<CChar>?) -> Int32).self),
            let rigSetFreq = sym("rig_set_freq", (@convention(c) (RigPtr?, UInt32, Double) -> Int32).self),
            let rigGetFreq = sym("rig_get_freq",
                                 (@convention(c) (RigPtr?, UInt32, UnsafeMutablePointer<Double>?) -> Int32).self),
            let rigSetMode = sym("rig_set_mode",
                                 (@convention(c) (RigPtr?, UInt32, UInt64, Int) -> Int32).self),
            let rigGetMode = sym("rig_get_mode",
                                 (@convention(c) (RigPtr?, UInt32, UnsafeMutablePointer<UInt64>?,
                                                  UnsafeMutablePointer<Int>?) -> Int32).self),
            let rigSetPTT = sym("rig_set_ptt", (@convention(c) (RigPtr?, UInt32, Int32) -> Int32).self),
            let rigParseMode = sym("rig_parse_mode", (@convention(c) (UnsafePointer<CChar>?) -> UInt64).self),
            let rigStrRMode = sym("rig_strrmode", (@convention(c) (UInt64) -> UnsafePointer<CChar>?).self),
            let rigSetDebug = sym("rig_set_debug", (@convention(c) (Int32) -> Void).self),
            let rigSetDebugFile = sym("rig_set_debug_file",
                                      (@convention(c) (UnsafeMutablePointer<FILE>?)
                                       -> UnsafeMutablePointer<FILE>?).self),
            let rigLoadAllBackends = sym("rig_load_all_backends", (@convention(c) () -> Int32).self),
            let rigListForeach = sym("rig_list_foreach",
                                     (@convention(c) (ListCallback?, UnsafeMutableRawPointer?) -> Int32).self),
            let rigError = sym("rigerror", (@convention(c) (Int32) -> UnsafePointer<CChar>?).self),
            let rigGetLevel = sym("rig_get_level",
                                  (@convention(c) (RigPtr?, UInt32, UInt64, UnsafeMutableRawPointer?)
                                   -> Int32).self),
            let rigHasGetLevel = sym("rig_has_get_level", (@convention(c) (RigPtr?, UInt64) -> UInt64).self)
        else {
            dlclose(h)
            return nil
        }

        self.handle = h
        self.path = path
        self.rigInit = rigInit
        self.rigOpen = rigOpen
        self.rigClose = rigClose
        self.rigCleanup = rigCleanup
        self.rigTokenLookup = rigTokenLookup
        self.rigSetConf = rigSetConf
        self.rigSetFreq = rigSetFreq
        self.rigGetFreq = rigGetFreq
        self.rigSetMode = rigSetMode
        self.rigGetMode = rigGetMode
        self.rigSetPTT = rigSetPTT
        self.rigParseMode = rigParseMode
        self.rigStrRMode = rigStrRMode
        self.rigSetDebug = rigSetDebug
        self.rigSetDebugFile = rigSetDebugFile
        self.rigLoadAllBackends = rigLoadAllBackends
        self.rigListForeach = rigListForeach
        self.rigError = rigError
        self.rigGetLevel = rigGetLevel
        self.rigHasGetLevel = rigHasGetLevel

        // `const char hamlib_version[]` – adres symbolu to sam tekst
        if let v = dlsym(h, "hamlib_version") {
            self.version = String(cString: v.assumingMemoryBound(to: CChar.self))
        } else {
            self.version = "Hamlib"
        }

        // Komunikaty Hamlib idą do pliku ~/Library/Logs/CAT2RIG/hamlib.log (domyślnie tylko
        // błędy, ze „Pokaż ramki CAT” – pełny ślad). Funkcji zwrotnej z va_list nie da się
        // zadeklarować w Swifcie (CVaListPointer nie jest dozwolony w @convention(c)).
        if let file = Self.openLogFile() {
            _ = rigSetDebugFile(file)
        }
        rigSetDebug(Self.debugErr)
        _ = rigLoadAllBackends()
    }

    // MARK: lista modeli

    /// Wszystkie modele Hamlib, posortowane wg producenta i nazwy.
    /// Plik z logiem Hamlib (do zgłoszeń błędów).
    public static let logURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/CAT2RIG/hamlib.log")

    private static func openLogFile() -> UnsafeMutablePointer<FILE>? {
        let dir = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // nie pozwalamy plikowi rosnąć bez końca
        if let size = (try? FileManager.default.attributesOfItem(atPath: logURL.path))?[.size] as? Int,
           size > 5_000_000 {
            try? FileManager.default.removeItem(at: logURL)
        }
        guard let fp = fopen(logURL.path, "a") else { return nil }
        setlinebuf(fp)
        return fp
    }

    public lazy var models: [HamlibModelInfo] = {
        self.globalLock.lock(); defer { self.globalLock.unlock() }
        let box = HamlibModelBox()
        let ctx = Unmanaged.passUnretained(box).toOpaque()
        // struct rig_caps zaczyna się od: rig_model_t rig_model (u32), const char *model_name,
        // const char *mfg_name, const char *version, const char *copyright, enum status –
        // stały początek struktury we wszystkich wersjach 4.x (offsety 0, 8, 16, 24, 32, 40).
        _ = self.rigListForeach({ caps, data in
            guard let caps = caps, let data = data else { return 1 }
            let box = Unmanaged<HamlibModelBox>.fromOpaque(data).takeUnretainedValue()
            let model = Int(caps.load(as: UInt32.self))
            let namePtr = caps.load(fromByteOffset: 8, as: UnsafePointer<CChar>?.self)
            let mfgPtr = caps.load(fromByteOffset: 16, as: UnsafePointer<CChar>?.self)
            let status = Int(caps.load(fromByteOffset: 40, as: Int32.self))
            if let n = namePtr, let m = mfgPtr {
                box.items.append(HamlibModelInfo(id: model, manufacturer: String(cString: m),
                                                 name: String(cString: n), status: status))
            }
            return 1                                  // !=0: kontynuuj
        }, ctx)
        return box.items
            .filter { !Self.hiddenModels.contains($0.id) }
            .sorted { ($0.manufacturer.lowercased(), $0.name.lowercased(), $0.id)
                    < ($1.manufacturer.lowercased(), $1.name.lowercased(), $1.id) }
    }()

    public var manufacturers: [String] {
        var seen = [String]()
        for m in models where !seen.contains(m.manufacturer) { seen.append(m.manufacturer) }
        return seen
    }

    public func model(_ id: Int) -> HamlibModelInfo? {
        models.first { $0.id == id }
    }

    /// Ostatnia linia komunikatu błędu Hamlib (rigerror zwraca też ślad debugowania).
    func errorText(_ code: Int32) -> String {
        guard let p = rigError(code) else { return "RPRT \(code)" }
        let lines = String(cString: p).split(whereSeparator: \.isNewline)
        return lines.last.map(String.init) ?? "RPRT \(code)"
    }
}

/// Pojemnik na wyniki rig_list_foreach (przekazywany do funkcji C jako wskaźnik).
private final class HamlibModelBox {
    var items: [HamlibModelInfo] = []
}
