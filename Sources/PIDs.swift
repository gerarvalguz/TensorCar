import Foundation

/// A Mode 01 sensor: how many bytes it returns and how to turn them (A, B, ...) into a value.
struct PID: Identifiable {
    let id: UInt8
    let name: String
    let unit: String
    let bytes: Int
    let fast: Bool     // polled every cycle; the others take turns
    let top: Double?   // has a tile with a bar up to this value on the live screen
    let digits: Int?   // decimals to show; nil = 0 above 100, else 1
    let formula: ([Double]) -> Double

    init(_ id: UInt8, _ name: String, _ unit: String, _ bytes: Int = 1, fast: Bool = false, top: Double? = nil,
         digits: Int? = nil, _ formula: @escaping ([Double]) -> Double) {
        (self.id, self.name, self.unit, self.bytes, self.fast, self.top, self.digits, self.formula) =
            (id, name, unit, bytes, fast, top, digits, formula)
    }

    func value(_ raw: [UInt8]) -> Double? { raw.count >= bytes ? formula(raw.map(Double.init)) : nil }

    func text(_ v: Double?) -> String {
        guard let v else { return "—" }
        let s = String(format: "%.\(digits ?? (abs(v) >= 100 ? 0 : 1))f", v)
        return unit.isEmpty ? s : s + " " + unit
    }

    // shortcut: standard SAE J1979 PIDs only; VW-specific data (ABS, airbag, gearbox) needs UDS, not Mode 01
    static let all: [PID] = [
        PID(0x0C, "RPM", "rpm", 2, fast: true, top: 7000) { ($0[0] * 256 + $0[1]) / 4 },
        PID(0x0D, "Velocidad", "km/h", fast: true, top: 200) { $0[0] },
        PID(0x05, "Temp. refrigerante", "°C", top: 120) { $0[0] - 40 },
        PID(0x04, "Carga del motor", "%", fast: true, top: 100) { $0[0] * 100 / 255 },
        PID(0x11, "Acelerador", "%", fast: true, top: 100) { $0[0] * 100 / 255 },
        PID(0x2F, "Nivel de combustible", "%", top: 100) { $0[0] * 100 / 255 },
        PID(0x06, "Ajuste comb. corto plazo", "%") { $0[0] * 100 / 128 - 100 },
        PID(0x07, "Ajuste comb. largo plazo", "%") { $0[0] * 100 / 128 - 100 },
        PID(0x0B, "Presión de admisión (MAP)", "kPa") { $0[0] },
        PID(0x0E, "Avance de encendido", "°") { $0[0] / 2 - 64 },
        PID(0x0F, "Temp. aire de admisión", "°C") { $0[0] - 40 },
        PID(0x10, "Flujo de aire (MAF)", "g/s", 2) { ($0[0] * 256 + $0[1]) / 100 },
        PID(0x1F, "Tiempo con motor encendido", "s", 2) { $0[0] * 256 + $0[1] },
        PID(0x21, "Distancia con luz MIL", "km", 2) { $0[0] * 256 + $0[1] },
        PID(0x23, "Presión riel de combustible", "kPa", 2) { ($0[0] * 256 + $0[1]) * 10 },
        PID(0x30, "Arranques desde borrado", "") { $0[0] },
        PID(0x31, "Distancia desde borrado", "km", 2) { $0[0] * 256 + $0[1] },
        PID(0x33, "Presión barométrica", "kPa") { $0[0] },
        PID(0x3C, "Temp. catalizador", "°C", 2) { ($0[0] * 256 + $0[1]) / 10 - 40 },
        PID(0x42, "Voltaje del módulo", "V", 2) { ($0[0] * 256 + $0[1]) / 1000 },
        PID(0x43, "Carga absoluta", "%", 2) { ($0[0] * 256 + $0[1]) * 100 / 255 },
        PID(0x44, "Lambda comandado", "", 2, digits: 2) { ($0[0] * 256 + $0[1]) / 32768 },
        PID(0x14, "Sensor O₂ banco 1-1", "V", 2, digits: 2) { $0[0] / 200 },
        PID(0x15, "Sensor O₂ banco 1-2", "V", 2, digits: 2) { $0[0] / 200 },
        PID(0x34, "Sensor O₂ banda ancha 1-1 (λ)", "", 4, digits: 2) { ($0[0] * 256 + $0[1]) * 2 / 65536 },
        PID(0x45, "Acelerador relativo", "%") { $0[0] * 100 / 255 },
        PID(0x46, "Temp. ambiente", "°C") { $0[0] - 40 },
        PID(0x49, "Pedal del acelerador", "%") { $0[0] * 100 / 255 },
        PID(0x4C, "Acelerador comandado", "%") { $0[0] * 100 / 255 },
        PID(0x4D, "Tiempo con luz MIL", "min", 2) { $0[0] * 256 + $0[1] },
        PID(0x4E, "Tiempo desde borrado", "min", 2) { $0[0] * 256 + $0[1] },
        PID(0x5C, "Temp. aceite", "°C") { $0[0] - 40 },
        PID(0x5E, "Consumo instantáneo", "L/h", 2) { ($0[0] * 256 + $0[1]) / 20 },
        PID(0xA6, "Odómetro", "km", 4) { ($0[0] * 16_777_216 + $0[1] * 65_536 + $0[2] * 256 + $0[3]) / 10 },
    ]
}

