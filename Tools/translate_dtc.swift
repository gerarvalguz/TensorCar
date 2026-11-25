// Translates the fault-code dictionary from English to Spanish with Apple's on-device translator (no internet).
//
// Needs macOS 26+ with English and Spanish downloaded in
// System Settings › General › Language & Region › Translation Languages.
//
// Usage: python3 Tools/build_dtc.py generic.json DTC-en.json
//        swift Tools/translate_dtc.swift DTC-en.json Sources/DTC.json
//
// Progress is cached next to the output, so an interrupted run picks up where it stopped.
import Foundation
import Translation

struct Info: Codable { var t: String; var d: String; var c: [String]; var s: [String] }

let args = CommandLine.arguments
guard args.count == 3 else {
    print("uso: swift Tools/translate_dtc.swift <DTC-en.json> <DTC-es.json>")
    exit(1)
}
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let cacheURL = output.appendingPathExtension("cache")

let en = Locale.Language(identifier: "en")
let es = Locale.Language(identifier: "es")
guard await LanguageAvailability().status(from: en, to: es) == .installed else {
    print("Faltan los idiomas: descarga Inglés y Español en Ajustes del Sistema › General › Idioma y región › Idiomas de traducción.")
    exit(2)
}

var codes = try JSONDecoder().decode([String: Info].self, from: Data(contentsOf: input))
var cache = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: cacheURL))) ?? [:]
// the same causes and symptoms repeat across codes, so each distinct sentence is translated once
let pending = Set(codes.values.flatMap { [$0.t, $0.d] + $0.c + $0.s }).filter { !$0.isEmpty && cache[$0] == nil }.sorted()
print("\(codes.count) códigos, \(pending.count) frases por traducir")

let session = TranslationSession(installedSource: en, target: es)
let batchSize = 200
for (n, start) in stride(from: 0, to: pending.count, by: batchSize).enumerated() {
    let batch = Array(pending[start..<min(start + batchSize, pending.count)])
    let requests = batch.indices.map { TranslationSession.Request(sourceText: batch[$0], clientIdentifier: String($0)) }
    for response in try await session.translations(from: requests) {
        if let i = response.clientIdentifier.flatMap(Int.init) { cache[batch[i]] = response.targetText }
    }
    if n % 10 == 9 || start + batchSize >= pending.count {
        try JSONEncoder().encode(cache).write(to: cacheURL, options: .atomic)
        print("\(min(start + batchSize, pending.count))/\(pending.count)")
    }
}

func tr(_ s: String) -> String { cache[s] ?? s }
for (code, info) in codes { codes[code] = Info(t: tr(info.t), d: tr(info.d), c: info.c.map(tr), s: info.s.map(tr)) }
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
try encoder.encode(codes).write(to: output, options: .atomic)
try? FileManager.default.removeItem(at: cacheURL)
print("listo: \(output.path)")
