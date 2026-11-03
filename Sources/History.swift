import Foundation
import Observation

struct Entry: Codable, Identifiable {
    enum Kind: String, Codable {
        case scan, cleared, service, repair, collision, other, tires

        static let manual: [Kind] = [.service, .repair, .collision, .other]

        var label: String {
            switch self {
            case .scan: "Escaneo"
            case .cleared: "Fallas borradas"
            case .service: "Servicio"
            case .repair: "Reparación"
            case .collision: "Choque"
            case .other: "Otro"
            case .tires: "Neumáticos"
            }
        }
    }

    var id = UUID()
    var date = Date()
    var kind: Kind
    var title: String
    var vin: String?
    var km: Int?
    var place: String?
    var cost: Double?
    var codes: [String] = []
    var battery: Double?
    var notes: String?
    var tires: [Double]?  // psi, in Tires.names order
}

/// The car's timeline: automatic scans plus what the owner writes down. Lives in a JSON file on the phone.
@MainActor @Observable
final class History {
    private(set) var entries: [Entry] = []
    private let url: URL

    init(url: URL = URL.documentsDirectory.appending(path: "history.json")) {
        self.url = url
        guard let data = try? Data(contentsOf: url) else { return }
        do { entries = try JSONDecoder().decode([Entry].self, from: data) }
        catch { try? data.write(to: url.deletingPathExtension().appendingPathExtension("corrupt.json")) }  // keep it instead of overwriting on next save
    }

    func add(_ entry: Entry) {
        entries.append(entry)
        entries.sort { $0.date > $1.date }
        save()
    }

    func delete(_ id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    private func save() {
        try? JSONEncoder().encode(entries).write(to: url, options: .atomic)
    }

    /// Builds a scan entry and explains what changed since `previous` (the last scan of the same car).
    static func scan(vin: String?, codes: [String], battery: Double?, km: Int?, kmSinceClear: Double?, warmups: Double?,
                     previous: Entry?, demo: Bool) -> Entry {
        var notes: [String] = []
        // few km and few engine warm-ups since the last clear = someone erased the faults recently
        if let since = kmSinceClear, since < 50, (warmups ?? 0) < 10 {
            notes.append("Las fallas se borraron hace poco (hace \(Int(since)) km). Si estás comprando el auto, pregunta por qué.")
        }
        if let previous {
            let new = codes.filter { !previous.codes.contains($0) }
            let gone = previous.codes.filter { !codes.contains($0) }
            if !new.isEmpty { notes.append("Nuevas: " + new.joined(separator: ", ")) }
            if !gone.isEmpty { notes.append("Ya no aparecen: " + gone.joined(separator: ", ")) }
        }
        let title = (codes.isEmpty ? "Escaneo sin fallas" : "Escaneo con \(codes.count) falla(s)") + (demo ? " (demo)" : "")
        return Entry(kind: .scan, title: title, vin: vin, km: km, codes: codes, battery: battery,
                     notes: notes.isEmpty ? nil : notes.joined(separator: "\n"))
    }
}
