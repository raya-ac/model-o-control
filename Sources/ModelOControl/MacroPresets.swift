import ModelOCore

struct ModelOMacroPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let events: [ModelOMacroEvent]

    static let builtIns: [ModelOMacroPreset] = [
        .init(id: "double-click", name: "Double click", detail: "Two left clicks · 70 ms gap", events: mouseClicks(button: 0x01, count: 2, gap: 70)),
        .init(id: "triple-click", name: "Triple click", detail: "Three left clicks · 65 ms gaps", events: mouseClicks(button: 0x01, count: 3, gap: 65)),
        .init(id: "right-double", name: "Double right click", detail: "Two right clicks · 80 ms gap", events: mouseClicks(button: 0x02, count: 2, gap: 80)),
        .init(id: "copy", name: "Copy", detail: "Command-C", events: shortcut(modifier: 0x08, key: 0x06)),
        .init(id: "paste", name: "Paste", detail: "Command-V", events: shortcut(modifier: 0x08, key: 0x19)),
        .init(id: "undo", name: "Undo", detail: "Command-Z", events: shortcut(modifier: 0x08, key: 0x1D)),
        .init(id: "redo", name: "Redo", detail: "Command-Shift-Z", events: shortcut(modifier: 0x0A, key: 0x1D)),
        .init(id: "screenshot", name: "Screenshot area", detail: "Command-Shift-4", events: shortcut(modifier: 0x0A, key: 0x21))
    ]

    static func preset(id: String) -> ModelOMacroPreset {
        builtIns.first(where: { $0.id == id }) ?? builtIns[0]
    }

    private static func mouseClicks(button: UInt8, count: Int, gap: Int) -> [ModelOMacroEvent] {
        (0..<count).flatMap { index in
            [
                ModelOMacroEvent(state: .down, type: .mouse(button), delayMilliseconds: 30),
                ModelOMacroEvent(state: .up, type: .mouse(button), delayMilliseconds: index == count - 1 ? 0 : gap)
            ]
        }
    }

    private static func shortcut(modifier: UInt8, key: UInt8) -> [ModelOMacroEvent] {
        [
            ModelOMacroEvent(state: .down, type: .modifier(modifier), delayMilliseconds: 15),
            ModelOMacroEvent(state: .down, type: .keyboard(key), delayMilliseconds: 35),
            ModelOMacroEvent(state: .up, type: .keyboard(key), delayMilliseconds: 15),
            ModelOMacroEvent(state: .up, type: .modifier(modifier), delayMilliseconds: 0)
        ]
    }

    static func == (lhs: ModelOMacroPreset, rhs: ModelOMacroPreset) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
