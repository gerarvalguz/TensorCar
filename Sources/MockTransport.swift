import Foundation

/// A fake ELM327 + car, so the app runs without hardware (demo mode and tests).
/// Answers in the same format a real adapter uses with ATE0 ATS0 ATH0, including multi-frame replies.
final class MockTransport: Transport {
    private var dtcs: [UInt8] = [0x01, 0x33, 0x04, 0x20]  // P0133, P0420

    func connect() async throws {}
    func close() {}

    func send(_ command: String, timeout: TimeInterval) async throws -> String {
        try await Task.sleep(nanoseconds: 30_000_000)
        return reply(command.uppercased()) + "\r\r>"
    }

    private func reply(_ cmd: String) -> String {
        if cmd.hasPrefix("AT") {
            switch cmd {
            case "ATDPN": return "A6"
            case "ATRV": return "14.1V"
            default: return "OK"
            }
        }
        let b = hexBytes(cmd)
        guard let mode = b.first else { return "?" }
        let pid = b.count > 1 ? b[1] : nil
        switch (mode, pid) {
        case (1, let p?) where p % 0x20 == 0 && p < 0xE0: return hexString([0x41, p] + bitmap(p))
        case (1, 1?):
            let a: UInt8 = dtcs.isEmpty ? 0 : 0x80 | UInt8(dtcs.count / 2)
            return hexString([0x41, 1, a, 0x07, 0x65, 0x04])  // spark ignition; EVAP monitor not ready
        case (1, let p?): return live(p).map { hexString([0x41, p] + $0) } ?? "NO DATA"
        case (3, _): return hexString([0x43, UInt8(dtcs.count / 2)] + dtcs)
        case (7, _): return "47010300"  // pending P0300
        case (0x0A, _): return "4A00"
        case (4, _): dtcs = []; return "44"
        case (9, 2?): return multiframe([0x49, 2, 1] + Array("DEMOVIN0000000001".utf8))
        default: return "NO DATA"
        }
    }

    private func bitmap(_ base: UInt8) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 4)
        for i in 0..<32 {
            let pid = Int(base) + i + 1
            let on = pid % 0x20 == 0 ? (pid + 1...0xFF).contains { live(UInt8($0)) != nil } : live(UInt8(pid)) != nil
            if on { out[i / 8] |= 0x80 >> UInt8(i % 8) }
        }
        return out
    }

    private func multiframe(_ bytes: [UInt8]) -> String {
        var lines = [String(format: "%03X", bytes.count)]
        var rest = bytes[...]
        var n = 0
        while !rest.isEmpty {
            let size = n == 0 ? 6 : 7
            lines.append("\(n): " + hexString(Array(rest.prefix(size))))
            rest = rest.dropFirst(size)
            n += 1
        }
        return lines.joined(separator: "\r")
    }

    private func live(_ p: UInt8) -> [UInt8]? {
        let w = 0.5 + 0.5 * sin(Date.timeIntervalSinceReferenceDate / 3)  // 0...1, slow swing
        func u8(_ v: Double) -> [UInt8] { [UInt8(max(0, min(255, v)))] }
        func u16(_ v: Double) -> [UInt8] {
            let n = UInt16(max(0, min(65535, v)))
            return [UInt8(n >> 8), UInt8(n & 255)]
        }
        switch p {
        case 0x04: return u8(80 + 60 * w)
        case 0x05: return u8(128)
        case 0x06: return u8(129)
        case 0x07: return u8(126)
        case 0x0B: return u8(35 + 40 * w)
        case 0x0C: return u16((800 + 2200 * w) * 4)
        case 0x0D: return u8(70 * w)
        case 0x0E: return u8(148)
        case 0x0F: return u8(68)
        case 0x10: return u16(300 + 900 * w)
        case 0x11: return u8(30 + 60 * w)
        case 0x1F: return u16(754)
        case 0x21: return u16(12)
        case 0x23: return u16(800)
        case 0x2F: return u8(158)
        case 0x30: return u8(12)
        case 0x31: return u16(340)
        case 0x33: return u8(100)
        case 0x3C: return u16(4400)
        case 0x42: return u16(14100)
        case 0x43: return u16(76)
        case 0x44: return u16(32768)
        case 0x45: return u8(40)
        case 0x46: return u8(70)
        case 0x49, 0x4C: return u8(30 + 60 * w)
        case 0x4D: return u16(5)
        case 0x4E: return u16(340)
        case 0x5C: return u8(135)
        case 0x5E: return u16(80)
        case 0xA6: return [0x00, 0x01, 0xE2, 0x40]  // 12345.6 km
        case 0x14: return u8(20 + 160 * (0.5 + 0.5 * sin(Date.timeIntervalSinceReferenceDate * 2))) + [0x80]  // switching 0.1-0.9 V
        case 0x15: return [130, 0x80]  // ~0.65 V, steady after the catalyst
        case 0x34: return [0x80, 0x00, 0x80, 0x00]  // λ 1.00
        default: return nil
        }
    }
}
