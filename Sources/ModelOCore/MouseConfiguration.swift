import Foundation

public struct MouseColor: Codable, Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let violet = MouseColor(red: 124, green: 92, blue: 255)
}

public struct DPIProfile: Codable, Hashable, Identifiable, Sendable {
    public var id: Int
    public var enabled: Bool
    public var dpi: Int
    public var color: MouseColor

    public init(id: Int, enabled: Bool, dpi: Int, color: MouseColor) {
        self.id = id
        self.enabled = enabled
        self.dpi = dpi
        self.color = color
    }
}

public enum PollingRate: Int, Codable, CaseIterable, Identifiable, Sendable {
    case hz125 = 1
    case hz250 = 2
    case hz500 = 3
    case hz1000 = 4

    public var id: Int { rawValue }
    public var hertz: Int { [1: 125, 2: 250, 3: 500, 4: 1000][rawValue] ?? 1000 }
}

public enum LightingEffect: UInt8, Codable, CaseIterable, Identifiable, Sendable {
    case off = 0
    case glorious = 1
    case single = 2
    case breathing = 3
    case tail = 4
    case seamless = 5
    case constant = 6
    case rave = 7
    case random = 8
    case wave = 9
    case singleBreathing = 10

    public var id: UInt8 { rawValue }

    public var title: String {
        switch self {
        case .off: "Off"
        case .glorious: "Glorious"
        case .single: "Single colour"
        case .breathing: "Colour cycle"
        case .tail: "Tail"
        case .seamless: "Seamless breathing"
        case .constant: "Per-LED colour"
        case .rave: "Rave"
        case .random: "Random"
        case .wave: "Wave"
        case .singleBreathing: "Single breathing"
        }
    }

    public var supportsPrimaryColor: Bool {
        [.single, .breathing, .constant, .rave, .singleBreathing].contains(self)
    }

    public var supportsBrightness: Bool {
        [.single, .tail, .rave, .wave].contains(self)
    }

    public var supportsSpeed: Bool {
        ![.off, .single, .constant].contains(self)
    }
}

public struct MouseConfiguration: Codable, Hashable, Sendable {
    public static let reportLength = 520
    public static let usedLength = 131

    public var firmwareVersion: String
    public var rawReport: Data
    public var profiles: [DPIProfile]
    public var activeProfile: Int
    public var pollingRate: PollingRate
    public var lightingEffect: LightingEffect
    public var lightingColor: MouseColor
    public var lightingBrightness: Int
    public var lightingSpeed: Int
    public var debounceMilliseconds: Int
    public var liftOffDistanceMillimeters: Int
    public var dpiAxesIndependent: Bool

    public init(
        firmwareVersion: String,
        rawReport: Data,
        profiles: [DPIProfile],
        activeProfile: Int,
        pollingRate: PollingRate,
        lightingEffect: LightingEffect,
        lightingColor: MouseColor,
        lightingBrightness: Int,
        lightingSpeed: Int,
        debounceMilliseconds: Int,
        liftOffDistanceMillimeters: Int,
        dpiAxesIndependent: Bool
    ) {
        self.firmwareVersion = firmwareVersion
        self.rawReport = rawReport
        self.profiles = profiles
        self.activeProfile = activeProfile
        self.pollingRate = pollingRate
        self.lightingEffect = lightingEffect
        self.lightingColor = lightingColor
        self.lightingBrightness = lightingBrightness
        self.lightingSpeed = lightingSpeed
        self.debounceMilliseconds = debounceMilliseconds
        self.liftOffDistanceMillimeters = liftOffDistanceMillimeters
        self.dpiAxesIndependent = dpiAxesIndependent
    }

