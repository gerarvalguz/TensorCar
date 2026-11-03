import Foundation
import Network

enum OBDError: LocalizedError {
    case noData, noVehicle, timeout, closed, badReply(String)

    var errorDescription: String? {
        switch self {
        case .noData: "El auto no reporta ese dato"
        case .noVehicle: "El adaptador no logra hablar con el auto. ¿Está el contacto puesto?"
        case .timeout: "El adaptador no responde. ¿Está el iPhone en la red WiFi del adaptador?"
        case .closed: "Se cerró la conexión con el adaptador"
        case .badReply(let r): "Respuesta inesperada del adaptador: \(r)"
        }
    }
}

protocol Transport: AnyObject {
    func connect() async throws
    /// Sends one command and returns everything the adapter answers up to its `>` prompt.
    func send(_ command: String, timeout: TimeInterval) async throws -> String
    func close()
}

/// Raw TCP to a WiFi ELM327 (most clones: 192.168.0.10:35000).
final class TCPTransport: Transport {
    private let conn: NWConnection
    private let q = DispatchQueue(label: "obd.tcp")

    init(host: String, port: UInt16) {
        conn = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? 35000, using: .tcp)
    }

    func connect() async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            var done = false
            conn.stateUpdateHandler = { [conn] state in
                guard !done else { return }
                switch state {
                case .ready: done = true; c.resume()
                // .waiting is what iOS reports for "unreachable" and "local network permission denied"
                case .failed(let e), .waiting(let e): done = true; conn.cancel(); c.resume(throwing: e)
                default: break
                }
            }
            q.asyncAfter(deadline: .now() + 10) { [conn] in
                guard !done else { return }
                done = true; conn.cancel(); c.resume(throwing: OBDError.timeout)
            }
            conn.start(queue: q)
        }
    }

    // shortcut: a command timeout drops the link instead of resyncing the adapter; reconnect by hand
    func send(_ command: String, timeout: TimeInterval) async throws -> String {
        var timedOut = false
        let timer = DispatchWorkItem { [conn] in timedOut = true; conn.cancel() }
        q.asyncAfter(deadline: .now() + timeout, execute: timer)
        defer { timer.cancel() }
        do {
            try await write(Data((command + "\r").utf8))
            var reply = ""
            while !reply.contains(">") { reply += try await read() }
            return reply
        } catch {
            throw timedOut ? OBDError.timeout : error
        }
    }

    func close() { conn.cancel() }

    private func write(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { if let e = $0 { c.resume(throwing: e) } else { c.resume() } })
        }
    }

    private func read() async throws -> String {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<String, Error>) in
            conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                if let error { c.resume(throwing: error) }
                else if let data, !data.isEmpty { c.resume(returning: String(decoding: data, as: UTF8.self)) }
                else { c.resume(throwing: OBDError.closed) }
            }
        }
    }
}
