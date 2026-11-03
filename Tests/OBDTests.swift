import XCTest
@testable import TensorCar

final class OBDTests: XCTestCase {
    func testMockCarEndToEnd() async throws {
        let elm = ELM327(MockTransport())
        let pids = try await elm.open()
        XCTAssertTrue(pids.contains(0x0C) && pids.contains(0x5C) && pids.contains(0xA6), "bitmap chain 0100 -> ... -> 01A0")
        let odo = try await elm.query(1, 0xA6)
        XCTAssertEqual(PID.all.first { $0.id == 0xA6 }?.value(odo), 12345.6)
        let stored = try await elm.dtcs(3)
        XCTAssertEqual(stored, ["P0133", "P0420"])
        let pending = try await elm.dtcs(7)
        XCTAssertEqual(pending, ["P0300"])
        let vin = await elm.info(2)
        XCTAssertEqual(vin, "DEMOVIN0000000001")  // multi-frame reply
        let s = try await elm.status()
        XCTAssertTrue(s.mil)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s.monitors.first { $0.id == "Evaporativo (EVAP)" }?.ready, false)
        XCTAssertEqual(s.monitors.first { $0.id == "Catalizador" }?.ready, true)
        let volts = try await elm.voltage()
        XCTAssertEqual(volts, 14.1, accuracy: 0.05)
        _ = try await elm.query(4)
        let cleared = try await elm.dtcs(3)
        XCTAssertEqual(cleared, [])
    }

    func testPayload() throws {
        XCTAssertEqual(try ELM327.payload("SEARCHING...\r410C1AF8\r\r", prefix: "410C"), [0x1A, 0xF8])
        XCTAssertThrowsError(try ELM327.payload("NO DATA\r\r", prefix: "410C"))
        XCTAssertThrowsError(try ELM327.payload("UNABLE TO CONNECT\r\r", prefix: "410C"))
    }

    func testBatteryState() {
        XCTAssertEqual(Battery.state(12.7, rpm: nil).health, .good)  // engine off, full
        XCTAssertEqual(Battery.state(12.3, rpm: nil).health, .warn)
        XCTAssertEqual(Battery.state(11.8, rpm: nil).health, .bad)
        XCTAssertEqual(Battery.state(14.1, rpm: 800).health, .good)  // charging
        XCTAssertEqual(Battery.state(12.5, rpm: 800).health, .warn)  // running but not charging much
        XCTAssertEqual(Battery.state(11.5, rpm: 800).health, .bad)
        XCTAssertEqual(Battery.state(14.1, rpm: nil).text, "Carga normal")  // no RPM, voltage says engine is on
    }

    @MainActor func testHistory() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).json")
        let h = History(url: url)
        let first = History.scan(vin: "V", codes: ["P0133", "P0420"], battery: 12.6, km: 1000, kmSinceClear: 500, warmups: 40,
                                 previous: nil, demo: false)
        XCTAssertNil(first.notes)
        h.add(first)
        let second = History.scan(vin: "V", codes: ["P0420", "P0300"], battery: nil, km: nil, kmSinceClear: 12, warmups: 2,
                                  previous: h.entries.first, demo: false)
        let notes = try XCTUnwrap(second.notes)
        XCTAssertTrue(notes.contains("se borraron hace poco"))
        XCTAssertTrue(notes.contains("Nuevas: P0300"))
        XCTAssertTrue(notes.contains("Ya no aparecen: P0133"))
        h.add(second)
        XCTAssertEqual(History(url: url).entries.count, 2)  // survives a restart

        try Data("no es json".utf8).write(to: url)
        XCTAssertTrue(History(url: url).entries.isEmpty)
        let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))  // unreadable file kept, not lost
    }

    func testO2Formulas() throws {
        let narrow = try XCTUnwrap(PID.all.first { $0.id == 0x14 })
        XCTAssertEqual(narrow.value([90, 0x80]), 0.45)
        XCTAssertEqual(narrow.text(0.45), "0.45 V")
        let wide = try XCTUnwrap(PID.all.first { $0.id == 0x34 })
        XCTAssertEqual(wide.value([0x80, 0x00, 0x80, 0x00]), 1.0)
        XCTAssertTrue(KeySensor.all.allSatisfy { $0.pids.allSatisfy { id in PID.all.contains { $0.id == id } } })
    }

    func testOfflineDTCDictionary() {
        XCTAssertGreaterThan(DTCDictionary.all.count, 9000)
        XCTAssertFalse(DTCDictionary.all["P0420"]?.t.isEmpty ?? true)
    }

    @MainActor func testBackupRoundTrip() throws {
        let tmp = FileManager.default.temporaryDirectory
        let source = History(url: tmp.appending(path: "\(UUID()).json"))
        source.add(Entry(kind: .service, title: "Cambio de aceite", km: 15000, cost: 1200))
        source.add(Entry(kind: .tires, title: "Presión de neumáticos", tires: [32, 32, 30, 31]))
        let data = try source.exportData()

        let target = History(url: tmp.appending(path: "\(UUID()).json"))
        XCTAssertEqual(try target.importData(data), 2)
        XCTAssertEqual(try target.importData(data), 0)  // re-import adds nothing
        XCTAssertEqual(target.entries.first { $0.kind == .tires }?.tires, [32, 32, 30, 31])
        XCTAssertThrowsError(try target.importData(Data("{\"entries\":[]}".utf8)))  // not a TensorCar backup

        var edited = target.entries[0]
        edited.title = "Editado"
        target.add(edited)
        XCTAssertEqual(target.entries.count, 2)  // edit replaces, not duplicates
        XCTAssertTrue(target.entries.contains { $0.title == "Editado" })
    }

    func testTireState() {
        XCTAssertEqual(Tires.state(32, target: 32).health, .good)
        XCTAssertEqual(Tires.state(29, target: 32).health, .warn)  // 3 psi low
        XCTAssertEqual(Tires.state(23, target: 32).health, .bad)   // >25% low
        XCTAssertEqual(Tires.state(38, target: 32).text, "Alta")
    }

    func testRPMFormula() throws {
        let rpm = try XCTUnwrap(PID.all.first { $0.id == 0x0C })
        XCTAssertEqual(rpm.value([0x1A, 0xF8]), 1726)
        XCTAssertNil(rpm.value([0x1A]))
    }
}
