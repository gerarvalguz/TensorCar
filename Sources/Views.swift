import SwiftUI
import UniformTypeIdentifiers

extension Color {
    static let brand = Color(red: 0.97, green: 0.56, blue: 0.08)
    static let brandLight = Color(red: 1.0, green: 0.74, blue: 0.30)
    static let brandSoft = adaptive(light: (1.0, 0.94, 0.84), dark: (0.24, 0.16, 0.08))
    static let canvas = adaptive(light: (0.99, 0.97, 0.94), dark: (0.07, 0.06, 0.05))
    static let surface = adaptive(light: (1, 1, 1), dark: (0.14, 0.12, 0.10))

    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

extension ShapeStyle where Self == LinearGradient {
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [.brand, .brandLight], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    func pill(_ color: Color) -> some View {
        font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }
}

struct BrandButton: ButtonStyle {
    var primary = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(primary ? .white : Color.brand)
            .background(primary ? Color.brand : Color.brandSoft, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: primary ? Color.brand.opacity(0.3) : .clear, radius: 8, y: 4)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Orange curved header + scrolling cards, the layout every tab shares.
struct Screen<Content: View>: View {
    let greeting: String
    let title: String
    let icon: String
    var list = false  // a List instead of a ScrollView, so rows can have swipe actions
    @ViewBuilder let content: Content
    @AppStorage("theme") private var theme = "auto"

    var body: some View {
        Group {
            if list {
                List {
                    Group { content }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 8, for: .scrollContent)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) { content }
                        .padding(16)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting).font(.subheadline).opacity(0.9)
                    Text(title).font(.title2.bold())
                    Text("by OnceOnce Studio").font(.caption2.weight(.medium)).opacity(0.8)
                }
                Spacer()
                // cycles automático -> claro -> oscuro
                Button { theme = ["auto": "light", "light": "dark"][theme] ?? "auto" } label: {
                    bubble(["light": "sun.max.fill", "dark": "moon.fill"][theme] ?? "circle.lefthalf.filled")
                }
                .accessibilityLabel("Apariencia: " + (["light": "claro", "dark": "oscuro"][theme] ?? "automática"))
                bubble(icon)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 26)
            .background {
                UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32)
                    .fill(.brandGradient)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .background(Color.canvas)
    }

    private func bubble(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.title3.bold())
            .frame(width: 48, height: 48)
            .background(.white.opacity(0.25), in: Circle())
    }
}

struct ContentView: View {
    @State private var model = OBDModel()
    @State private var tab = 0
    @AppStorage("theme") private var theme = "auto"
    @AppStorage("seenTutorial") private var seenTutorial = false

    var body: some View {
        TabView(selection: $tab) {
            ConnectView(model: model).tabItem { Label("Conexión", systemImage: "wifi") }.tag(0)
            LiveView(model: model).tabItem { Label("En vivo", systemImage: "speedometer") }.tag(1)
            FaultsView(model: model).tabItem { Label("Fallas", systemImage: "exclamationmark.triangle") }.tag(2)
            CarView(model: model).tabItem { Label("Auto", systemImage: "car") }.tag(3)
            HistoryView(history: model.history).tabItem { Label("Historial", systemImage: "clock.arrow.circlepath") }.tag(4)
        }
        .tint(.brand)
        .preferredColorScheme(theme == "light" ? .light : theme == "dark" ? .dark : nil)
        .onChange(of: model.state) { _, new in if new == .connected { tab = 1 } }
        .fullScreenCover(isPresented: Binding(get: { !seenTutorial }, set: { seenTutorial = !$0 })) {
            Tutorial { seenTutorial = true }
        }
    }
}

/// Shows `content` only while connected.
struct NeedsConnection<Content: View>: View {
    let model: OBDModel
    @ViewBuilder let content: Content

    var body: some View {
        if model.state == .connected {
            VStack(alignment: .leading, spacing: 16) { content }
        } else {
            ContentUnavailableView("Sin conexión", systemImage: "wifi.slash",
                                   description: Text("Conecta el adaptador en la pestaña Conexión."))
                .card()
        }
    }
}

