import Foundation
import Network

/// Serwer TCP zgodny z rigctld.
public final class RigctlServer: @unchecked Sendable {
    private let listener: NWListener
    private let rig: RigBackend
    private let log: (String) -> Void
    private let tcpPort: UInt16
    private let queue = DispatchQueue(label: "cat2rig.listener", qos: .userInteractive)
    private var clients: [RigctlClient] = []     // dostęp tylko na `queue`
    public var onFailed: ((String) -> Void)?
    /// Wywoływane, gdy serwer zacznie nasłuchiwać; argument = faktyczny port TCP.
    public var onReady: ((UInt16) -> Void)?

    /// Faktyczny port nasłuchu (przydatne przy porcie 0 = dowolny wolny).
    public var listeningPort: UInt16? { listener.port?.rawValue }

    /// port 0 = system wybierze wolny port (używane w testach).
    public init(rig: RigBackend, port: UInt16, lan: Bool, log: @escaping (String) -> Void = { _ in }) throws {
        // TCP_NODELAY: krótkie odpowiedzi rigctl idą od razu (bez algorytmu Nagle'a)
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.allowLocalEndpointReuse = true
        if !lan {
            params.requiredInterfaceType = .loopback   // tylko 127.0.0.1
        }
        let p: NWEndpoint.Port = port == 0 ? .any : (NWEndpoint.Port(rawValue: port) ?? .any)
        self.listener = try NWListener(using: params, on: p)
        self.rig = rig
        self.log = log
        self.tcpPort = port
    }

    public func start() {
        let port = tcpPort
        listener.stateUpdateHandler = { [weak self] st in
            switch st {
            case .ready:
                let actual = self?.listener.port?.rawValue ?? port
                self?.log(L("Serwer rigctl nasłuchuje na porcie %ld", Int(actual)))
                self?.onReady?(actual)
            case .waiting(let err):
                self?.log(L("Serwer rigctl czeka (port %ld niedostępny?): %@", Int(port), "\(err)"))
            case .failed(let err):
                self?.log(L("Serwer rigctl: błąd %@", "\(err)"))
                self?.onFailed?("\(err)")
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] conn in
            self?.accept(conn)
        }
        listener.start(queue: queue)
    }

    private func accept(_ conn: NWConnection) {
        let client = RigctlClient(connection: conn, rig: rig, log: log) { [weak self] c in
            self?.queue.async { self?.clients.removeAll { $0 === c } }
        }
        clients.append(client)
        client.start()
    }

    public func stop() {
        listener.cancel()
        queue.sync {
            clients.forEach { $0.cancel() }
            clients.removeAll()
        }
    }
}

/// Jedno połączenie klienta – komendy linia po linii, każda z odpowiedzią.
final class RigctlClient {
    private let conn: NWConnection
    private let rig: RigBackend
    private let log: (String) -> Void
    private let onClose: (RigctlClient) -> Void
    private let queue = DispatchQueue(label: "cat2rig.client", qos: .userInteractive)
    private var buffer = Data()
    private var closed = false
    private let peer: String

    init(connection: NWConnection, rig: RigBackend, log: @escaping (String) -> Void,
         onClose: @escaping (RigctlClient) -> Void) {
        self.conn = connection
        self.rig = rig
        self.log = log
        self.onClose = onClose
        self.peer = "\(connection.endpoint)"
    }

    func start() {
        conn.stateUpdateHandler = { [weak self] st in
            guard let self = self else { return }
            switch st {
            case .ready:
                self.log(L("Klient połączony: %@", self.peer))
            case .failed, .cancelled:
                self.finish()
            default:
                break
            }
        }
        conn.start(queue: queue)
        receive()
    }

    func cancel() {
        conn.cancel()
    }

    private func receive() {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                self.buffer.append(data)
                self.processLines()
            }
            if isComplete || error != nil {
                self.conn.cancel()
                return
            }
            if !self.closed { self.receive() }
        }
    }

    private func processLines() {
        while let nl = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            let line = String(decoding: lineData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            let t0 = Date()
            let result = RigctlProtocol.dispatch(rig, line)
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            if ms >= 300 {
                log(L("Wolna odpowiedź radia: %@ – %ld ms", line, ms))
            }
            guard let resp = result else {
                if rig.debugFrames { log("rigctl < \(line)  " + L("(koniec sesji)")) }
                conn.cancel()
                return
            }
            if !rig.debugFrames && resp.hasPrefix("RPRT") {
                // komendy ustawiające i błędy zawsze widoczne w logu
                let note = resp.hasPrefix("RPRT -11") ? "  " + L("(nieobsługiwana komenda)") : ""
                log("rigctl < \(line)   > \(resp.trimmingCharacters(in: .whitespacesAndNewlines))\(note)")
            }
            if rig.debugFrames {
                let shown = line.contains("dump_state") ? "<dump_state>"
                    : resp.trimmingCharacters(in: .whitespacesAndNewlines)
                          .replacingOccurrences(of: "\n", with: " | ")
                log("rigctl < \(line)   > \(shown)")
            }
            conn.send(content: Data(resp.utf8), completion: .contentProcessed { _ in })
        }
    }

    private func finish() {
        if closed { return }
        closed = true
        log(L("Klient rozłączony: %@", peer))
        onClose(self)
    }
}
