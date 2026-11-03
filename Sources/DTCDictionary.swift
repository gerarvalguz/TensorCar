import SwiftUI

/// One fault code from the bundled OBDex dictionary (CC0, English). Built by Tools/build_dtc.py.
struct DTCInfo: Decodable {
    let t: String    // title
    let d: String    // what it means
    let c: [String]  // common causes, most likely first
    let s: [String]  // symptoms
}

enum DTCDictionary {
    // shortcut: decoded on first use on the main thread (~6 MB, a fraction of a second); move off it if Fallas stutters
    static let all: [String: DTCInfo] = {
        guard let url = Bundle.main.url(forResource: "DTC", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: DTCInfo].self, from: data)) ?? [:]
    }()
}

/// What a fault code means, read from the offline dictionary, with a web search as fallback.
struct DTCDetail: View {
    let code: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let info = DTCDictionary.all[code]
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(code).font(.largeTitle.monospaced().bold()).foregroundStyle(Color.brand)
                        Text(info?.t ?? "Este código no está en la base offline").font(.title3.bold())
                    }
                    if let info {
                        if !info.d.isEmpty { section("Qué significa", icon: "info.circle.fill", [info.d], bullets: false) }
                        if !info.c.isEmpty { section("Causas probables", icon: "wrench.and.screwdriver.fill", info.c, bullets: true) }
                        if !info.s.isEmpty { section("Síntomas", icon: "stethoscope", info.s, bullets: true) }
                    } else {
                        section("Por qué", icon: "questionmark.circle.fill",
                                ["Suele ser un código propio del fabricante (por ejemplo P1xxx). La base offline solo trae códigos genéricos."],
                                bullets: false)
                    }
                    Link(destination: URL(string: "https://www.google.com/search?q=OBD2+\(code)")!) {
                        Label("Buscar en internet", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(BrandButton(primary: false))
                    Text("Descripciones en inglés de OBDex (dominio público), incluidas en la app; no necesitan internet.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .background(Color.canvas)
            .navigationTitle("Detalle de la falla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        }
        .tint(.brand)
    }

    private func section(_ title: String, icon: String, _ lines: [String], bullets: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(Color.brand)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if bullets { Circle().fill(Color.brand).frame(width: 6, height: 6) }
                    Text(line).font(.subheadline)
                }
            }
        }
        .card()
    }
}