struct ConnectView: View {
    var model: OBDModel
    @AppStorage("host") private var host = "192.168.0.10"
    @AppStorage("port") private var port = "35000"

    private let steps = [
        "Enchufa el adaptador al puerto OBD del auto y pon el contacto.",
        "En Ajustes › WiFi del iPhone, únete a la red del adaptador (suele llamarse OBDII, V-LINK o similar).",
        "Vuelve aquí y toca Conectar. Si iOS pide permiso de red local, acéptalo.",
    ]

    var body: some View {
        Screen(greeting: "Hola 👋", title: "Conecta tu auto", icon: "wifi") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Adaptador WiFi").font(.headline)
                field("IP", "192.168.0.10", $host, .numbersAndPunctuation)
                field("Puerto", "35000", $port, .numberPad)
                HStack(spacing: 8) {
                    Circle().fill(status.color).frame(width: 8, height: 8)
                    Text(status.text).font(.footnote).foregroundStyle(status.color)
                }
            }
            .card()

            if model.state == .connected || model.state == .connecting {
                Button("Desconectar") { model.disconnect() }.buttonStyle(BrandButton(primary: false))
            } else {
                Button("Conectar al auto") { model.connect(host: host, port: UInt16(port) ?? 35000, demo: false) }
                    .buttonStyle(BrandButton())
                Button("Probar en modo demo") { model.connect(host: host, port: 35000, demo: true) }
                    .buttonStyle(BrandButton(primary: false))
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Cómo conectar").font(.headline)
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)")
                            .font(.subheadline.bold()).foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.brand, in: Circle())
                        Text(step).font(.subheadline)
                    }
                }
                Text("Si no conecta, revisa en el manual del adaptador su IP y puerto. Lo más común es 192.168.0.10 y 35000.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .card()
        }
    }

    private var status: (text: String, color: Color) {
        switch model.state {
        case .idle: ("Desconectado", .secondary)
        case .connecting: ("Conectando… puede tardar unos segundos", .brand)
        case .connected: ("Conectado", .green)
        case .failed(let m): (m, .red)
        }
    }

    private func field(_ label: String, _ placeholder: String, _ text: Binding<String>, _ keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing).keyboardType(keyboard).autocorrectionDisabled()
                .fontWeight(.semibold)
        }
        .padding(12)
        .background(Color.canvas, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct LiveView: View {
    var model: OBDModel

    var body: some View {
        Screen(greeting: "En vivo", title: "Tu auto ahora", icon: "speedometer") {
            NeedsConnection(model: model) {
                let pids = PID.all.filter { model.supported.contains($0.id) }
                if let v = model.battery { BatteryTile(volts: v, rpm: model.values[0x0C]) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(pids.filter { $0.top != nil }) { Tile(pid: $0, value: model.values[$0.id]) }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sensores clave del motor").font(.headline)
                    ForEach(KeySensor.all) { s in
                        let shown = s.pids.filter { model.supported.contains($0) }
                            .compactMap { id in PID.all.first { $0.id == id } }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(s.id).pill(.brand)
                                Text(s.name).font(.subheadline.bold())
                                Spacer()
                                if shown.isEmpty { Text("Sin lectura OBD").font(.caption).foregroundStyle(.secondary) }
                            }
                            ForEach(shown) { p in
                                HStack {
                                    Text(p.name).font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(p.text(model.values[p.id]))
                                        .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(Color.brand)
                                }
                            }
                            Text(s.what).font(.caption)
                            Text("Normal: " + s.normal).font(.caption).foregroundStyle(.secondary)
                        }
                        if s.id != KeySensor.all.last?.id { Divider() }
                    }
                }
                .card()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Todos los sensores").font(.headline)
                    ForEach(pids) { p in
                        HStack {
                            Text(p.name).font(.subheadline)
                            Spacer()
                            Text(p.text(model.values[p.id]))
                                .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(Color.brand)
                        }
                        if p.id != pids.last?.id { Divider() }
                    }
                }
                .card()
            }
        }
    }
}

struct Tile: View {
    let pid: PID
    let value: Double?

