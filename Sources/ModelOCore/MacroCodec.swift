import Foundation

public enum ModelOMacroState: Sendable { case down, up }

public enum ModelOMacroEventType: Sendable {
    case mouse(UInt8)
    case keyboard(UInt8)
    case modifier(UInt8)
}

public struct ModelOMacroEvent: Sendable {
    public var state: ModelOMacroState
    public var type: ModelOMacroEventType
    public var delayMilliseconds: Int

    public init(state: ModelOMacroState, type: ModelOMacroEventType, delayMilliseconds: Int) {
        self.state = state
        self.type = type
        self.delayMilliseconds = delayMilliseconds
    }
}

public enum ModelOMacroCodecError: LocalizedError {
    case invalidBank(Int)
    case tooManyEvents(Int)
    case invalidDelay(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidBank(let bank): "Macro bank must be 1 or 2 (received \(bank))."
        case .tooManyEvents(let count): "A macro can contain at most 168 events (received \(count))."
        case .invalidDelay(let delay): "Macro delays must be between 0 and 4,095 ms (received \(delay))."
        }
    }
}

public enum ModelOMacroCodec {
    public static func encode(bank: Int, events: [ModelOMacroEvent]) throws -> [UInt8] {
        guard (1...2).contains(bank) else { throw ModelOMacroCodecError.invalidBank(bank) }
        guard events.count <= 168 else { throw ModelOMacroCodecError.tooManyEvents(events.count) }
        var raw = [UInt8](repeating: 0, count: MouseConfiguration.reportLength)
        raw.replaceSubrange(0..<8, with: [0x04, 0x30, 0x02, 0, 0, 0, 0, 0])
        raw[8] = UInt8(bank)
        raw[9] = 0
        raw[10] = UInt8(events.count)
        for (index, event) in events.enumerated() {
            guard (0...4095).contains(event.delayMilliseconds) else {
                throw ModelOMacroCodecError.invalidDelay(event.delayMilliseconds)
            }
            let typeAndCode: (UInt8, UInt8) = switch event.type {
            case .mouse(let code): (0x01, code)
            case .keyboard(let code): (0x05, code)
            case .modifier(let code): (0x06, code)
            }
            let duration = UInt16(event.delayMilliseconds)
            var first = UInt8((duration >> 8) & 0x0F)
            if event.state == .up { first |= 0x80 }
            first |= typeAndCode.0 << 4
            let offset = 11 + index * 3
            raw[offset] = first
            raw[offset + 1] = UInt8(duration & 0xFF)
            raw[offset + 2] = typeAndCode.1
        }
        return raw
    }
}
