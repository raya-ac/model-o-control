import Foundation

public enum ModelOButtonAction: Codable, Hashable, Sendable, Identifiable {
    case leftClick
    case rightClick
    case middleClick
    case back
    case forward
    case scrollUp
    case scrollDown
    case dpiCycle
    case dpiUp
    case dpiDown
    case dpiLock400
    case dpiLock800
    case dpiLock1600
    case previousTrack
    case nextTrack
    case playPause
    case mute
    case volumeUp
    case volumeDown
    case macroBank1
    case macroBank2
    case disabled
    case unknown([UInt8])

    public var id: String { title }

    public var title: String {
        switch self {
        case .leftClick: "Left click"
        case .rightClick: "Right click"
        case .middleClick: "Middle click"
        case .back: "Back"
        case .forward: "Forward"
        case .scrollUp: "Scroll up"
        case .scrollDown: "Scroll down"
        case .dpiCycle: "DPI cycle"
        case .dpiUp: "DPI up"
        case .dpiDown: "DPI down"
        case .dpiLock400: "DPI lock · 400"
        case .dpiLock800: "DPI lock · 800"
        case .dpiLock1600: "DPI lock · 1600"
        case .previousTrack: "Previous track"
        case .nextTrack: "Next track"
        case .playPause: "Play / pause"
        case .mute: "Mute"
        case .volumeUp: "Volume up"
        case .volumeDown: "Volume down"
        case .macroBank1: "Macro bank 1"
        case .macroBank2: "Macro bank 2"
        case .disabled: "Disabled"
        case .unknown(let bytes): "Unknown · " + bytes.map { String(format: "%02X", $0) }.joined()
        }
    }

    public var category: String {
        switch self {
        case .leftClick, .rightClick, .middleClick, .back, .forward: "Mouse"
        case .scrollUp, .scrollDown: "Scroll"
        case .dpiCycle, .dpiUp, .dpiDown, .dpiLock400, .dpiLock800, .dpiLock1600: "DPI"
        case .previousTrack, .nextTrack, .playPause, .mute, .volumeUp, .volumeDown: "Media"
        case .macroBank1, .macroBank2: "Macro"
        case .disabled: "Other"
        case .unknown: "Current"
        }
    }

    public static let selectable: [ModelOButtonAction] = [
        .leftClick, .rightClick, .middleClick, .back, .forward,
        .scrollUp, .scrollDown,
        .dpiCycle, .dpiUp, .dpiDown, .dpiLock400, .dpiLock800, .dpiLock1600,
        .previousTrack, .nextTrack, .playPause, .mute, .volumeUp, .volumeDown,
        .macroBank1, .macroBank2,
        .disabled
    ]
}

public struct ModelOButtonMapping: Codable, Hashable, Sendable {
    public var rawReport: Data
    public var actions: [ModelOButtonAction]

    public init(rawReport: Data, actions: [ModelOButtonAction]) {
        self.rawReport = rawReport
        self.actions = actions
    }

    public var editableSignature: String {
        actions.prefix(6).map(\.title).joined(separator: "|")
    }
}

public enum ModelOButtonMappingCodec {
    public static func decode(raw input: [UInt8]) throws -> ModelOButtonMapping {
        guard input.count >= 32 else { throw ModelOCodecError.reportTooShort(input.count) }
        guard input[0] == 0x04 else { throw ModelOCodecError.wrongReportID(input[0]) }
        guard input[1] == 0x12 else { throw ModelOCodecError.wrongCommand(input[1]) }
        var raw = input
        if raw.count < MouseConfiguration.reportLength {
            raw.append(contentsOf: repeatElement(0, count: MouseConfiguration.reportLength - raw.count))
        } else if raw.count > MouseConfiguration.reportLength {
            raw = Array(raw.prefix(MouseConfiguration.reportLength))
        }
        let actions = (0..<6).map { index in
            decodeAction(Array(raw[(8 + index * 4)..<(12 + index * 4)]))
        }
        return ModelOButtonMapping(rawReport: Data(raw), actions: actions)
    }

