import Foundation
import IOKit.hid

public enum ModelOHIDPermissionState: Sendable {
    case granted
    case denied
    case unknown
}

public struct ModelODeviceInfo: Codable, Hashable, Sendable {
    public var productName: String
    public var manufacturer: String
    public var vendorID: Int
    public var productID: Int
    public var locationID: Int

    public init(productName: String, manufacturer: String, vendorID: Int, productID: Int, locationID: Int) {
        self.productName = productName
        self.manufacturer = manufacturer
        self.vendorID = vendorID
        self.productID = productID
        self.locationID = locationID
    }

    public var usbIdentifier: String {
        String(format: "%04X:%04X", vendorID, productID)
    }
}

public struct ModelOSnapshot: Sendable {
    public var device: ModelODeviceInfo
    public var configuration: MouseConfiguration
    public var buttonMapping: ModelOButtonMapping

    public init(device: ModelODeviceInfo, configuration: MouseConfiguration, buttonMapping: ModelOButtonMapping) {
        self.device = device
        self.configuration = configuration
        self.buttonMapping = buttonMapping
    }
}

public enum ModelOHIDError: LocalizedError {
    case deviceNotFound
    case controlInterfaceNotFound
    case managerOpenFailed(IOReturn)
    case deviceOpenFailed(IOReturn)
    case setReportFailed(reportID: Int, result: IOReturn)
    case getReportFailed(reportID: Int, result: IOReturn)
    case invalidFirmwareResponse
    case invalidDebounceResponse

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound: "No original wired Model O was found. Connect USB device 258A:0036."
        case .controlInterfaceNotFound: "The mouse is connected, but its configuration interface is unavailable."
        case .managerOpenFailed(let result): "Could not open the macOS HID manager (0x\(String(UInt32(bitPattern: result), radix: 16)))."
        case .deviceOpenFailed(let result): "Could not open the mouse control interface (0x\(String(UInt32(bitPattern: result), radix: 16)))."
        case .setReportFailed(let reportID, let result): "Could not send feature report \(reportID) (0x\(String(UInt32(bitPattern: result), radix: 16)))."
        case .getReportFailed(let reportID, let result): "Could not read feature report \(reportID) (0x\(String(UInt32(bitPattern: result), radix: 16)))."
        case .invalidFirmwareResponse: "The mouse returned an invalid firmware response."
        case .invalidDebounceResponse: "The mouse returned an invalid debounce response."
        }
    }
}

enum ModelOHIDReportFrame {
    static func make(reportID: CFIndex, payload: [UInt8]) -> [UInt8] {
        [UInt8(reportID)] + payload
    }
}

public final class ModelOHIDConnection {
    public static let vendorID = 0x258A
    public static let productID = 0x0036

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?

    public init() {}