    public var editableSignature: String {
        let profilePart = profiles.prefix(6).map {
            "\($0.enabled ? 1 : 0):\($0.dpi):\($0.color.red),\($0.color.green),\($0.color.blue)"
        }.joined(separator: "|")
        return [
            profilePart,
            String(activeProfile),
            String(pollingRate.rawValue),
            String(lightingEffect.rawValue),
            "\(lightingColor.red),\(lightingColor.green),\(lightingColor.blue)",
            String(lightingBrightness),
            String(lightingSpeed),
            String(debounceMilliseconds),
            String(liftOffDistanceMillimeters)
        ].joined(separator: ";")
    }
}

public enum ModelOCodecError: LocalizedError, Equatable {
    case reportTooShort(Int)
    case wrongReportID(UInt8)
    case wrongCommand(UInt8)
    case invalidPollingRate(UInt8)
    case invalidEffect(UInt8)
    case noEnabledDPIProfile
    case invalidDPI(Int)
    case invalidDebounce(Int)
    case invalidLiftOffDistance(Int)

    public var errorDescription: String? {
        switch self {
        case .reportTooShort(let count): "Configuration report is too short (\(count) bytes)."
        case .wrongReportID(let value): "Unexpected report ID 0x\(String(value, radix: 16))."
        case .wrongCommand(let value): "Unexpected command 0x\(String(value, radix: 16))."
        case .invalidPollingRate(let value): "The mouse returned an unsupported polling-rate value (\(value))."
        case .invalidEffect(let value): "The mouse returned an unknown lighting effect (\(value))."
        case .noEnabledDPIProfile: "At least one DPI profile must remain enabled."
        case .invalidDPI(let value): "DPI must be between 100 and 25,600 in steps of 100 (received \(value))."
        case .invalidDebounce(let value): "Debounce must be an even value from 4 to 16 ms (received \(value))."
        case .invalidLiftOffDistance(let value): "Lift-off distance must be 2 or 3 mm (received \(value))."
        }
    }
}

public enum ModelOVerification {
    public static func matches(
        actual: MouseConfiguration,
        expected: MouseConfiguration,
        changedFrom baseline: MouseConfiguration
    ) -> Bool {
        let expectedProfiles = Array(expected.profiles.prefix(6))
        let baselineProfiles = Array(baseline.profiles.prefix(6))
        if expectedProfiles != baselineProfiles,
           Array(actual.profiles.prefix(6)) != expectedProfiles {
            return false
        }

        if expected.activeProfile != baseline.activeProfile,
           actual.activeProfile != expected.activeProfile {
            return false
        }
        if expected.pollingRate != baseline.pollingRate,
           actual.pollingRate != expected.pollingRate {
            return false
        }

        let effectChanged = expected.lightingEffect != baseline.lightingEffect
        if effectChanged, actual.lightingEffect != expected.lightingEffect {
            return false
        }
        if expected.lightingEffect.supportsPrimaryColor,
           (effectChanged || expected.lightingColor != baseline.lightingColor),
           actual.lightingColor != expected.lightingColor {
            return false
        }
        if expected.lightingEffect.supportsBrightness,
           (effectChanged || expected.lightingBrightness != baseline.lightingBrightness),
           actual.lightingBrightness != expected.lightingBrightness {
            return false
        }
        if expected.lightingEffect.supportsSpeed,
           (effectChanged || expected.lightingSpeed != baseline.lightingSpeed),
           actual.lightingSpeed != expected.lightingSpeed {
            return false
        }

        if expected.debounceMilliseconds != baseline.debounceMilliseconds,
           actual.debounceMilliseconds != expected.debounceMilliseconds {
            return false
        }
        if expected.liftOffDistanceMillimeters != baseline.liftOffDistanceMillimeters,
           actual.liftOffDistanceMillimeters != expected.liftOffDistanceMillimeters {
            return false
        }
        return true
    }
}

