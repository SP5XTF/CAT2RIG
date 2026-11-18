import Foundation
import Darwin

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

        // z powrotem tryb blokujący; czas oczekiwania ustala VTIME
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)

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
            cc[Int(VTIME)] = 1          // read() wraca najpóźniej po 0,1 s
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

    public func read(into buf: inout [UInt8]) -> Int {
        guard fd >= 0 else { return -1 }
        let f = fd
        return buf.withUnsafeMutableBytes { Darwin.read(f, $0.baseAddress, $0.count) }
    }

    public func write(_ bytes: [UInt8]) -> Bool {
        guard fd >= 0 else { return false }
        let f = fd
        let n = bytes.withUnsafeBytes { Darwin.write(f, $0.baseAddress, $0.count) }
        return n == bytes.count
    }

    public func close() {
        if fd >= 0 {
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
