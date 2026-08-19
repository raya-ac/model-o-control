import Foundation
import ModelOCore

struct SavedDeviceProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    let configuration: MouseConfiguration
    var isFavorite: Bool?

    init(configuration: MouseConfiguration) {
        id = UUID()
        createdAt = Date()
        self.configuration = configuration
        isFavorite = false
        let activeDPI = configuration.profiles.first(where: { $0.id == configuration.activeProfile })?.dpi ?? 0
        name = "\(activeDPI) DPI · \(configuration.lightingEffect.title)"
    }

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), configuration: MouseConfiguration, isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.configuration = configuration
        self.isFavorite = isFavorite
    }

    func apply(to draft: inout MouseConfiguration) {
        for index in 0..<min(6, min(draft.profiles.count, configuration.profiles.count)) {
            draft.profiles[index] = configuration.profiles[index]
        }
        draft.activeProfile = min(configuration.activeProfile, max(0, draft.profiles.count - 1))
        draft.pollingRate = configuration.pollingRate
        draft.lightingEffect = configuration.lightingEffect
        draft.lightingColor = configuration.lightingColor
        draft.lightingBrightness = configuration.lightingBrightness
        draft.lightingSpeed = configuration.lightingSpeed
        draft.debounceMilliseconds = configuration.debounceMilliseconds
        draft.liftOffDistanceMillimeters = configuration.liftOffDistanceMillimeters
        draft.dpiAxesIndependent = configuration.dpiAxesIndependent
    }

    var summary: String {
        let enabled = configuration.profiles.prefix(6).filter(\.enabled).map { String($0.dpi) }.joined(separator: " / ")
        return "\(enabled) DPI · \(configuration.pollingRate.hertz) Hz · \(configuration.debounceMilliseconds) ms"
    }
}

final class SavedProfileStore {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.fileURL = base.appendingPathComponent("Model O Control/Profiles/saved-profiles.json")
        }
    }

    func all() throws -> [SavedDeviceProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return sort(try decoder.decode([SavedDeviceProfile].self, from: Data(contentsOf: fileURL)))
    }

    @discardableResult
    func save(configuration: MouseConfiguration) throws -> SavedDeviceProfile {
        let saved = SavedDeviceProfile(configuration: configuration)
        var profiles = (try? all()) ?? []
        profiles.insert(saved, at: 0)
        profiles = Array(profiles.prefix(24))
        try write(profiles)
        return saved
    }

    func delete(id: UUID) throws {
        var profiles = try all()
        profiles.removeAll { $0.id == id }
        try write(profiles)
    }

    func rename(id: UUID, to name: String) throws {
        var profiles = try all()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try write(profiles)
    }

    func toggleFavorite(id: UUID) throws {
        var profiles = try all()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].isFavorite = !(profiles[index].isFavorite ?? false)
        try write(profiles)
    }

    func duplicate(id: UUID) throws {
        var profiles = try all()
        guard let source = profiles.first(where: { $0.id == id }) else { return }
        profiles.insert(SavedDeviceProfile(name: source.name + " copy", configuration: source.configuration), at: 0)
        try write(Array(profiles.prefix(24)))
    }

    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(try all())
    }

    func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode([SavedDeviceProfile].self, from: data)
        var profiles = try all()
        let existing = Set(profiles.map(\.id))
        profiles.insert(contentsOf: imported.filter { !existing.contains($0.id) }, at: 0)
        try write(Array(sort(profiles).prefix(24)))
    }

    private func write(_ profiles: [SavedDeviceProfile]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(profiles).write(to: fileURL, options: .atomic)
    }

    private func sort(_ profiles: [SavedDeviceProfile]) -> [SavedDeviceProfile] {
        profiles.sorted {
            if ($0.isFavorite ?? false) != ($1.isFavorite ?? false) { return $0.isFavorite ?? false }
            return $0.createdAt > $1.createdAt
        }
    }
}