    private static let icons: [UInt8: String] = [
        0x0C: "gauge.medium", 0x0D: "speedometer", 0x05: "thermometer.medium",
        0x04: "engine.combustion", 0x11: "pedal.accelerator", 0x2F: "fuelpump",
    ]

    var body: some View {
        let top = pid.top ?? 1
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: Self.icons[pid.id] ?? "gauge.medium")
                .font(.headline).foregroundStyle(Color.brand)
                .frame(width: 40, height: 40)
                .background(Color.brandSoft, in: RoundedRectangle(cornerRadius: 12))
            Text(pid.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(pid.text(value))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            ProgressView(value: min(max(value ?? 0, 0), top), total: top).tint(.brand)
        }
        .card()
    }
}

struct BatteryTile: View {
    let volts: Double
    let rpm: Double?

    var body: some View {
        let s = Battery.state(volts, rpm: rpm)
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Batería", systemImage: "bolt.fill").font(.subheadline.bold())
                Text(String(format: "%.1f V", volts))
                    .font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                Text("Estimado por voltaje").font(.caption).opacity(0.85)
            }
            Spacer()
            Text(s.text)
                .font(.caption.bold()).foregroundStyle(s.health.color)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white, in: Capsule())
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(.brandGradient, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.brand.opacity(0.3), radius: 10, y: 4)
    }
}

extension Health {
    var color: Color {
        switch self {
        case .good: .green
        case .warn: .brand
        case .bad: .red
        }
    }
}

struct FaultsView: View {
    @Bindable var model: OBDModel
    @State private var confirmClear = false
    @State private var selectedCode: String?