public enum ModelOCodec {
    public static func decode(raw input: [UInt8], firmware: String, debounceMilliseconds: Int) throws -> MouseConfiguration {
        guard input.count >= MouseConfiguration.usedLength else {
            throw ModelOCodecError.reportTooShort(input.count)
        }
        guard input[0] == 0x04 else { throw ModelOCodecError.wrongReportID(input[0]) }
        guard input[1] == 0x11 else { throw ModelOCodecError.wrongCommand(input[1]) }

        var raw = input
        if raw.count < MouseConfiguration.reportLength {
            raw.append(contentsOf: repeatElement(0, count: MouseConfiguration.reportLength - raw.count))
        } else if raw.count > MouseConfiguration.reportLength {
            raw = Array(raw.prefix(MouseConfiguration.reportLength))
        }

        let independent = (raw[10] & 0xF0) != 0
        let pollingValue = raw[10] & 0x0F
        guard let pollingRate = PollingRate(rawValue: Int(pollingValue)) else {
            throw ModelOCodecError.invalidPollingRate(pollingValue)
        }

        // The controller numbers DPI stages from 1 in the report's high nibble,
        // while the app uses zero-based profile indices.
        let reportedActiveStage = Int(raw[11] >> 4)
        let active = max(0, reportedActiveStage - 1)
        let disabledMask = raw[12]
        var profiles: [DPIProfile] = []
        for index in 0..<8 {
            let encodedDPI = independent ? raw[13 + (index * 2)] : raw[13 + index]
            let dpi = (Int(encodedDPI) + 1) * 100
            let colorOffset = 29 + (index * 3)
            profiles.append(DPIProfile(
                id: index,
                enabled: (disabledMask & (1 << index)) == 0,
                dpi: dpi,
                color: MouseColor(red: raw[colorOffset], green: raw[colorOffset + 1], blue: raw[colorOffset + 2])
            ))
        }

        guard let effect = LightingEffect(rawValue: raw[53]) else {
            throw ModelOCodecError.invalidEffect(raw[53])
        }
        let mode = modeByte(for: effect, raw: raw)
        let color = primaryColor(for: effect, raw: raw)

        return MouseConfiguration(
            firmwareVersion: firmware,
            rawReport: Data(raw),
            profiles: profiles,
            activeProfile: active,
            pollingRate: pollingRate,
            lightingEffect: effect,
            lightingColor: color,
            lightingBrightness: Int(mode >> 4),
            lightingSpeed: Int(mode & 0x0F),
            debounceMilliseconds: debounceMilliseconds,
            liftOffDistanceMillimeters: raw[129] == 2 ? 3 : 2,
            dpiAxesIndependent: independent
        )
    }

