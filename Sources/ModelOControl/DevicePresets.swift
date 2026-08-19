import ModelOCore
import SwiftUI

struct DevicePreset: Identifiable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let dpis: [Int]
    let activeStage: Int
    let pollingRate: PollingRate
    let debounce: Int
    let liftOffDistance: Int
    let lightingEffect: LightingEffect
    let lightingColor: MouseColor
    let lightingBrightness: Int
    let lightingSpeed: Int

    func apply(to configuration: inout MouseConfiguration) {
        for index in 0..<min(6, configuration.profiles.count) {
            configuration.profiles[index].enabled = index < dpis.count
            if index < dpis.count {
                configuration.profiles[index].dpi = dpis[index]
                configuration.profiles[index].color = StagePalette.color(at: index)
            }
        }
        configuration.activeProfile = min(activeStage, max(0, dpis.count - 1))
        configuration.pollingRate = pollingRate
        configuration.debounceMilliseconds = debounce
        configuration.liftOffDistanceMillimeters = liftOffDistance
        configuration.lightingEffect = lightingEffect
        if lightingEffect.supportsPrimaryColor { configuration.lightingColor = lightingColor }
        if lightingEffect.supportsBrightness { configuration.lightingBrightness = lightingBrightness }
        if lightingEffect.supportsSpeed { configuration.lightingSpeed = lightingSpeed }
    }

    func matches(_ configuration: MouseConfiguration) -> Bool {
        let profiles = Array(configuration.profiles.prefix(6))
        guard profiles.indices.allSatisfy({ index in
            let shouldEnable = index < dpis.count
            return profiles[index].enabled == shouldEnable && (!shouldEnable || profiles[index].dpi == dpis[index])
        }) else { return false }
        guard configuration.activeProfile == activeStage,
              configuration.pollingRate == pollingRate,
              configuration.debounceMilliseconds == debounce,
              configuration.liftOffDistanceMillimeters == liftOffDistance,
              configuration.lightingEffect == lightingEffect else { return false }
        if lightingEffect.supportsPrimaryColor, configuration.lightingColor != lightingColor { return false }
        if lightingEffect.supportsBrightness, configuration.lightingBrightness != lightingBrightness { return false }
        if lightingEffect.supportsSpeed, configuration.lightingSpeed != lightingSpeed { return false }
        return true
    }

    var dpiSummary: String { dpis.map(String.init).joined(separator: " / ") }

    static let builtIns: [DevicePreset] = [
        .init(
            id: "tournament", name: "Tournament", detail: "Fast clicks, low lift and no lighting distraction.", symbol: "scope",
            dpis: [400, 800, 1600], activeStage: 1, pollingRate: .hz1000, debounce: 4, liftOffDistance: 2,
            lightingEffect: .off, lightingColor: .violet, lightingBrightness: 0, lightingSpeed: 0
        ),
        .init(
            id: "aim", name: "Aim training", detail: "A tighter four-stage ladder with a cool DPI-matched glow.", symbol: "target",
            dpis: [400, 800, 1200, 1600], activeStage: 1, pollingRate: .hz1000, debounce: 6, liftOffDistance: 2,
            lightingEffect: .single, lightingColor: StagePalette.color(at: 1), lightingBrightness: 4, lightingSpeed: 1
        ),
        .init(
            id: "daily", name: "Daily", detail: "Three practical stages and full-rate tracking.", symbol: "cursorarrow.motionlines",
            dpis: [800, 1600, 3200], activeStage: 1, pollingRate: .hz1000, debounce: 10, liftOffDistance: 2,
            lightingEffect: .glorious, lightingColor: .violet, lightingBrightness: 3, lightingSpeed: 1
        ),
        .init(
            id: "creator", name: "Creator", detail: "More desktop range with calmer USB traffic and a soft pulse.", symbol: "paintbrush.pointed",
            dpis: [800, 1200, 2400, 4800], activeStage: 1, pollingRate: .hz500, debounce: 10, liftOffDistance: 3,
            lightingEffect: .singleBreathing, lightingColor: .init(red: 137, green: 76, blue: 255), lightingBrightness: 3, lightingSpeed: 0
        ),
        .init(
            id: "locked", name: "One speed", detail: "Locks the mouse to one 800 DPI stage to prevent accidental switching.", symbol: "lock.fill",
            dpis: [800], activeStage: 0, pollingRate: .hz1000, debounce: 8, liftOffDistance: 2,
            lightingEffect: .single, lightingColor: StagePalette.color(at: 0), lightingBrightness: 2, lightingSpeed: 1
        )
    ]
}

enum StagePalette {
    static let colors: [MouseColor] = [
        .init(red: 255, green: 219, blue: 48),
        .init(red: 38, green: 220, blue: 255),
        .init(red: 137, green: 76, blue: 255),
        .init(red: 46, green: 235, blue: 99),
        .init(red: 255, green: 65, blue: 179),
        .init(red: 255, green: 255, blue: 255)
    ]

    static func color(at index: Int) -> MouseColor {
        colors[max(0, min(colors.count - 1, index))]
    }
}

struct ResponsePreset: Identifiable {
    let id: String
    let name: String
    let detail: String
    let pollingRate: PollingRate
    let debounce: Int
    let liftOffDistance: Int

    func apply(to configuration: inout MouseConfiguration) {
        configuration.pollingRate = pollingRate
        configuration.debounceMilliseconds = debounce
        configuration.liftOffDistanceMillimeters = liftOffDistance
    }

    func matches(_ configuration: MouseConfiguration) -> Bool {
        configuration.pollingRate == pollingRate &&
        configuration.debounceMilliseconds == debounce &&
        configuration.liftOffDistanceMillimeters == liftOffDistance
    }

    static let builtIns: [ResponsePreset] = [
        .init(id: "fast", name: "Fastest", detail: "1000 Hz · 4 ms · 2 mm", pollingRate: .hz1000, debounce: 4, liftOffDistance: 2),
        .init(id: "balanced", name: "Balanced", detail: "1000 Hz · 8 ms · 2 mm", pollingRate: .hz1000, debounce: 8, liftOffDistance: 2),
        .init(id: "shield", name: "Click shield", detail: "1000 Hz · 16 ms · 2 mm", pollingRate: .hz1000, debounce: 16, liftOffDistance: 2),
        .init(id: "high-lift", name: "High lift", detail: "1000 Hz · 10 ms · 3 mm", pollingRate: .hz1000, debounce: 10, liftOffDistance: 3),
        .init(id: "low-cpu", name: "Low CPU", detail: "250 Hz · 10 ms · 2 mm", pollingRate: .hz250, debounce: 10, liftOffDistance: 2)
    ]
}