    var body: some View {
        Screen(greeting: "Diagnóstico", title: "Fallas del motor", icon: "wrench.and.screwdriver.fill") {
            NeedsConnection(model: model) {
                if let s = model.status { milCard(s) }
                group("Almacenadas", model.stored)
                group("Pendientes", model.pending)
                group("Permanentes", model.permanent)
                Button("Borrar fallas y apagar luz MIL") { confirmClear = true }.buttonStyle(BrandButton())
                Text("Toca un código para ver qué significa. Desliza hacia abajo para actualizar.")
                    .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
        .refreshable { await model.refreshDTCs() }
        .sheet(isPresented: Binding(get: { selectedCode != nil }, set: { if !$0 { selectedCode = nil } })) {
            if let selectedCode { DTCDetail(code: selectedCode) }
        }
        .alert("¿Borrar las fallas?", isPresented: $confirmClear) {
            Button("Borrar", role: .destructive) { Task { await model.clearDTCs() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se apaga la luz de motor y se reinician los monitores de emisiones. Si la falla sigue, volverá a aparecer.")
        }
        .alert("Aviso", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("OK") {}
        } message: { Text(model.notice ?? "") }
    }

    private func milCard(_ s: Status) -> some View {
        HStack(spacing: 14) {
            Image(systemName: s.mil ? "exclamationmark.triangle.fill" : "checkmark.seal.fill").font(.largeTitle)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.mil ? "Luz de motor encendida" : "Todo en orden").font(.headline)
                Text(s.mil ? "\(s.count) falla(s) registradas" : "La luz de motor está apagada").font(.subheadline).opacity(0.9)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(s.mil ? .brandGradient : LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20))
    }

    private func group(_ title: String, _ codes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("\(codes.count)").pill(codes.isEmpty ? .green : .brand)
            }
            if codes.isEmpty { Text("Ninguna").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(codes, id: \.self) { code in
                Button { selectedCode = code } label: {
                    HStack(spacing: 12) {
                        Text(code)
                            .font(.headline.monospaced()).foregroundStyle(Color.brand)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(Color.brandSoft, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DTCDictionary.all[code]?.t ?? "Sin descripción offline")
                                .font(.subheadline).multilineTextAlignment(.leading).lineLimit(2)
                            Text(kind(code)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private func kind(_ code: String) -> String {
        switch code.prefix(1) {
        case "P": "Motor / transmisión"
        case "B": "Carrocería"
        case "C": "Chasis"
        default: "Red / comunicación"
        }
    }
}

struct CarView: View {
    var model: OBDModel

    var body: some View {
        Screen(greeting: "Tu vehículo", title: "Información del auto", icon: "car.fill") {
            NeedsConnection(model: model) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Identificación").font(.headline)
                    row("VIN", model.vin)
                    row("Calibración", model.calibration)
                    row("Módulo (ECU)", model.ecu)
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Monitores de emisiones").font(.headline)
                    if model.status?.monitors.isEmpty ?? true { Text("No disponible").font(.subheadline).foregroundStyle(.secondary) }
                    ForEach(model.status?.monitors ?? []) { m in
                        HStack {
                            Text(m.id).font(.subheadline)
                            Spacer()
                            Text(m.ready ? "Listo" : "Pendiente").pill(m.ready ? .green : .brand)
                        }
                    }
                }
                .card()

                // PIDs 00/20/40... only say which PIDs come next, they are not sensors
                let sensors = model.supported.filter { $0 % 0x20 != 0 }.sorted()
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Sensores que reporta tu auto").font(.headline)
                        Spacer()
                        Text("\(sensors.count)").pill(.brand)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 8)], spacing: 8) {
                        ForEach(sensors, id: \.self) { id in
                            Text(String(format: "%02X", id))
                                .font(.footnote.monospaced().bold()).foregroundStyle(Color.brand)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(Color.brandSoft, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .card()
            }
        }
    }

    private func row(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "No disponible").fontWeight(.semibold).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .font(.subheadline)
    }
}

extension Entry.Kind {
    var icon: String {
        switch self {
        case .scan: "stethoscope"
        case .cleared: "trash.fill"
        case .service: "wrench.and.screwdriver.fill"
        case .repair: "hammer.fill"
        case .collision: "exclamationmark.octagon.fill"
        case .other: "note.text"
        case .tires: "tirepressure"
        }
    }

    var color: Color {
        switch self {
        case .scan: .brand
        case .cleared: .pink
        case .service: .blue
        case .repair: .purple
        case .collision: .red
        case .other: .gray
        case .tires: .teal
        }
    }
}

struct HistoryView: View {
    var history: History
    @State private var adding = false
    @State private var addingTires = false
    @State private var editing: Entry?
    @State private var backup: BackupFile?
    @State private var importing = false
    @State private var showInfo = false
    @State private var message: String?

    var body: some View {
        Screen(greeting: "Historial", title: "La vida de tu auto", icon: "clock.arrow.circlepath", list: true) {
            Button { adding = true } label: { Label("Agregar servicio, reparación o choque", systemImage: "plus") }
                .buttonStyle(BrandButton())
            HStack(spacing: 10) {
                Button {
                    do { backup = BackupFile(data: try history.exportData()) } catch { message = "No se pudo crear el respaldo." }
                } label: { Label("Exportar", systemImage: "square.and.arrow.up") }
                    .buttonStyle(BrandButton(primary: false))
                    .disabled(history.entries.isEmpty)
                Button { importing = true } label: { Label("Importar", systemImage: "square.and.arrow.down") }
                    .buttonStyle(BrandButton(primary: false))
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.title3).foregroundStyle(Color.brand)
                        .frame(width: 52, height: 52)
                        .background(Color.brandSoft, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cómo funciona el respaldo")
            }
            TireCard(latest: history.entries.first { $0.kind == .tires }) { addingTires = true }
            if history.entries.isEmpty {
                ContentUnavailableView("Sin registros todavía", systemImage: "clock",
                                       description: Text("Cada vez que conectes el auto se guarda un escaneo. También puedes anotar servicios, reparaciones y choques."))
                    .card()
            } else {
                ForEach(history.entries) { entry in
                    EntryRow(entry: entry)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { history.delete(entry.id) } label: { Label("Eliminar", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { editing = entry } label: { Label("Editar", systemImage: "pencil") }.tint(.brand)
                        }
                }
                Text("Desliza un registro a la izquierda para eliminarlo o a la derecha para editarlo.")
                    .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }
        }
        .sheet(isPresented: $adding) { EntryForm { history.add($0) } }
        .sheet(isPresented: $addingTires) { TireForm { history.add($0) } }
        .sheet(item: $editing) { entry in
            if entry.kind == .tires { TireForm(editing: entry) { history.add($0) } } else { EntryForm(editing: entry) { history.add($0) } }
        }
        .fileExporter(isPresented: Binding(get: { backup != nil }, set: { if !$0 { backup = nil } }), document: backup,
                      contentType: .json, defaultFilename: "TensorCar-historial-\(Date().formatted(.iso8601.year().month().day()))") { result in
            if case .success = result { message = "Respaldo guardado. Tenlo en tu nube para no perderlo." }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let added = try history.importData(Data(contentsOf: url))
                message = added == 0 ? "Ese respaldo no tenía registros nuevos." : "Se importaron \(added) registros."
            } catch {
                message = "No se pudo importar: el archivo no es un respaldo válido de TensorCar."
            }
        }
        .alert("Respaldo del historial", isPresented: $showInfo) {
            Button("Entendido") {}
        } message: {
            Text("""
            Exportar crea un archivo JSON con todo tu historial: escaneos, fallas, servicios, reparaciones, choques y presión de llantas.

            Guárdalo en iCloud Drive, Google Drive u otra nube. Así no lo pierdes si cambias de iPhone o borras la app, y puedes compartirlo al vender el auto.

            Importar agrega los registros del archivo que aún no estén en la app. Nunca borra nada.
            """)
        }
        .alert("Historial", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") {}
        } message: { Text(message ?? "") }
    }
}

/// The backup as a file the system save sheet can write to iCloud Drive or any other provider.
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct EntryRow: View {
    let entry: Entry
    @AppStorage("tireTarget") private var tireTarget = 32.0

    var body: some View {
        let facts: [String?] = [
            entry.km.map { "\($0.formatted()) km" },
            entry.place,
            entry.cost.map { $0.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")) },
            entry.battery.map { String(format: "Batería %.1f V", $0) },
        ]
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.kind.icon)
                .font(.headline).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(entry.kind.color, in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.kind.label).pill(entry.kind.color)
                    Spacer()
                    Text(entry.date, format: .dateTime.day().month().year()).font(.caption).foregroundStyle(.secondary)
                }
                Text(entry.title).font(.headline)
                let shown = facts.compactMap { $0 }
                if !shown.isEmpty { Text(shown.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary) }
                if !entry.codes.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(entry.codes, id: \.self) { Text($0).font(.caption.monospaced().bold()).pill(.brand) }
                    }
                }
                if let tires = entry.tires {
                    HStack(spacing: 6) {
                        ForEach(Array(zip(Tires.short, tires)), id: \.0) { name, psi in
                            Text("\(name) \(Int(psi.rounded()))").font(.caption.monospaced().bold())
                                .pill(Tires.state(psi, target: tireTarget).health.color)
                        }
                    }
                }
                if let notes = entry.notes { Text(notes).font(.subheadline) }
            }
        }
        .card()
    }
}

