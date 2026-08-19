import Foundation
import XCTest
@testable import ModelOCore

final class ModelOCodecTests: XCTestCase {
    func testMacOSFeatureReportIncludesReportIDInBuffer() {
        let command = ModelOHIDReportFrame.make(reportID: 5, payload: [0x01, 0, 0, 0, 0])
        XCTAssertEqual(command, [0x05, 0x01, 0, 0, 0, 0])

        let config = ModelOHIDReportFrame.make(reportID: 4, payload: [UInt8](repeating: 0, count: 519))
        XCTAssertEqual(config.count, 520)
        XCTAssertEqual(config.first, 4)
    }

    func testButtonMapDecodeAndEncodeRoundTrip() throws {
        var raw = [UInt8](repeating: 0, count: 520)
        raw[0] = 0x04
        raw[1] = 0x12
        raw[6] = 0x06
        let bytes: [[UInt8]] = [
            [0x11, 0x01, 0, 0], [0x11, 0x02, 0, 0], [0x11, 0x04, 0, 0],
            [0x11, 0x08, 0, 0], [0x11, 0x10, 0, 0], [0x41, 0x00, 0, 0]
        ]
        for (index, action) in bytes.enumerated() {
            raw.replaceSubrange((8 + index * 4)..<(12 + index * 4), with: action)
        }

        var mapping = try ModelOButtonMappingCodec.decode(raw: raw)
        XCTAssertEqual(mapping.actions, [.leftClick, .rightClick, .middleClick, .back, .forward, .dpiCycle])
        mapping.actions[3] = .volumeDown
        mapping.actions[4] = .volumeUp

        let encoded = try ModelOButtonMappingCodec.encodeForWrite(mapping)
        XCTAssertEqual(encoded[3], 0x50)
        XCTAssertEqual(Array(encoded[20..<24]), [0x22, 0x80, 0x00, 0x00])
        XCTAssertEqual(Array(encoded[24..<28]), [0x22, 0x40, 0x00, 0x00])
        XCTAssertEqual(try ModelOButtonMappingCodec.decode(raw: encoded).actions, mapping.actions)
    }

    func testButtonMapPreservesUnknownAction() throws {
        var raw = [UInt8](repeating: 0, count: 520)
        raw[0] = 0x04
        raw[1] = 0x12
        raw[6] = 0x06
        for index in 0..<6 {
            raw.replaceSubrange((8 + index * 4)..<(12 + index * 4), with: [0x50, 0x01, 0, 0])
        }
        raw.replaceSubrange(8..<12, with: [0x70, 0x01, 0x04, 0x01])
        let mapping = try ModelOButtonMappingCodec.decode(raw: raw)
        XCTAssertEqual(mapping.actions[0], .unknown([0x70, 0x01, 0x04, 0x01]))
        XCTAssertEqual(Array(try ModelOButtonMappingCodec.encodeForWrite(mapping)[8..<12]), [0x70, 0x01, 0x04, 0x01])
    }

    func testMacroBankEncoding() throws {
        let events = [
            ModelOMacroEvent(state: .down, type: .modifier(0x08), delayMilliseconds: 15),
            ModelOMacroEvent(state: .down, type: .keyboard(0x06), delayMilliseconds: 35),
            ModelOMacroEvent(state: .up, type: .keyboard(0x06), delayMilliseconds: 15),
            ModelOMacroEvent(state: .up, type: .modifier(0x08), delayMilliseconds: 0)
        ]
        let raw = try ModelOMacroCodec.encode(bank: 1, events: events)
        XCTAssertEqual(Array(raw[0..<11]), [0x04, 0x30, 0x02, 0, 0, 0, 0, 0, 1, 0, 4])
        XCTAssertEqual(Array(raw[11..<14]), [0x60, 0x0F, 0x08])
        XCTAssertEqual(Array(raw[14..<17]), [0x50, 0x23, 0x06])
        XCTAssertEqual(Array(raw[17..<20]), [0xD0, 0x0F, 0x06])
        XCTAssertEqual(Array(raw[20..<23]), [0xE0, 0x00, 0x08])
    }

    func testDecodesKnownConfigurationLayout() throws {
        let config = try ModelOCodec.decode(raw: fixture(), firmware: "V110", debounceMilliseconds: 10)

        XCTAssertEqual(config.firmwareVersion, "V110")
        XCTAssertEqual(config.pollingRate, .hz1000)
        XCTAssertEqual(config.activeProfile, 1)
        XCTAssertEqual(config.profiles[0].dpi, 400)
        XCTAssertEqual(config.profiles[1].dpi, 800)
        XCTAssertTrue(config.profiles[0].enabled)
        XCTAssertFalse(config.profiles[2].enabled)
        XCTAssertEqual(config.lightingEffect, .single)
        XCTAssertEqual(config.lightingColor, MouseColor(red: 0xAA, green: 0xCC, blue: 0xBB))
        XCTAssertEqual(config.lightingBrightness, 4)
        XCTAssertEqual(config.debounceMilliseconds, 10)
        XCTAssertEqual(config.liftOffDistanceMillimeters, 2)
    }

