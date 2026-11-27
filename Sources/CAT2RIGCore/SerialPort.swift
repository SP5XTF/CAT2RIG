import Foundation
import Darwin
import IOKit
import IOKit.serial

/// Abstrakcja portu szeregowego – pozwala podmienić prawdziwy port na atrapę w testach.
public protocol SerialTransport: AnyObject {
    /// Zwraca liczbę bajtów, 0 przy braku danych (timeout ok. 0,1 s), -1 przy błędzie.
    func read(into buf: inout [UInt8]) -> Int
    func write(_ bytes: [UInt8]) -> Bool
    func setRTS(_ on: Bool)
    func setDTR(_ on: Bool)
    func close()
}

public enum SerialError: LocalizedError {
    case open(String)
    case config(String)

    public var errorDescription: String? {
        switch self {
        case .open(let s): return L("Nie mogę otworzyć portu: %@", s)
        case .config(let s): return L("Błąd konfiguracji portu: %@", s)
        }
    }
}

/// Prosty port szeregowy na termios (8N1, bez kontroli przepływu).
public final class SerialPort: SerialTransport {
    public let path: String
    private var fd: Int32 = -1

    // Makra _IO/_IOW z <sys/ioctl.h> nie są importowane do Swifta – wartości wyliczone ręcznie.
    private static let ioctlTIOCEXCL: UInt = 0x2000_740D   // _IO('t', 13)
    private static let ioctlTIOCMBIS: UInt = 0x8004_746C   // _IOW('t', 108, int)
    private static let ioctlTIOCMBIC: UInt = 0x8004_746B   // _IOW('t', 107, int)

    public init(path: String) {
        self.path = path
    }

    public var isOpen: Bool { fd >= 0 }

    /// exclusive = true: drugi program nie otworzy portu (dla portu CI-V).
    /// exclusive = false: port może być równocześnie otwarty przez inny program
    /// (dla portu PTT, który Hamlib/WSJT-X też otwiera).
    /// stopBits: 1 albo 2 (starsze Yaesu: 2). rtsCts: sprzętowa kontrola przepływu
    /// (nowsze Yaesu z włączonym „CAT RTS” w menu radia).
    public func open(baud: Int, stopBits: Int = 1, rtsCts: Bool = false, exclusive: Bool = true) throws {
        let f = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard f >= 0 else { throw SerialError.open("\(path): \(Self.lastError())") }
        fd = f

        // wyłączny dostęp – drugi program (flrig, rigctld) nie otworzy portu
        if exclusive && ioctl(fd, Self.ioctlTIOCEXCL) == -1 {
            let e = Self.lastError()
            close()
            throw SerialError.open(L("%@ zajęty? %@", path, e))
        }

        let flags = fcntl(fd, F_GETFL)
        // Port zostaje w trybie nieblokującym: odczyt i zapis czekają przez poll() z limitem czasu.
        // W trybie blokującym write() potrafił zawisnąć na zawsze, gdy urządzenie nie odbiera
        // danych (złe radio/port, brak CTS) – a z nim Stop i zamykanie programu.
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var t = termios()
        guard tcgetattr(fd, &t) == 0 else {
            let e = Self.lastError(); close(); throw SerialError.config(e)
        }
        cfmakeraw(&t)
        t.c_cflag |= tcflag_t(CLOCAL | CREAD)
        t.c_cflag &= ~tcflag_t(CSTOPB | CCTS_OFLOW | CRTS_IFLOW)
        if stopBits == 2 { t.c_cflag |= tcflag_t(CSTOPB) }
        if rtsCts { t.c_cflag |= tcflag_t(CCTS_OFLOW | CRTS_IFLOW) }
        withUnsafeMutableBytes(of: &t.c_cc) { cc in
            cc[Int(VMIN)] = 0
            cc[Int(VTIME)] = 1          // (port nieblokujący – czas czekania ustala poll())
        }
        cfsetspeed(&t, speed_t(baud))
        guard tcsetattr(fd, TCSANOW, &t) == 0 else {
            let e = Self.lastError(); close(); throw SerialError.config(L("prędkość %ld: %@", baud, e))
        }
        tcflush(fd, TCIOFLUSH)

        // macOS podnosi RTS/DTR przy otwarciu – opuszczamy, żeby nie kluczować nadajnika
        if !rtsCts { setRTS(false) }      // przy RTS/CTS linią RTS steruje sterownik portu
        setDTR(false)
    }

    public func setRTS(_ on: Bool) { setModemBit(TIOCM_RTS, on) }
    public func setDTR(_ on: Bool) { setModemBit(TIOCM_DTR, on) }

    private func setModemBit(_ bit: Int32, _ on: Bool) {
        guard fd >= 0 else { return }
        var b = bit
        let req = on ? Self.ioctlTIOCMBIS : Self.ioctlTIOCMBIC
        _ = withUnsafeMutablePointer(to: &b) { ioctl(fd, req, UnsafeMutableRawPointer($0)) }
    }

    /// Czeka na dane najwyżej 0,1 s. Zwraca liczbę bajtów, 0 (brak danych) albo -1 (błąd).
    public func read(into buf: inout [UInt8]) -> Int {
        guard fd >= 0 else { return -1 }
        let f = fd
        var pfd = pollfd(fd: f, events: Int16(POLLIN), revents: 0)
        let r = Darwin.poll(&pfd, 1, 100)
        if r == 0 { return 0 }
        if r < 0 { return errno == EINTR ? 0 : -1 }
        let n = buf.withUnsafeMutableBytes { Darwin.read(f, $0.baseAddress, $0.count) }
        if n < 0 && (errno == EAGAIN || errno == EINTR) { return 0 }
        return n
    }