    public static var inputMonitoringPermission: ModelOHIDPermissionState {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: .granted
        case kIOHIDAccessTypeDenied: .denied
        default: .unknown
        }
    }

    @discardableResult
    public static func requestInputMonitoringPermission() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    deinit {
        close()
    }

    public func connectAndRead() throws -> ModelOSnapshot {
        try connectIfNeeded()
        guard let device else { throw ModelOHIDError.deviceNotFound }

        let firmware = try readFirmware(from: device)
        let debounce = try readDebounce(from: device)
        let raw = try readConfigurationReport(from: device)
        let configuration = try ModelOCodec.decode(raw: raw, firmware: firmware, debounceMilliseconds: debounce)
        let buttonRaw = try readButtonMappingReport(from: device)
        let buttonMapping = try ModelOButtonMappingCodec.decode(raw: buttonRaw)
        return ModelOSnapshot(device: info(for: device), configuration: configuration, buttonMapping: buttonMapping)
    }

    public func write(
        _ configuration: MouseConfiguration,
        comparedTo previous: MouseConfiguration,
        buttonMapping: ModelOButtonMapping? = nil,
        comparedToButtonMapping previousButtonMapping: ModelOButtonMapping? = nil
    ) throws {
        try connectIfNeeded()
        guard let device else { throw ModelOHIDError.deviceNotFound }

        if configuration.debounceMilliseconds != previous.debounceMilliseconds {
            try writeDebounce(configuration.debounceMilliseconds, to: device)
        }

        if let buttonMapping, let previousButtonMapping,
           buttonMapping.editableSignature != previousButtonMapping.editableSignature {
            let report = try ModelOButtonMappingCodec.encodeForWrite(buttonMapping)
            try setFeatureReport(on: device, reportID: 4, payload: Array(report.dropFirst()))
        }

        let desiredReport = try ModelOCodec.encodeForWrite(configuration)
        let previousReport = try ModelOCodec.encodeForWrite(previous)
        if desiredReport != previousReport {
            try setFeatureReport(on: device, reportID: 4, payload: Array(desiredReport.dropFirst()))
        }

        // Configuration writes can briefly restart the controller. Never verify
        // through the pre-write IOHID handle.
        close()
    }

    public func restore(
        rawReport: Data,
        debounceMilliseconds: Int,
        buttonMapping: ModelOButtonMapping? = nil
    ) throws {
        var report = [UInt8](rawReport)
        guard report.count >= MouseConfiguration.usedLength else {
            throw ModelOCodecError.reportTooShort(report.count)
        }
        guard report[0] == 4 else { throw ModelOCodecError.wrongReportID(report[0]) }
        guard report[1] == 0x11 else { throw ModelOCodecError.wrongCommand(report[1]) }
        if report.count < MouseConfiguration.reportLength {
            report.append(contentsOf: repeatElement(0, count: MouseConfiguration.reportLength - report.count))
        }
        report[3] = 0x7B

        try connectIfNeeded()
        guard let device else { throw ModelOHIDError.deviceNotFound }
        if let buttonMapping {
            let buttonReport = try ModelOButtonMappingCodec.encodeForWrite(buttonMapping)
            try setFeatureReport(on: device, reportID: 4, payload: Array(buttonReport.dropFirst()))
        }
        try setFeatureReport(on: device, reportID: 4, payload: Array(report.dropFirst().prefix(519)))
        try writeDebounce(debounceMilliseconds, to: device)
        close()
    }

    public func writeMacroBank(_ bank: Int, events: [ModelOMacroEvent]) throws {
        let report = try ModelOMacroCodec.encode(bank: bank, events: events)
        try connectIfNeeded()
        guard let device else { throw ModelOHIDError.deviceNotFound }
        try setFeatureReport(on: device, reportID: 4, payload: Array(report.dropFirst()))
        close()
    }

    public func close() {
        if let device {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
        manager = nil
    }

    private func connectIfNeeded() throws {
        if device != nil { return }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: Self.vendorID,
            kIOHIDProductIDKey as String: Self.productID
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard managerResult == kIOReturnSuccess else {
            throw ModelOHIDError.managerOpenFailed(managerResult)
        }
        self.manager = manager

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !devices.isEmpty else {
            close()
            throw ModelOHIDError.deviceNotFound
        }
        guard let control = devices.first(where: { intProperty($0, "MaxFeatureReportSize") >= 520 }) else {
            close()
            throw ModelOHIDError.controlInterfaceNotFound
        }

        let openResult = IOHIDDeviceOpen(control, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            close()
            throw ModelOHIDError.deviceOpenFailed(openResult)
        }
        device = control
    }

    private func readFirmware(from device: IOHIDDevice) throws -> String {
        try setFeatureReport(on: device, reportID: 5, payload: [0x01, 0, 0, 0, 0])
        let response = try getFeatureReport(from: device, reportID: 5, totalLength: 6)
        guard response.count >= 6, response[0] == 0x05, response[1] == 0x01 else {
            throw ModelOHIDError.invalidFirmwareResponse
        }
        let bytes = response[2...5]
        guard let version = String(bytes: bytes, encoding: .ascii) else {
            throw ModelOHIDError.invalidFirmwareResponse
        }
        return version
    }

    private func readDebounce(from device: IOHIDDevice) throws -> Int {
        try setFeatureReport(on: device, reportID: 5, payload: [0x1A, 0, 0, 0, 0])
        let response = try getFeatureReport(from: device, reportID: 5, totalLength: 6)
        guard response.count >= 3, response[0] == 0x05, response[1] == 0x1A else {
            throw ModelOHIDError.invalidDebounceResponse
        }
        return Int(response[2]) * 2
    }

    private func writeDebounce(_ milliseconds: Int, to device: IOHIDDevice) throws {
        guard (4...16).contains(milliseconds), milliseconds.isMultiple(of: 2) else {
            throw ModelOCodecError.invalidDebounce(milliseconds)
        }
        try setFeatureReport(on: device, reportID: 5, payload: [0x1A, UInt8(milliseconds / 2), 0, 0, 0])
    }

    private func readConfigurationReport(from device: IOHIDDevice) throws -> [UInt8] {
        try setFeatureReport(on: device, reportID: 5, payload: [0x11, 0, 0, 0, 0])
        var report = try getFeatureReport(from: device, reportID: 4, totalLength: 520)
        if report.count < MouseConfiguration.reportLength {
            report.append(contentsOf: repeatElement(0, count: MouseConfiguration.reportLength - report.count))
        }
        return report
    }

    private func readButtonMappingReport(from device: IOHIDDevice) throws -> [UInt8] {
        try setFeatureReport(on: device, reportID: 5, payload: [0x12, 0, 0, 0, 0])
        var report = try getFeatureReport(from: device, reportID: 4, totalLength: 520)
        if report.count < MouseConfiguration.reportLength {
            report.append(contentsOf: repeatElement(0, count: MouseConfiguration.reportLength - report.count))
        }
        return report
    }

    private func setFeatureReport(on device: IOHIDDevice, reportID: CFIndex, payload: [UInt8]) throws {
        let report = ModelOHIDReportFrame.make(reportID: reportID, payload: payload)
        let result = report.withUnsafeBytes { bytes in
            IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeFeature,
                reportID,
                bytes.bindMemory(to: UInt8.self).baseAddress!,
                report.count
            )
        }
        guard result == kIOReturnSuccess else {
            throw ModelOHIDError.setReportFailed(reportID: reportID, result: result)
        }
    }

    private func getFeatureReport(from device: IOHIDDevice, reportID: CFIndex, totalLength: Int) throws -> [UInt8] {
        var report = [UInt8](repeating: 0, count: totalLength)
        report[0] = UInt8(reportID)
        var length = totalLength
        let result = report.withUnsafeMutableBytes { bytes in
            IOHIDDeviceGetReport(
                device,
                kIOHIDReportTypeFeature,
                reportID,
                bytes.bindMemory(to: UInt8.self).baseAddress!,
                &length
            )
        }
        guard result == kIOReturnSuccess else {
            throw ModelOHIDError.getReportFailed(reportID: reportID, result: result)
        }
        return Array(report.prefix(length))
    }

    private func info(for device: IOHIDDevice) -> ModelODeviceInfo {
        ModelODeviceInfo(
            productName: stringProperty(device, kIOHIDProductKey as String) ?? "Wired Gaming Mouse",
            manufacturer: stringProperty(device, kIOHIDManufacturerKey as String) ?? "SINOWEALTH",
            vendorID: intProperty(device, kIOHIDVendorIDKey as String),
            productID: intProperty(device, kIOHIDProductIDKey as String),
            locationID: intProperty(device, kIOHIDLocationIDKey as String)
        )
    }

    private func intProperty(_ device: IOHIDDevice, _ key: String) -> Int {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else { return 0 }
        if let number = value as? NSNumber { return number.intValue }
        return 0
    }

    private func stringProperty(_ device: IOHIDDevice, _ key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }
}
