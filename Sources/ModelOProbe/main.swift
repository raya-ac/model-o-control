import Foundation
import ModelOCore

do {
    let connection = ModelOHIDConnection()
    let snapshot = try connection.connectAndRead()
    let config = snapshot.configuration
    print("Model O detected")
    print("USB: \(snapshot.device.usbIdentifier)")
    print("Product: \(snapshot.device.productName)")
    print("Firmware: \(config.firmwareVersion)")
    print("Polling: \(config.pollingRate.hertz) Hz")
    print("Debounce: \(config.debounceMilliseconds) ms")
    print("Lift-off distance: \(config.liftOffDistanceMillimeters) mm")
    print("Lighting: \(config.lightingEffect.title)")
    for profile in config.profiles.prefix(6) {
        let marker = profile.enabled ? "on " : "off"
        print("DPI \(profile.id + 1): \(marker) \(profile.dpi)")
    }
} catch {
    fputs("modelo-probe: \(error.localizedDescription)\n", stderr)
    exit(1)
}
