import AppKit
import Foundation
import ModelOCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    enum ConnectionState: Equatable {
        case scanning
        case permissionRequired
        case connected
        case disconnected
        case failed(String)
    }

    @Published var connectionState: ConnectionState = .scanning
    @Published var device: ModelODeviceInfo?
    @Published var baseline: MouseConfiguration?
    @Published var editing: MouseConfiguration?
    @Published var baselineButtons: ModelOButtonMapping?
    @Published var editingButtons: ModelOButtonMapping?
    @Published var backups: [ModelOBackup] = []
    @Published var savedProfiles: [SavedDeviceProfile] = []
    @Published var savedLightingLooks: [SavedLightingLook] = []
    @Published var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    @Published var appRulesEnabled = UserDefaults.standard.bool(forKey: "AppRulesEnabled")
    @Published var appRules: [AppProfileRule] = []
    @Published var runningApps: [RunningAppChoice] = []
    @Published var connectionActivity: [ConnectionActivity] = []
    @Published var isApplying = false
    @Published var notice: String?
    @Published var showsApplyConfirmation = false
    @Published var showsRestoreConfirmation = false

    private let connection = ModelOHIDConnection()
    private let backupStore = ModelOBackupStore()
    private let savedProfileStore = SavedProfileStore()
    private let savedLightingStore = SavedLightingStore()
    private var hasStarted = false
    private var appActivationObserver: NSObjectProtocol?

    var hasChanges: Bool {
        guard let baseline, let editing else { return false }
        let buttonsChanged = baselineButtons?.editableSignature != editingButtons?.editableSignature
        return baseline.editableSignature != editing.editableSignature || buttonsChanged
    }

    var latestBackup: ModelOBackup? { backups.first }

    var menuBarStatus: String {
        switch connectionState {
        case .connected: "Model O connected"
        case .scanning: "Scanning for Model O"
        case .permissionRequired: "Input Monitoring required"
        case .disconnected: "Model O disconnected"
        case .failed: "Model O read error"
        }
    }

    var changeSummary: [String] {
        guard let baseline, let editing else { return [] }
        var changes: [String] = []
        if Array(baseline.profiles.prefix(6)) != Array(editing.profiles.prefix(6)) {
            changes.append("DPI profiles")
        }
        if baseline.pollingRate != editing.pollingRate { changes.append("Polling rate") }
        if baseline.lightingEffect != editing.lightingEffect ||
            baseline.lightingColor != editing.lightingColor ||
            baseline.lightingBrightness != editing.lightingBrightness ||
            baseline.lightingSpeed != editing.lightingSpeed {
            changes.append("Lighting")
        }
        if baseline.debounceMilliseconds != editing.debounceMilliseconds { changes.append("Debounce") }
        if baseline.liftOffDistanceMillimeters != editing.liftOffDistanceMillimeters { changes.append("Lift-off distance") }
        if baselineButtons?.editableSignature != editingButtons?.editableSignature { changes.append("Button assignments") }
        return changes
    }

    var changeDetails: [String] {
        guard let baseline, let editing else { return [] }
        var details: [String] = []
        let oldStages = baseline.profiles.prefix(6).filter(\.enabled).map { String($0.dpi) }.joined(separator: " / ")
        let newStages = editing.profiles.prefix(6).filter(\.enabled).map { String($0.dpi) }.joined(separator: " / ")
        if Array(baseline.profiles.prefix(6)) != Array(editing.profiles.prefix(6)) {
            details.append("DPI stages: \(oldStages) → \(newStages)")
        }
        if baseline.activeProfile != editing.activeProfile {
            details.append("Active stage: \(baseline.activeProfile + 1) → \(editing.activeProfile + 1)")
        }
        if baseline.pollingRate != editing.pollingRate {
            details.append("Polling: \(baseline.pollingRate.hertz) → \(editing.pollingRate.hertz) Hz")
        }
        if baseline.lightingEffect != editing.lightingEffect {
            details.append("Lighting: \(baseline.lightingEffect.title) → \(editing.lightingEffect.title)")
        }
        if editing.lightingEffect.supportsPrimaryColor,
           baseline.lightingColor != editing.lightingColor {
            details.append("Lighting colour: \(baseline.lightingColor.hexDescription) → \(editing.lightingColor.hexDescription)")
        }
        if editing.lightingEffect.supportsBrightness,
           baseline.lightingBrightness != editing.lightingBrightness {
            details.append("Brightness: \(baseline.lightingBrightness) → \(editing.lightingBrightness)")
        }
        if editing.lightingEffect.supportsSpeed,
           baseline.lightingSpeed != editing.lightingSpeed {
            details.append("Speed: \(baseline.lightingSpeed) → \(editing.lightingSpeed)")
        }
        if baseline.debounceMilliseconds != editing.debounceMilliseconds {
            details.append("Debounce: \(baseline.debounceMilliseconds) → \(editing.debounceMilliseconds) ms")
        }
        if baseline.liftOffDistanceMillimeters != editing.liftOffDistanceMillimeters {
            details.append("Lift-off: \(baseline.liftOffDistanceMillimeters) → \(editing.liftOffDistanceMillimeters) mm")
        }
        if let baselineButtons, let editingButtons {
            for index in 0..<min(6, min(baselineButtons.actions.count, editingButtons.actions.count))
            where baselineButtons.actions[index] != editingButtons.actions[index] {
                details.append("Button \(index + 1): \(baselineButtons.actions[index].title) → \(editingButtons.actions[index].title)")
            }
        }
        return details
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        loadBackups()
        loadSavedProfiles()
        loadSavedLightingLooks()
        loadAppRules()
        startAppRuleObserver()
        refresh()
    }

    func refresh(silent: Bool = false) {
        guard !isApplying else { return }
        if !silent { connectionState = .scanning }
        do {
            let snapshot = try connection.connectAndRead()
            device = snapshot.device
            baseline = snapshot.configuration
            baselineButtons = snapshot.buttonMapping
            if !hasChanges || editing == nil {
                editing = snapshot.configuration
                editingButtons = snapshot.buttonMapping
            }
            connectionState = .connected
            recordConnection("Read firmware, configuration and button map", success: true)
        } catch let error as ModelOHIDError {
            connection.close()
            if case .managerOpenFailed(let result) = error, result == kIOReturnNotPermitted {
                connectionState = .permissionRequired
            } else if case .deviceOpenFailed(let result) = error, result == kIOReturnNotPermitted {
                connectionState = .permissionRequired
            } else if case .deviceNotFound = error {
                connectionState = .disconnected
            } else {
                connectionState = .failed(error.localizedDescription)
            }
            recordConnection(error.localizedDescription, success: false)
        } catch {
            connection.close()
            connectionState = .failed(error.localizedDescription)
            recordConnection(error.localizedDescription, success: false)
        }
    }

    func requestPermission() {
        _ = ModelOHIDConnection.requestInputMonitoringPermission()
        if ModelOHIDConnection.inputMonitoringPermission == .granted {
            refresh()
        } else {
            notice = "Allow Model O Control in Privacy & Security → Input Monitoring, then quit and reopen the app."
        }
    }

    func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    func discardChanges() {
        editing = baseline
        editingButtons = baselineButtons
    }

    func applyChanges() {
        guard let device, let baseline, let editing, let baselineButtons, let editingButtons else { return }
        isApplying = true
        notice = nil
        var attemptedPersistentWrite = false
        defer { isApplying = false }
        do {
            try ModelOCodec.validate(editing)
            _ = try backupStore.save(device: device, configuration: baseline, buttonMapping: baselineButtons)
            attemptedPersistentWrite = true
            try connection.write(
                editing,
                comparedTo: baseline,
                buttonMapping: editingButtons,
                comparedToButtonMapping: baselineButtons
            )
            let verified = try verifyAfterWrite(
                expected: editing,
                changedFrom: baseline,
                expectedButtons: editingButtons,
                changedFromButtons: baselineButtons
            )
            self.device = verified.device
            self.baseline = verified.configuration
            self.editing = verified.configuration
            self.baselineButtons = verified.buttonMapping
            self.editingButtons = verified.buttonMapping
            self.connectionState = .connected
            loadBackups()
            notice = "Settings applied and verified. The previous onboard configuration was backed up first."
        } catch {
            if attemptedPersistentWrite {
                notice = "The mouse may have accepted settings before verification failed. Its previous raw configuration was backed up first. Error: \(error.localizedDescription)"
            } else {
                notice = "No persistent configuration report was sent. Error: \(error.localizedDescription)"
            }
            refresh(silent: true)
        }
    }

    func restoreLatestBackup() {
        guard let backup = latestBackup else { return }
        isApplying = true
        notice = nil
        defer { isApplying = false }
        do {
            try backup.validate()
            if let device, let baseline {
                _ = try backupStore.save(device: device, configuration: baseline, buttonMapping: baselineButtons)
            }
            try connection.restore(
                rawReport: backup.rawReport,
                debounceMilliseconds: backup.debounceMilliseconds,
                buttonMapping: backup.buttonMapping
            )
            let verified = try connection.connectAndRead()
            self.device = verified.device
            self.baseline = verified.configuration
            self.editing = verified.configuration
            self.baselineButtons = verified.buttonMapping
            self.editingButtons = verified.buttonMapping
            self.connectionState = .connected
            loadBackups()
            notice = "Backup restored and read back from the mouse."
        } catch {
            notice = "Restore stopped: \(error.localizedDescription)"
        }
    }

    func revealBackups() {
        try? FileManager.default.createDirectory(at: backupStore.directory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([backupStore.directory])
    }

    func createRecoveryPoint() {
        guard let device, let baseline else { return }
        do {
            _ = try backupStore.save(device: device, configuration: baseline, buttonMapping: baselineButtons)
            loadBackups()
            notice = "Saved a raw recovery point without writing to the mouse."
        } catch {
            notice = "Couldn’t create the recovery point: \(error.localizedDescription)"
        }
    }

    func compareLatestBackup() {
        guard let latestBackup, let baseline else {
            notice = "There isn’t a backup to compare yet."
            return
        }
        var differences: [String] = []
        if latestBackup.rawReport != baseline.rawReport { differences.append("configuration report") }
        if latestBackup.debounceMilliseconds != baseline.debounceMilliseconds { differences.append("debounce") }
        if let backedButtons = latestBackup.buttonMapping,
           backedButtons.editableSignature != baselineButtons?.editableSignature {
            differences.append("button assignments")
        }
        notice = differences.isEmpty
            ? "The current onboard state matches the latest backup."
            : "Changed since the latest backup: \(differences.joined(separator: ", "))."
    }

    func copyRawReportHex() {
        guard let baseline else { return }
        let hex = [UInt8](baseline.rawReport).enumerated().map { index, byte in
            let prefix = index.isMultiple(of: 16) ? String(format: "%04X: ", index) : ""
            let suffix = (index + 1).isMultiple(of: 16) ? "\n" : " "
            return prefix + String(format: "%02X", byte) + suffix
        }.joined()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
        notice = "Copied the full 520-byte configuration report as hex."
    }

    func exportLatestBackup() {
        guard let latestBackup else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Model O Backup.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(latestBackup).write(to: url, options: .atomic)
        } catch {
            notice = "Couldn’t export the backup: \(error.localizedDescription)"
        }
    }

    func saveCurrentProfile() {
        guard let editing else { return }
        do {
            let saved = try savedProfileStore.save(configuration: editing)
            loadSavedProfiles()
            notice = "Saved \(saved.name) locally."
        } catch {
            notice = "Couldn’t save the profile: \(error.localizedDescription)"
        }
    }

    func loadSavedProfile(_ profile: SavedDeviceProfile) {
        guard var draft = editing else { return }
        profile.apply(to: &draft)
        editing = draft
    }

    func deleteSavedProfile(_ profile: SavedDeviceProfile) {
        do {
            try savedProfileStore.delete(id: profile.id)
            loadSavedProfiles()
        } catch {
            notice = "Couldn’t delete the profile: \(error.localizedDescription)"
        }
    }

    func renameSavedProfile(_ profile: SavedDeviceProfile, to name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try savedProfileStore.rename(id: profile.id, to: name)
            loadSavedProfiles()
        } catch {
            notice = "Couldn’t rename the profile: \(error.localizedDescription)"
        }
    }

    func toggleFavoriteProfile(_ profile: SavedDeviceProfile) {
        do {
            try savedProfileStore.toggleFavorite(id: profile.id)
            loadSavedProfiles()
        } catch {
            notice = "Couldn’t update the favourite: \(error.localizedDescription)"
        }
    }

    func duplicateSavedProfile(_ profile: SavedDeviceProfile) {
        do {
            try savedProfileStore.duplicate(id: profile.id)
            loadSavedProfiles()
        } catch {
            notice = "Couldn’t duplicate the profile: \(error.localizedDescription)"
        }
    }

    func exportSavedProfiles() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Model O Profiles.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try savedProfileStore.exportData().write(to: url, options: .atomic)
        } catch {
            notice = "Couldn’t export profiles: \(error.localizedDescription)"
        }
    }

    func importSavedProfiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try savedProfileStore.importData(Data(contentsOf: url))
            loadSavedProfiles()
        } catch {
            notice = "Couldn’t import profiles: \(error.localizedDescription)"
        }
    }

    func revealSavedProfiles() {
        let folder = savedProfileStore.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    func saveCurrentLightingLook() {
        guard let editing else { return }
        do {
            try savedLightingStore.save(configuration: editing)
            loadSavedLightingLooks()
        } catch {
            notice = "Couldn’t save the lighting look: \(error.localizedDescription)"
        }
    }

    func loadLightingLook(_ look: SavedLightingLook) {
        guard var draft = editing else { return }
        look.apply(to: &draft)
        editing = draft
    }

    func deleteLightingLook(_ look: SavedLightingLook) {
        do {
            try savedLightingStore.delete(id: look.id)
            loadSavedLightingLooks()
        } catch {
            notice = "Couldn’t delete the lighting look: \(error.localizedDescription)"
        }
    }

    func copySetupSummary() {
        guard let configuration = editing else { return }
        let enabled = configuration.profiles.prefix(6).filter(\.enabled)
            .map { "Stage \($0.id + 1): \($0.dpi) DPI \($0.color.hexDescription)" }
            .joined(separator: "\n")
        let activeDPI = configuration.profiles.first(where: { $0.id == configuration.activeProfile })?.dpi ?? 0
        let text = """
        Model O Control setup
        Device: \(device?.usbIdentifier ?? "258A:0036") · firmware \(configuration.firmwareVersion)
        Active: Stage \(configuration.activeProfile + 1) · \(activeDPI) DPI
        \(enabled)
        Polling: \(configuration.pollingRate.hertz) Hz
        Debounce: \(configuration.debounceMilliseconds) ms
        Lift-off: \(configuration.liftOffDistanceMillimeters) mm
        Lighting: \(configuration.lightingEffect.title) · \(configuration.lightingColor.hexDescription)
        Backups: \(backups.count)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        notice = "Setup summary copied to the clipboard."
    }

    func copyDiagnosticReport() {
        guard let configuration = editing else { return }
        let validation: String
        do {
            try ModelOCodec.validate(configuration)
            validation = "passed"
        } catch {
            validation = "failed: \(error.localizedDescription)"
        }
        let activeDPI = configuration.profiles.first(where: { $0.id == configuration.activeProfile })?.dpi ?? 0
        let latestBackup = latestBackup?.createdAt.formatted(date: .abbreviated, time: .standard) ?? "none"
        let text = """
        Model O Control diagnostic report
        Device: \(device?.productName ?? "Wired Gaming Mouse")
        USB: \(device?.usbIdentifier ?? "258A:0036")
        Firmware: \(configuration.firmwareVersion)
        Configuration report: \(configuration.rawReport.count) bytes
        Validation: \(validation)
        Active stage: \(configuration.activeProfile + 1) · \(activeDPI) DPI
        Enabled stages: \(configuration.profiles.prefix(6).filter(\.enabled).count)
        Polling: \(configuration.pollingRate.hertz) Hz
        Debounce: \(configuration.debounceMilliseconds) ms
        Lift-off: \(configuration.liftOffDistanceMillimeters) mm
        Lighting: \(configuration.lightingEffect.title)
        Raw backups: \(backups.count) · latest \(latestBackup)
        Saved profiles: \(savedProfiles.count)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        notice = "Diagnostic report copied to the clipboard."
    }

    func programMacro(bank: Int, preset: ModelOMacroPreset) {
        isApplying = true
        defer { isApplying = false }
        do {
            try connection.writeMacroBank(bank, events: preset.events)
            notice = "Programmed macro bank \(bank) with \(preset.name). Assign the bank from Buttons, then Review & Apply."
        } catch {
            notice = "Macro write failed: \(error.localizedDescription)"
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            notice = "Couldn’t change launch-at-login: \(error.localizedDescription)"
        }
    }

    func setAppRulesEnabled(_ enabled: Bool) {
        appRulesEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "AppRulesEnabled")
    }

    func refreshRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular,
                  let bundle = app.bundleIdentifier,
                  bundle != Bundle.main.bundleIdentifier else { return nil }
            return RunningAppChoice(id: bundle, name: app.localizedName ?? bundle)
        }
        .reduce(into: [String: RunningAppChoice]()) { $0[$1.id] = $1 }
        .values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addAppRule(bundleIdentifier: String, profileID: UUID?) {
        guard let profileID,
              let app = runningApps.first(where: { $0.id == bundleIdentifier }) else { return }
        appRules.removeAll { $0.bundleIdentifier == bundleIdentifier }
        appRules.append(AppProfileRule(appName: app.name, bundleIdentifier: bundleIdentifier, profileID: profileID))
        saveAppRules()
    }

    func deleteAppRule(_ rule: AppProfileRule) {
        appRules.removeAll { $0.id == rule.id }
        saveAppRules()
    }

    private func loadBackups() {
        backups = (try? backupStore.all()) ?? []
    }

    private func loadSavedProfiles() {
        savedProfiles = (try? savedProfileStore.all()) ?? []
    }

    private func loadSavedLightingLooks() {
        savedLightingLooks = (try? savedLightingStore.all()) ?? []
    }

    private func recordConnection(_ text: String, success: Bool) {
        connectionActivity.insert(ConnectionActivity(date: Date(), text: text, success: success), at: 0)
        if connectionActivity.count > 30 { connectionActivity.removeLast(connectionActivity.count - 30) }
    }

    private func loadAppRules() {
        guard let data = UserDefaults.standard.data(forKey: "AppProfileRules") else { return }
        appRules = (try? JSONDecoder().decode([AppProfileRule].self, from: data)) ?? []
    }

    private func saveAppRules() {
        UserDefaults.standard.set(try? JSONEncoder().encode(appRules), forKey: "AppProfileRules")
    }

    private func startAppRuleObserver() {
        guard appActivationObserver == nil else { return }
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundle = app.bundleIdentifier else { return }
            Task { @MainActor [weak self] in self?.handleActivatedApplication(bundle) }
        }
    }

    private func handleActivatedApplication(_ bundleIdentifier: String) {
        guard appRulesEnabled,
              let rule = appRules.first(where: { $0.bundleIdentifier == bundleIdentifier }),
              let profile = savedProfiles.first(where: { $0.id == rule.profileID }) else { return }
        loadSavedProfile(profile)
        connectionActivity.insert(ConnectionActivity(date: Date(), text: "Staged \(profile.name) for \(rule.appName)", success: true), at: 0)
    }

    private func verifyAfterWrite(
        expected: MouseConfiguration,
        changedFrom baseline: MouseConfiguration,
        expectedButtons: ModelOButtonMapping,
        changedFromButtons baselineButtons: ModelOButtonMapping
    ) throws -> ModelOSnapshot {
        var lastError: Error = ApplyError.verificationFailed
        for attempt in 0..<5 {
            Thread.sleep(forTimeInterval: 0.3 + (Double(attempt) * 0.2))
            connection.close()
            do {
                let snapshot = try connection.connectAndRead()
                guard ModelOVerification.matches(
                    actual: snapshot.configuration,
                    expected: expected,
                    changedFrom: baseline
                ) else {
                    lastError = ApplyError.verificationFailed
                    continue
                }
                if expectedButtons.editableSignature != baselineButtons.editableSignature,
                   snapshot.buttonMapping.editableSignature != expectedButtons.editableSignature {
                    lastError = ApplyError.verificationFailed
                    continue
                }
                return snapshot
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}

private extension MouseColor {
    var hexDescription: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}

private enum ApplyError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        "The mouse accepted the write, but its read-back did not match. The previous configuration is available in Backups."
    }
}
