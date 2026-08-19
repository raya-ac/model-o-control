import Foundation
import ModelOCore

struct SavedLightingLook: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let effect: LightingEffect
    let color: MouseColor
    let brightness: Int
    let speed: Int

    init(configuration: MouseConfiguration) {
        id = UUID()
        createdAt = Date()
        effect = configuration.lightingEffect
        color = configuration.lightingColor
        brightness = configuration.lightingBrightness
        speed = configuration.lightingSpeed
    }

    var name: String { "\(effect.title) · \(color.hexValue)" }

    func apply(to configuration: inout MouseConfiguration) {
        configuration.lightingEffect = effect
        if effect.supportsPrimaryColor { configuration.lightingColor = color }
        if effect.supportsBrightness { configuration.lightingBrightness = brightness }
        if effect.supportsSpeed { configuration.lightingSpeed = speed }
    }
}

final class SavedLightingStore {
    let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        fileURL = base.appendingPathComponent("Model O Control/Lighting/saved-looks.json")
    }

    func all() throws -> [SavedLightingLook] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([SavedLightingLook].self, from: Data(contentsOf: fileURL))
            .sorted { $0.createdAt > $1.createdAt }
    }

    func save(configuration: MouseConfiguration) throws {
        var looks = (try? all()) ?? []
        looks.insert(SavedLightingLook(configuration: configuration), at: 0)
        try write(Array(looks.prefix(24)))
    }

    func delete(id: UUID) throws {
        var looks = try all()
        looks.removeAll { $0.id == id }
        try write(looks)
    }

    private func write(_ looks: [SavedLightingLook]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(looks).write(to: fileURL, options: .atomic)
    }
}

private extension MouseColor {
    var hexValue: String { String(format: "#%02X%02X%02X", red, green, blue) }
}
