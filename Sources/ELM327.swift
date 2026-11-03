import Foundation

func hexBytes<S: StringProtocol>(_ s: S) -> [UInt8] {
    let c = Array(s)
    return stride(from: 0, to: c.count - 1, by: 2).compactMap { UInt8(String(c[$0...$0 + 1]), radix: 16) }
}

func hexString(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined() }

struct Monitor: Identifiable {
    let id: String
    let ready: Bool
}

struct Status {
    var mil: Bool
    var count: Int
    var monitors: [Monitor]
}

/// Talks OBD-II through an ELM327. One command at a time; callers can overlap safely.
actor ELM327 {
    private let transport: Transport
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isCAN = true

    init(_ transport: Transport) { self.transport = transport }

    /// Initializes the adapter and returns the Mode 01 PIDs the car supports.
    func open() async throws -> Set<UInt8> {
        try await transport.connect()
        for c in ["ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"] { _ = try await raw(c) }
        let pids = try await supported()
        // ATDPN answers e.g. "A6": protocols 6...9 are CAN, which puts a count byte in Mode 03/07/0A replies
        let proto = try await raw("ATDPN")
        isCAN = Int(String(proto.last ?? "6"), radix: 16).map { $0 >= 6 } ?? true
        return pids
    }

    func raw(_ cmd: String, timeout: TimeInterval = 5) async throws -> String {
        await lock()
        defer { unlock() }
        let reply = try await transport.send(cmd, timeout: timeout)
        return reply.replacingOccurrences(of: ">", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sends `mode [pid]` and returns the data bytes after the echoed service id.
    func query(_ mode: UInt8, _ pid: UInt8? = nil, timeout: TimeInterval = 5) async throws -> [UInt8] {
        let tail = pid.map { hexString([$0]) } ?? ""
        let reply = try await raw(hexString([mode]) + tail, timeout: timeout)
        return try Self.payload(reply, prefix: hexString([mode + 0x40]) + tail)
    }

    func status() async throws -> Status {
        let b = try await query(1, 1)
        guard b.count >= 4 else { throw OBDError.badReply(hexString(b)) }
        let diesel = b[1] & 8 != 0
        let tests = diesel
            ? ["Catalizador NMHC", "Catalizador NOx/SCR", "", "Presión de turbo", "", "Sensor de gases de escape", "Filtro de partículas", "EGR / VVT"]
            : ["Catalizador", "Catalizador calefactado", "Evaporativo (EVAP)", "Aire secundario", "Refrigerante A/C", "Sensor de oxígeno", "Calefactor sensor O2", "EGR / VVT"]
        var monitors: [Monitor] = []
        for (i, n) in ["Fallo de encendido", "Sistema de combustible", "Componentes"].enumerated() where b[1] & (1 << i) != 0 {
            monitors.append(Monitor(id: n, ready: b[1] & (0x10 << i) == 0))
        }
        for (i, n) in tests.enumerated() where !n.isEmpty && b[2] & (1 << i) != 0 {
            monitors.append(Monitor(id: n, ready: b[3] & (1 << i) == 0))
        }
        return Status(mil: b[0] & 0x80 != 0, count: Int(b[0] & 0x7F), monitors: monitors)
    }

    /// Fault codes: mode 3 = stored, 7 = pending, 0x0A = permanent.
    func dtcs(_ mode: UInt8) async throws -> [String] {
        let b: [UInt8]
        do { b = try await query(mode) } catch OBDError.noData { return [] }
        let pairs = isCAN ? Array(b.dropFirst().prefix(Int(b.first ?? 0) * 2)) : b
        return stride(from: 0, to: pairs.count - 1, by: 2).compactMap { i in
            let (a, c) = (pairs[i], pairs[i + 1])
            guard a != 0 || c != 0 else { return nil }
            return String(Array("PCBU")[Int(a >> 6)]) + String(a >> 4 & 3) + String(format: "%X%02X", a & 15, c)
        }
    }

    /// Mode 09 text: 2 = VIN, 4 = calibration IDs, 0x0A = ECU name. Nil if the car doesn't answer.
    func info(_ pid: UInt8) async -> String? {
        guard let b = try? await query(9, pid) else { return nil }
        let text = String(decoding: b.dropFirst().map { (32..<127).contains($0) ? $0 : 32 }, as: UTF8.self)
        return text.split(separator: " ").joined(separator: " ")
    }

    /// Battery voltage as the adapter itself sees it on the OBD port; works with the engine off.
    func voltage() async throws -> Double {
        let reply = try await raw("ATRV")
        guard let v = Double(reply.filter { $0.isNumber || $0 == "." }) else { throw OBDError.badReply(reply) }
        return v
    }

    private func supported() async throws -> Set<UInt8> {
        var set = Set<UInt8>()
        for base in stride(from: UInt8(0), through: 0xC0, by: 0x20) {
            let b: [UInt8]
            // the first query makes the adapter search for the protocol, which can take several seconds
            if base == 0 { b = try await query(1, 0, timeout: 20) }
            else if set.contains(base), let r = try? await query(1, base) { b = r }
            else { break }
            guard b.count >= 4 else { break }
            for i in 0..<32 where b[i / 8] & (0x80 >> UInt8(i % 8)) != 0 { set.insert(base + UInt8(i) + 1) }
        }
        return set
    }

    private func lock() async {
        if busy { await withCheckedContinuation { waiters.append($0) } } else { busy = true }
    }

    private func unlock() {
        if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
    }

    /// Pulls the data bytes out of an adapter reply (single line or "0:/1:" multi-frame), or throws.
    static func payload(_ reply: String, prefix: String) throws -> [UInt8] {
        let lines = reply.split(whereSeparator: \.isNewline)
            .map { $0.filter { !$0.isWhitespace }.uppercased() }
            .filter { !$0.isEmpty }
        for l in lines {
            if l.contains("NODATA") { throw OBDError.noData }
            if l.contains("UNABLE") || l.contains("ERROR") || l.hasPrefix("STOPPED") { throw OBDError.noVehicle }
            if l == "?" { throw OBDError.badReply(reply) }
        }
        let frames = lines.filter { $0.dropFirst().hasPrefix(":") }
        let hex: String
        if !frames.isEmpty { hex = frames.map { String($0.dropFirst(2)) }.joined() }
        else if let l = lines.first(where: { $0.hasPrefix(prefix) }) { hex = l }
        else { throw OBDError.badReply(reply) }
        guard hex.hasPrefix(prefix) else { throw OBDError.badReply(reply) }
        return hexBytes(hex.dropFirst(prefix.count))
    }
}