/// The engine sensors a mechanic checks first, what they measure and what a healthy reading looks like.
struct KeySensor: Identifiable {
    let id: String  // the usual abbreviation
    let name: String
    let what: String
    let normal: String
    let pids: [UInt8]  // Mode 01 readings that show it; empty when standard OBD-II has none

    static let all: [KeySensor] = [
        KeySensor(id: "CKP", name: "Posición del cigüeñal",
                  what: "Posición y velocidad de giro del cigüeñal; de aquí salen las RPM.",
                  normal: "RPM estables con el motor en marcha. Si marca 0 mientras el motor gira, la computadora no sabe cuándo inyectar ni dar chispa y el auto no arranca.",
                  pids: [0x0C]),
        KeySensor(id: "CMP", name: "Posición del árbol de levas",
                  what: "Posición de las válvulas y su sincronía con el cigüeñal.",
                  normal: "Debe ir sincronizado con el CKP. OBD-II estándar no da su lectura; un desfase aparece como falla de correlación (P0016 a P0019) en la pestaña Fallas.",
                  pids: []),
        KeySensor(id: "ECT", name: "Temperatura del refrigerante",
                  what: "Qué tan caliente está el refrigerante del motor.",
                  normal: "En frío, cerca de la temperatura ambiente; ya caliente, estable entre 85 y 95 °C.",
                  pids: [0x05]),
        KeySensor(id: "MAF", name: "Flujo de masa de aire",
                  what: "Gramos por segundo de aire que entran al motor.",
                  normal: "Sube suave y en proporción al acelerar. Valores trabados o erráticos causan alto consumo o mezcla pobre o rica.",
                  pids: [0x10]),
        KeySensor(id: "MAP", name: "Presión del múltiple de admisión",
                  what: "Vacío o presión dentro del múltiple de admisión.",
                  normal: "Baja en ralentí y sube con la carga al acelerar. En motores turbo puede pasar la presión barométrica.",
                  pids: [0x0B]),
        KeySensor(id: "TPS", name: "Posición del acelerador",
                  what: "Qué tan abierta está la mariposa de aceleración.",
                  normal: "Sube de forma progresiva, sin saltos ni cortes, al pisar el pedal. OBD-II la reporta en porcentaje, no en voltaje.",
                  pids: [0x11, 0x45]),
        KeySensor(id: "O₂", name: "Sensor de oxígeno",
                  what: "Oxígeno sobrante en los gases de escape.",
                  normal: "Banda estrecha: oscila entre 0.1 y 0.9 V en lazo cerrado. Banda ancha (λ): se mantiene cerca de 1.00.",
                  pids: [0x34, 0x14, 0x15]),
        KeySensor(id: "KS", name: "Sensor de detonación",
                  what: "Golpeteo o cascabeleo anormal del motor.",
                  normal: "OBD-II estándar no da su lectura. Al detectar golpeteo, la computadora atrasa el encendido (el avance de abajo baja); sus fallas aparecen como P0325 a P0334.",
                  pids: [0x0E]),
    ]
}

enum Health { case good, warn, bad }

/// Rough battery verdict from voltage alone; a real health check needs VW's battery module (UDS).
enum Battery {
    // thresholds: lead-acid rests at ~12.6 V full, ~12.0 V half; smart alternators can sit near 12.5 V while cruising
    static func state(_ volts: Double, rpm: Double?) -> (text: String, health: Health) {
        if (rpm ?? 0) > 400 || volts >= 13.2 {
            switch volts {
            case ..<12.0: return ("Alternador no carga", .bad)
            case ..<12.9: return ("Voltaje bajo en marcha", .warn)
            case ...15.0: return ("Carga normal", .good)
            default: return ("Sobrecarga", .bad)
            }
        }
        switch volts {
        case ..<12.0: return ("Batería baja", .bad)
        case ..<12.5: return ("Carga media", .warn)
        default: return ("Batería cargada", .good)
        }
    }
}

/// Manual tire readings (the Taigun's deflation warning has no pressure sensors to read).
// shortcut: psi only; add kPa/bar if someone asks
enum Tires {
    static let names = ["Delantera izq.", "Delantera der.", "Trasera izq.", "Trasera der."]
    static let short = ["DI", "DD", "TI", "TD"]

    static func state(_ psi: Double, target: Double) -> (text: String, health: Health) {
        switch psi {
        case ..<(target * 0.75): ("Muy baja", .bad)  // 25% under is where TPMS rules call it dangerous
        case ..<(target - 2): ("Baja", .warn)
        case ...(target + 4): ("Bien", .good)
        default: ("Alta", .warn)
        }
    }
}
