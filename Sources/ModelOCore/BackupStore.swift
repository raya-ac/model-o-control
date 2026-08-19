import Foundation

public struct ModelOBackup: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var device: ModelODeviceInfo
    public var firmwareVersion: String
    public var rawReport: Data
    public var debounceMilliseconds: Int
    public var buttonMapping: ModelOButtonMapping?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        device: ModelODeviceInfo,
        firmwareVersion: String,
        rawReport: Data,
        debounceMilliseconds: Int,
        buttonMapping: ModelOButtonMapping? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.device = device
        self.firmwareVersion = firmwareVersion
        self.rawReport = rawReport
        self.debounceMilliseconds = debounceMilliseconds
        self.buttonMapping = buttonMapping
    }

    public func validate() throws {
        let raw = [UInt8](rawReport)
        guard raw.count >= MouseConfiguration.usedLength else {
            throw ModelOCodecError.reportTooShort(raw.count)
        }
        guard raw[0] == 4 else { throw ModelOCodecError.wrongReportID(raw[0]) }
        guard raw[1] == 0x11 else { throw ModelOCodecError.wrongCommand(raw[1]) }
        guard (4...16).contains(debounceMilliseconds), debounceMilliseconds.isMultiple(of: 2) else {
            throw ModelOCodecError.invalidDebounce(debounceMilliseconds)
        }
        if let buttonMapping {
            _ = try ModelOButtonMappingCodec.encodeForWrite(buttonMapping)
        }
    }
}

public final class ModelOBackupStore {
    public let directory: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directory = base.appendingPathComponent("Model O Control/Backups", isDirectory: true)
        }
    }

    @discardableResult
    public func save(
        device: ModelODeviceInfo,
        configuration: MouseConfiguration,
        buttonMapping: ModelOButtonMapping? = nil
    ) throws -> ModelOBackup {
        let backup = ModelOBackup(
            device: device,
            firmwareVersion: configuration.firmwareVersion,
            rawReport: configuration.rawReport,
            debounceMilliseconds: configuration.debounceMilliseconds,
            buttonMapping: buttonMapping
        )
        try backup.validate()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        let safeTimestamp = formatter.string(from: backup.createdAt).replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("model-o-\(safeTimestamp)-\(backup.id.uuidString.prefix(8)).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(backup).write(to: url, options: .atomic)
        return backup
    }

    public func all() throws -> [ModelOBackup] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try urls.map { try decoder.decode(ModelOBackup.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func latest() throws -> ModelOBackup? {
        try all().first
    }
}
