import Observation
import UIKit

@MainActor @Observable
final class OBDModel {
    enum State: Equatable { case idle, connecting, connected, failed(String) }

    var state = State.idle
    var values: [UInt8: Double] = [:]
    var supported: Set<UInt8> = []
    var battery: Double?
    var status: Status?
    var stored: [String] = []
    var pending: [String] = []
    var permanent: [String] = []
    var vin: String?
    var calibration: String?
    var ecu: String?
    var notice: String?
    let history = History()

    private var elm: ELM327?
    private var transport: Transport?
    private var session: Task<Void, Never>?

    func connect(host: String, port: UInt16, demo: Bool) {
        disconnect()
        state = .connecting
        let transport: Transport = demo ? MockTransport() : TCPTransport(host: host, port: port)
        let elm = ELM327(transport)
        (self.transport, self.elm) = (transport, elm)
        session = Task {
            do {
                supported = try await elm.open()
                status = try? await elm.status()
                await refreshDTCs()
                vin = await elm.info(2)
                calibration = await elm.info(4)
                ecu = await elm.info(0x0A)
                battery = try? await elm.voltage()
                await logScan(elm, demo: demo)
                state = .connected
                try await poll(elm)
            } catch {
                if !Task.isCancelled { reset(); state = .failed(error.localizedDescription) }
            }
        }
    }

    func disconnect() {
        reset()
        state = .idle
    }

    func refreshDTCs() async {
        guard let elm else { return }
        stored = (try? await elm.dtcs(3)) ?? []
        pending = (try? await elm.dtcs(7)) ?? []
        permanent = (try? await elm.dtcs(0x0A)) ?? []
        status = (try? await elm.status()) ?? status
    }

    func clearDTCs() async {
        guard let elm else { return }
        let before = allCodes
        do {
            _ = try await elm.query(4)
            history.add(Entry(kind: .cleared, title: "Fallas borradas desde la app", vin: vin, codes: before))
        } catch {
            notice = "No se pudieron borrar (\(error.localizedDescription)). Prueba con el contacto puesto y el motor apagado."
        }
        await refreshDTCs()
    }

    private var allCodes: [String] { stored + pending.filter { !stored.contains($0) } }

    private func logScan(_ elm: ELM327, demo: Bool) async {
        let odometer = await read(0xA6, elm)
        let since = await read(0x31, elm)
        let warmups = await read(0x30, elm)
        let previous = history.entries.first { $0.kind == .scan && $0.vin == vin }
        history.add(History.scan(vin: vin, codes: allCodes, battery: battery, km: odometer.map { Int($0) },
                                 kmSinceClear: since, warmups: warmups, previous: previous, demo: demo))
    }

    private func read(_ id: UInt8, _ elm: ELM327) async -> Double? {
        guard supported.contains(id), let pid = PID.all.first(where: { $0.id == id }),
              let raw = try? await elm.query(1, id) else { return nil }
        return pid.value(raw)
    }

    private func reset() {
        session?.cancel()
        transport?.close()
        (session, transport, elm) = (nil, nil, nil)
        values = [:]; supported = []; status = nil; battery = nil
        stored = []; pending = []; permanent = []
        vin = nil; calibration = nil; ecu = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func poll(_ elm: ELM327) async throws {
        let pids = PID.all.filter { supported.contains($0.id) }
        let fast = pids.filter(\.fast), slow = pids.filter { !$0.fast }
        guard !pids.isEmpty else { return }
        UIApplication.shared.isIdleTimerDisabled = true  // keep the screen on while driving
        var turn = 0
        while !Task.isCancelled {
            for p in fast + (slow.isEmpty ? [] : [slow[turn % slow.count]]) {
                do {
                    let raw = try await elm.query(1, p.id)
                    if let v = p.value(raw) { values[p.id] = v }
                } catch OBDError.noData {}
            }
            if let v = try? await elm.voltage() { battery = v }
            turn += 1
        }
    }
}