    public static func encodeForWrite(_ mapping: ModelOButtonMapping) throws -> [UInt8] {
        guard mapping.actions.count >= 6 else { throw ModelOCodecError.reportTooShort(mapping.actions.count) }
        var raw = [UInt8](mapping.rawReport)
        if raw.count < MouseConfiguration.reportLength {
            raw.append(contentsOf: repeatElement(0, count: MouseConfiguration.reportLength - raw.count))
        } else if raw.count > MouseConfiguration.reportLength {
            raw = Array(raw.prefix(MouseConfiguration.reportLength))
        }
        raw[0] = 0x04
        raw[1] = 0x12
        raw[3] = 0x50
        raw[6] = 0x06
        for index in 0..<6 {
            let bytes = encodeAction(mapping.actions[index])
            raw.replaceSubrange((8 + index * 4)..<(12 + index * 4), with: bytes)
        }
        return raw
    }

    private static func decodeAction(_ bytes: [UInt8]) -> ModelOButtonAction {
        guard bytes.count == 4 else { return .unknown(bytes) }
        return switch (bytes[0], bytes[1], bytes[2], bytes[3]) {
        case (0x11, 0x01, _, _): .leftClick
        case (0x11, 0x02, _, _): .rightClick
        case (0x11, 0x04, _, _): .middleClick
        case (0x11, 0x08, _, _): .back
        case (0x11, 0x10, _, _): .forward
        case (0x12, 0x01, _, _): .scrollUp
        case (0x12, 0xFF, _, _): .scrollDown
        case (0x41, 0x00, _, _): .dpiCycle
        case (0x41, 0x01, _, _): .dpiUp
        case (0x41, 0x02, _, _): .dpiDown
        case (0x42, 0x03, _, _): .dpiLock400
        case (0x42, 0x07, _, _): .dpiLock800
        case (0x42, 0x0F, _, _): .dpiLock1600
        case (0x22, 0x02, 0x00, 0x00): .previousTrack
        case (0x22, 0x01, 0x00, 0x00): .nextTrack
        case (0x22, 0x08, 0x00, 0x00): .playPause
        case (0x22, 0x10, 0x00, 0x00): .mute
        case (0x22, 0x40, 0x00, 0x00): .volumeUp
        case (0x22, 0x80, 0x00, 0x00): .volumeDown
        case (0x70, 0x01, 0x01, 0x01): .macroBank1
        case (0x70, 0x02, 0x01, 0x01): .macroBank2
        case (0x50, _, _, _): .disabled
        default: .unknown(bytes)
        }
    }

    private static func encodeAction(_ action: ModelOButtonAction) -> [UInt8] {
        return switch action {
        case .leftClick: [0x11, 0x01, 0, 0]
        case .rightClick: [0x11, 0x02, 0, 0]
        case .middleClick: [0x11, 0x04, 0, 0]
        case .back: [0x11, 0x08, 0, 0]
        case .forward: [0x11, 0x10, 0, 0]
        case .scrollUp: [0x12, 0x01, 0, 0]
        case .scrollDown: [0x12, 0xFF, 0, 0]
        case .dpiCycle: [0x41, 0x00, 0, 0]
        case .dpiUp: [0x41, 0x01, 0, 0]
        case .dpiDown: [0x41, 0x02, 0, 0]
        case .dpiLock400: [0x42, 0x03, 0, 0]
        case .dpiLock800: [0x42, 0x07, 0, 0]
        case .dpiLock1600: [0x42, 0x0F, 0, 0]
        case .previousTrack: [0x22, 0x02, 0x00, 0x00]
        case .nextTrack: [0x22, 0x01, 0x00, 0x00]
        case .playPause: [0x22, 0x08, 0x00, 0x00]
        case .mute: [0x22, 0x10, 0x00, 0x00]
        case .volumeUp: [0x22, 0x40, 0x00, 0x00]
        case .volumeDown: [0x22, 0x80, 0x00, 0x00]
        case .macroBank1: [0x70, 0x01, 0x01, 0x01]
        case .macroBank2: [0x70, 0x02, 0x01, 0x01]
        case .disabled: [0x50, 0x01, 0x00, 0x00]
        case .unknown(let bytes): Array((bytes + [0, 0, 0, 0]).prefix(4))
        }
    }
}
