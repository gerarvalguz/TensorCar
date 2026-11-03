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

/// The exported file: the entries plus enough to recognise it on import.
struct Backup: Codable {
    static let appName = "TensorCar"
    var app = Backup.appName
    var version = 1
    var exported = Date()
    var entries: [Entry]
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

    /// Adds the entry, or replaces the one with the same id (an edit).
    func add(_ entry: Entry) {
        if let i = entries.firstIndex(where: { $0.id == entry.id }) { entries[i] = entry } else { entries.append(entry) }
        entries.sort { $0.date > $1.date }
        save()
    }

    /// A readable JSON backup of the whole history, to keep in a cloud drive.
    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Backup(entries: entries))
    }

    /// Merges a backup: adds the entries this phone doesn't have yet and never deletes. Returns how many were added.
    func importData(_ data: Data) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: data)
        guard backup.app == Backup.appName else { throw CocoaError(.fileReadCorruptFile) }
        let known = Set(entries.map(\.id))
        let new = backup.entries.filter { !known.contains($0.id) }
        guard !new.isEmpty else { return 0 }
        entries += new
        entries.sort { $0.date > $1.date }
        save()
        return new.count
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