    func testEncodesOnlyDocumentedFieldsAndWriteMagic() throws {
        var config = try ModelOCodec.decode(raw: fixture(), firmware: "V110", debounceMilliseconds: 10)
        config.pollingRate = .hz500
        config.profiles[0].dpi = 1600
        config.profiles[0].color = MouseColor(red: 1, green: 2, blue: 3)
        config.lightingEffect = .singleBreathing
        config.lightingColor = MouseColor(red: 9, green: 8, blue: 7)
        config.lightingSpeed = 2
        config.liftOffDistanceMillimeters = 3

        let encoded = try ModelOCodec.encodeForWrite(config)
        XCTAssertEqual(encoded.count, 520)
        XCTAssertEqual(encoded[3], 0x7B)
        XCTAssertEqual(encoded[10] & 0x0F, UInt8(PollingRate.hz500.rawValue))
        XCTAssertEqual(encoded[13], 15)
        XCTAssertEqual(Array(encoded[29...31]), [1, 2, 3])
        XCTAssertEqual(encoded[53], LightingEffect.singleBreathing.rawValue)
        XCTAssertEqual(encoded[125] & 0x0F, 2)
        XCTAssertEqual(Array(encoded[126...128]), [9, 7, 8])
        XCTAssertEqual(encoded[129], 2)
        XCTAssertEqual(encoded[200], 0xD7, "unknown bytes must be preserved")
    }

    func testActiveDPIStageUsesOneBasedWireNumbering() throws {
        var stageOneBytes = fixture()
        stageOneBytes[11] = 0x12
        var config = try ModelOCodec.decode(raw: stageOneBytes, firmware: "V110", debounceMilliseconds: 10)
        XCTAssertEqual(config.activeProfile, 0)

        config.profiles[2].enabled = true
        config.activeProfile = 2
        let encoded = try ModelOCodec.encodeForWrite(config)
        XCTAssertEqual(encoded[11] >> 4, 3, "app stage 3 must be encoded as controller stage 3")

        let decodedAgain = try ModelOCodec.decode(raw: encoded, firmware: "V110", debounceMilliseconds: 10)
        XCTAssertEqual(decodedAgain.activeProfile, 2)
    }

    func testRejectsDisablingEveryDPIStage() throws {
        var config = try ModelOCodec.decode(raw: fixture(), firmware: "V110", debounceMilliseconds: 10)
        for index in config.profiles.indices { config.profiles[index].enabled = false }
        XCTAssertThrowsError(try ModelOCodec.encodeForWrite(config)) { error in
            XCTAssertEqual(error as? ModelOCodecError, .noEnabledDPIProfile)
        }
    }

    func testLightingVerificationIgnoresUnrelatedActiveDPIChange() throws {
        let baseline = try ModelOCodec.decode(raw: fixture(), firmware: "V110", debounceMilliseconds: 10)
        var expected = baseline
        expected.lightingEffect = .singleBreathing
        expected.lightingColor = MouseColor(red: 255, green: 92, blue: 171)
        expected.lightingSpeed = 1

        var actual = expected
        actual.activeProfile = 0

        XCTAssertTrue(ModelOVerification.matches(actual: actual, expected: expected, changedFrom: baseline))
    }

    func testLightingVerificationIgnoresColourForSpectrumEffect() throws {
        let baseline = try ModelOCodec.decode(raw: fixture(), firmware: "V110", debounceMilliseconds: 10)
        var expected = baseline
        expected.lightingEffect = .glorious

        var actual = expected
        actual.lightingColor = MouseColor(red: 1, green: 2, blue: 3)

        XCTAssertTrue(ModelOVerification.matches(actual: actual, expected: expected, changedFrom: baseline))
    }

    func testLightingVerificationRejectsOwnedColourMismatch() throws {
        let baseline = try ModelOCodec.decode(raw: fixture(), firmware: "V110", debounceMilliseconds: 10)
        var expected = baseline
        expected.lightingEffect = .singleBreathing
        expected.lightingColor = MouseColor(red: 255, green: 92, blue: 171)

        var actual = expected
        actual.lightingColor = MouseColor(red: 45, green: 220, blue: 255)

        XCTAssertFalse(ModelOVerification.matches(actual: actual, expected: expected, changedFrom: baseline))
    }

    func testBackupRoundTrip() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let store = ModelOBackupStore(directory: temporary)
        let config = try ModelOCodec.decode(raw: fixture(), firmware: "V110", debounceMilliseconds: 10)
        let device = ModelODeviceInfo(productName: "Wired Gaming Mouse", manufacturer: "SINOWEALTH", vendorID: 0x258A, productID: 0x0036, locationID: 1)

        let saved = try store.save(device: device, configuration: config)
        let loaded = try XCTUnwrap(store.latest())
        XCTAssertEqual(loaded.id, saved.id)
        XCTAssertEqual(loaded.rawReport, config.rawReport)
        XCTAssertEqual(loaded.device.usbIdentifier, "258A:0036")
    }

    private func fixture() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 520)
        bytes[0] = 0x04
        bytes[1] = 0x11
        bytes[9] = 0x06
        bytes[10] = 0x04
        bytes[11] = 0x22
        bytes[12] = 0xFC
        bytes[13] = 3
        bytes[14] = 7
        bytes[15] = 15
        bytes[29] = 0xC0
        bytes[30] = 0x00
        bytes[31] = 0xC0
        bytes[53] = LightingEffect.single.rawValue
        bytes[56] = 0x40
        bytes[57] = 0xAA
        bytes[58] = 0xBB
        bytes[59] = 0xCC
        bytes[61] = 1
        bytes[129] = 1
        bytes[200] = 0xD7
        return bytes
    }
}