    /// Zapis z limitem czasu (1 s). Gdy urządzenie nie przyjmuje danych, kasuje bufor wyjściowy
    /// i zwraca false zamiast blokować wątek.
    public func write(_ bytes: [UInt8]) -> Bool {
        guard fd >= 0 else { return false }
        let f = fd
        let deadline = Date().addingTimeInterval(1.0)
        var offset = 0
        while offset < bytes.count {
            let n = bytes.withUnsafeBytes { raw -> Int in
                Darwin.write(f, raw.baseAddress! + offset, raw.count - offset)
            }
            if n > 0 {
                offset += n
                continue
            }
            if n < 0 && errno != EAGAIN && errno != EINTR { return false }
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                tcflush(f, TCOFLUSH)
                return false
            }
            var pfd = pollfd(fd: f, events: Int16(POLLOUT), revents: 0)
            _ = Darwin.poll(&pfd, 1, Int32(max(1, remaining * 1000)))
        }
        return true
    }

    public func close() {
        if fd >= 0 {
            // bez opróżnienia buforów close() potrafi czekać na wysłanie zaległych danych
            tcflush(fd, TCIOFLUSH)
            Darwin.close(fd)
            fd = -1
        }
    }

    deinit { close() }

    private static func lastError() -> String {
        String(cString: strerror(errno))
    }

    /// Porty /dev/cu.* (na macOS nie używamy /dev/tty.*), USB na początku listy.
    public static func availablePorts() -> [String] {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
        return items
            .filter { $0.hasPrefix("cu.") && !$0.contains("Bluetooth-Incoming") }
            .map { "/dev/" + $0 }
            .sorted { a, b in
                let ua = a.lowercased().contains("usb"), ub = b.lowercased().contains("usb")
                return ua != ub ? ua : a < b
            }
    }
}

// MARK: - Rozpoznawanie interfejsu USB niezależnie od nazwy portu


/// Port szeregowy z danymi urządzenia USB. Nazwy /dev/cu.* potrafią się zmienić po restarcie
/// albo po podłączeniu do innego gniazda USB – identyfikator (VID:PID:numer seryjny:interfejs)
/// pozwala znaleźć ten sam interfejs pod nową nazwą.
public struct SerialPortInfo: Hashable {
    public let path: String
    public let product: String?
    public let vendorID: Int?
    public let productID: Int?
    public let serialNumber: String?
    /// Numer interfejsu – rozróżnia porty jednego urządzenia (np. dwa porty FT-710, CP2105).
    public let interface: Int?

    public init(path: String, product: String? = nil, vendorID: Int? = nil, productID: Int? = nil,
                serialNumber: String? = nil, interface: Int? = nil) {
        self.path = path
        self.product = product
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.interface = interface
    }

    /// Stały identyfikator urządzenia; nil dla portów bez danych USB (np. Bluetooth).
    public var identity: String? {
        guard let v = vendorID, let p = productID else { return nil }
        return String(format: "%04X:%04X", v, p) + ":" + (serialNumber ?? "")
            + ":" + (interface.map(String.init) ?? "")
    }

    /// Tekst do listy portów: "/dev/cu.usbserial-1420 – USB Serial (A1B2C3)".
    public var label: String {
        var extra = [String]()
        if let p = product, !p.isEmpty { extra.append(p) }
        if let s = serialNumber, !s.isEmpty { extra.append("(\(s))") }
        return extra.isEmpty ? path : path + "  –  " + extra.joined(separator: " ")
    }
}

public enum PortResolver {
    /// Który port otworzyć. Gdy znamy identyfikator interfejsu: zapisana ścieżka, jeśli nadal
    /// wskazuje to samo urządzenie, w przeciwnym razie port o tym identyfikatorze pod nową nazwą;
    /// nil, gdy urządzenia nie ma (nie otwieramy innego urządzenia o starej nazwie).
    /// Bez identyfikatora – zapisana ścieżka, o ile istnieje.
    public static func resolve(path: String, identity: String?,
                               available: [SerialPortInfo]) -> String? {
        if let id = identity, !id.isEmpty {
            if let same = available.first(where: { $0.path == path }), same.identity == id {
                return path
            }
            let matches = available.filter { $0.identity == id }
            return matches.first?.path
        }
        return available.contains { $0.path == path } ? path : nil
    }
}

extension SerialPort {
    /// Porty /dev/cu.* z danymi USB z rejestru IOKit (kolejność jak w availablePorts()).
    public static func portInfos() -> [SerialPortInfo] {
        var byPath: [String: SerialPortInfo] = [:]
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(kIOSerialBSDServiceValue),
                                        &iterator) == KERN_SUCCESS {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                if let info = info(for: service) { byPath[info.path] = info }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
        return availablePorts().map { byPath[$0] ?? SerialPortInfo(path: $0) }
    }

    private static func info(for service: io_object_t) -> SerialPortInfo? {
        guard let path = IORegistryEntryCreateCFProperty(service, kIOCalloutDeviceKey as CFString,
                                                         kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String else { return nil }
        // właściwości urządzenia USB są u „rodziców” portu w rejestrze IOKit
        func prop(_ key: String) -> Any? {
            IORegistryEntrySearchCFProperty(service, kIOServicePlane, key as CFString, kCFAllocatorDefault,
                                            IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents))
        }
        func int(_ key: String) -> Int? { (prop(key) as? NSNumber)?.intValue }
        func str(_ keys: String...) -> String? {
            for k in keys { if let s = prop(k) as? String, !s.isEmpty { return s } }
            return nil
        }
        return SerialPortInfo(path: path,
                              product: str("USB Product Name", "kUSBProductString"),
                              vendorID: int("idVendor"),
                              productID: int("idProduct"),
                              serialNumber: str("USB Serial Number", "kUSBSerialNumberString"),
                              interface: int("bInterfaceNumber"))
    }
}