    public static func encodeForWrite(_ configuration: MouseConfiguration) throws -> [UInt8] {
        try validate(configuration)
        var raw = [UInt8](configuration.rawReport)
        guard raw.count >= MouseConfiguration.usedLength else {
            throw ModelOCodecError.reportTooShort(raw.count)
        }
        if raw.count < MouseConfiguration.reportLength {
            raw.append(contentsOf: repeatElement(0, count: MouseConfiguration.reportLength - raw.count))
        } else if raw.count > MouseConfiguration.reportLength {
            raw = Array(raw.prefix(MouseConfiguration.reportLength))
        }

        raw[0] = 0x04
        raw[1] = 0x11
        raw[3] = 0x7B
        raw[10] = (raw[10] & 0xF0) | UInt8(configuration.pollingRate.rawValue)

        var disabledMask = raw[12]
        for profile in configuration.profiles.prefix(6) {
            if profile.enabled {
                disabledMask &= ~(1 << profile.id)
            } else {
                disabledMask |= (1 << profile.id)
            }

            let encoded = UInt8((profile.dpi / 100) - 1)
            if configuration.dpiAxesIndependent {
                raw[13 + profile.id * 2] = encoded
                raw[13 + profile.id * 2 + 1] = encoded
            } else {
                raw[13 + profile.id] = encoded
            }

            let colorOffset = 29 + profile.id * 3
            raw[colorOffset] = profile.color.red
            raw[colorOffset + 1] = profile.color.green
            raw[colorOffset + 2] = profile.color.blue
        }
        raw[12] = disabledMask

        let enabledIndices = configuration.profiles.filter(\.enabled).map(\.id)
        let active = enabledIndices.contains(configuration.activeProfile) ? configuration.activeProfile : enabledIndices[0]
        let enabledCount = min(enabledIndices.count, 15)
        let reportedActiveStage = active + 1
        raw[11] = UInt8((reportedActiveStage << 4) | enabledCount)

        raw[53] = configuration.lightingEffect.rawValue
        let brightness = UInt8(configuration.lightingBrightness)
        let speed = UInt8(configuration.lightingSpeed)
        let combined = (brightness << 4) | speed
        switch configuration.lightingEffect {
        case .off:
            break
        case .glorious:
            raw[54] = (raw[54] & 0xF0) | speed
        case .single:
            raw[56] = brightness << 4
            putRBG(configuration.lightingColor, into: &raw, at: 57)
        case .breathing:
            raw[60] = (raw[60] & 0xF0) | speed
            raw[61] = max(raw[61], 1)
            putRBG(configuration.lightingColor, into: &raw, at: 62)
        case .tail:
            raw[83] = combined
        case .seamless:
            raw[84] = (raw[84] & 0xF0) | speed
        case .constant:
            putRBG(configuration.lightingColor, into: &raw, at: 86)
        case .rave:
            raw[116] = combined
            putRBG(configuration.lightingColor, into: &raw, at: 117)
        case .random:
            raw[123] = (raw[123] & 0xF0) | speed
        case .wave:
            raw[124] = combined
        case .singleBreathing:
            raw[125] = (raw[125] & 0xF0) | speed
            putRBG(configuration.lightingColor, into: &raw, at: 126)
        }

        raw[129] = configuration.liftOffDistanceMillimeters == 3 ? 2 : 1
        return raw
    }

    public static func validate(_ configuration: MouseConfiguration) throws {
        guard configuration.profiles.contains(where: \.enabled) else {
            throw ModelOCodecError.noEnabledDPIProfile
        }
        for profile in configuration.profiles.prefix(6) {
            guard profile.dpi >= 100, profile.dpi <= 25_600, profile.dpi % 100 == 0 else {
                throw ModelOCodecError.invalidDPI(profile.dpi)
            }
        }
        let debounce = configuration.debounceMilliseconds
        guard (4...16).contains(debounce), debounce.isMultiple(of: 2) else {
            throw ModelOCodecError.invalidDebounce(debounce)
        }
        guard [2, 3].contains(configuration.liftOffDistanceMillimeters) else {
            throw ModelOCodecError.invalidLiftOffDistance(configuration.liftOffDistanceMillimeters)
        }
    }

    private static func modeByte(for effect: LightingEffect, raw: [UInt8]) -> UInt8 {
        switch effect {
        case .off: 0
        case .glorious: raw[54]
        case .single: raw[56]
        case .breathing: raw[60]
        case .tail: raw[83]
        case .seamless: raw[84]
        case .constant: 0
        case .rave: raw[116]
        case .random: raw[123]
        case .wave: raw[124]
        case .singleBreathing: raw[125]
        }
    }

    private static func primaryColor(for effect: LightingEffect, raw: [UInt8]) -> MouseColor {
        switch effect {
        case .single: getRBG(raw, at: 57)
        case .breathing: getRBG(raw, at: 62)
        case .constant: getRBG(raw, at: 86)
        case .rave: getRBG(raw, at: 117)
        case .singleBreathing: getRBG(raw, at: 126)
        default: MouseColor(red: raw[29], green: raw[30], blue: raw[31])
        }
    }

    private static func getRBG(_ raw: [UInt8], at offset: Int) -> MouseColor {
        MouseColor(red: raw[offset], green: raw[offset + 2], blue: raw[offset + 1])
    }

    private static func putRBG(_ color: MouseColor, into raw: inout [UInt8], at offset: Int) {
        raw[offset] = color.red
        raw[offset + 1] = color.blue
        raw[offset + 2] = color.green
    }
}