struct EntryForm: View {
    private let original: Entry?
    let onSave: (Entry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var kind: Entry.Kind
    @State private var date: Date
    @State private var title: String
    @State private var km: String
    @State private var place: String
    @State private var cost: String
    @State private var notes: String

    /// New entry, or an edit of `original` that keeps its id and scan data.
    init(editing original: Entry? = nil, onSave: @escaping (Entry) -> Void) {
        self.original = original
        self.onSave = onSave
        _kind = State(initialValue: original?.kind ?? .service)
        _date = State(initialValue: original?.date ?? Date())
        _title = State(initialValue: original?.title ?? "")
        _km = State(initialValue: original?.km.map(String.init) ?? "")
        _place = State(initialValue: original?.place ?? "")
        _cost = State(initialValue: original?.cost.map { $0.formatted() } ?? "")
        _notes = State(initialValue: original?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // scans and clears are recorded by the app; only their text can change
                if Entry.Kind.manual.contains(kind) {
                    Section {
                        Picker("Tipo", selection: $kind) {
                            ForEach(Entry.Kind.manual, id: \.self) { Text($0.label) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section {
                    TextField("Qué se hizo (ej. cambio de aceite)", text: $title)
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    TextField("Kilometraje", text: $km).keyboardType(.numberPad)
                    TextField("Taller", text: $place)
                    TextField("Costo", text: $cost).keyboardType(.decimalPad)
                }
                Section("Notas") {
                    TextField("Detalles, piezas cambiadas, daños…", text: $notes, axis: .vertical).lineLimit(3...8)
                }
            }
            .navigationTitle(original == nil ? "Nuevo registro" : "Editar registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }.disabled(clean(title) == nil)
                }
            }
        }
        .tint(.brand)
    }

    private func clean(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func save() {
        var entry = original ?? Entry(kind: kind, title: "")
        entry.kind = kind
        entry.date = date
        entry.title = clean(title) ?? ""
        entry.km = Int(km.filter(\.isNumber))
        entry.place = clean(place)
        entry.cost = try? Double(cost, format: .number)
        entry.notes = clean(notes)
        onSave(entry)
        dismiss()
    }
}

/// Latest manual tire reading laid out around a car, plus the button to log a new one.
struct TireCard: View {
    let latest: Entry?
    let onAdd: () -> Void
    @AppStorage("tireTarget") private var target = 32.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Neumáticos", systemImage: "tirepressure").font(.headline)
                Spacer()
                Text("Ideal \(Int(target)) psi").pill(.brand)
            }
            if let latest, let tires = latest.tires, tires.count == 4 {
                HStack(spacing: 10) {
                    VStack(spacing: 10) { tire(0, tires); tire(2, tires) }
                    Image(systemName: "car.fill")
                        .font(.system(size: 34)).foregroundStyle(Color.brand)
                    VStack(spacing: 10) { tire(1, tires); tire(3, tires) }
                }
                Text("Medido el \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Aún no hay mediciones. Mide con un manómetro con las llantas frías y regístralo aquí.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Button("Registrar presión", action: onAdd).buttonStyle(BrandButton(primary: false))
        }
        .card()
    }

    private func tire(_ i: Int, _ tires: [Double]) -> some View {
        let s = Tires.state(tires[i], target: target)
        return VStack(spacing: 4) {
            Text(Tires.names[i]).font(.caption).foregroundStyle(.secondary)
            Text(String(format: "%.0f", tires[i])).font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit()
            Text(s.text).pill(s.health.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.canvas, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct TireForm: View {
    private let original: Entry?
    let onSave: (Entry) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tireTarget") private var target = 32.0
    @State private var values: [String]
    @State private var date: Date

    init(editing original: Entry? = nil, onSave: @escaping (Entry) -> Void) {
        self.original = original
        self.onSave = onSave
        let tires = original?.tires.flatMap { $0.count == 4 ? $0 : nil }
        _values = State(initialValue: tires?.map { $0.formatted() } ?? ["", "", "", ""])
        _date = State(initialValue: original?.date ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Presión ideal: \(Int(target)) psi", value: $target, in: 20...50)
                } footer: {
                    Text("Usa la presión de la etiqueta en el marco de la puerta del conductor o la del manual.")
                }
                Section {
                    ForEach(0..<4, id: \.self) { i in
                        LabeledContent(Tires.names[i]) {
                            TextField("psi", text: $values[i]).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    }
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                } footer: {
                    Text("Mide con las llantas frías: antes de manejar o tras 3 horas detenido.")
                }
            }
            .navigationTitle("Presión de neumáticos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var entry = original ?? Entry(kind: .tires, title: "Presión de neumáticos")
                        entry.date = date
                        entry.tires = parsed
                        onSave(entry)
                        dismiss()
                    }
                    .disabled(parsed == nil)
                }
            }
        }
        .tint(.brand)
    }

    /// All four readings, each a believable psi value, or nil.
    private var parsed: [Double]? {
        let p = values.compactMap { try? Double($0, format: .number) }.filter { (5...100).contains($0) }
        return p.count == 4 ? p : nil
    }
}
