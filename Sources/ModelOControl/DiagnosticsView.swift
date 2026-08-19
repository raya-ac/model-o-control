import ModelOCore
import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var configuration: MouseConfiguration

    var body: some View {
        PageScaffold(
            title: "Diagnostics",
            subtitle: "Read-only checks for the connected mouse, current report and recovery state."
        ) {
            SettingSection("Device checks", detail: overallStatus) {
                VStack(spacing: 0) {
                    DiagnosticRow(label: "USB connection", value: model.device?.usbIdentifier ?? "258A:0036", state: .pass)
                    Divider()
                    DiagnosticRow(label: "Firmware", value: configuration.firmwareVersion, state: .pass)
                    Divider()
                    DiagnosticRow(label: "Configuration report", value: "\(configuration.rawReport.count) bytes", state: reportState)
                    Divider()
                    DiagnosticRow(label: "Editable values", value: validationText, state: validationState)
                    Divider()
                    DiagnosticRow(label: "Active DPI stage", value: activeStageText, state: activeStageState)
                }
            }

            SettingSection("Recovery state") {
                HStack(spacing: 36) {
                    DiagnosticMetric(value: "\(model.backups.count)", label: "Raw backups")
                    DiagnosticMetric(value: "\(model.savedProfiles.count)", label: "Saved profiles")
                    DiagnosticMetric(value: latestBackupText, label: "Latest backup")
                    DiagnosticMetric(value: "\(configuration.profiles.prefix(6).filter(\.enabled).count)", label: "Enabled stages")
                }
            }

            SettingSection("Current configuration") {
                VStack(spacing: 0) {
                    DiagnosticFact(label: "Polling", value: "\(configuration.pollingRate.hertz) Hz")
                    Divider()
                    DiagnosticFact(label: "Debounce", value: "\(configuration.debounceMilliseconds) ms")
                    Divider()
                    DiagnosticFact(label: "Lift-off", value: "\(configuration.liftOffDistanceMillimeters) mm")
                    Divider()
                    DiagnosticFact(label: "Lighting", value: configuration.lightingEffect.title)
                }
            }

            SettingSection("Raw report inspector", detail: "First 64 of \(configuration.rawReport.count) bytes") {
                Text(rawPreview)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Button {
                    model.copyRawReportHex()
                } label: {
                    Label("Copy all 520 bytes", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                Button {
                    model.refresh()
                } label: {
                    Label("Read mouse again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    model.copyDiagnosticReport()
                } label: {
                    Label("Copy diagnostic report", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)

                Spacer()
                Text("No persistent reports are sent from this page")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var validationError: Error? {
        do {
            try ModelOCodec.validate(configuration)
            return nil
        } catch {
            return error
        }
    }

    private var validationText: String { validationError?.localizedDescription ?? "Valid" }
    private var validationState: DiagnosticState { validationError == nil ? .pass : .fail }
    private var reportState: DiagnosticState { configuration.rawReport.count == MouseConfiguration.reportLength ? .pass : .fail }

    private var activeStageState: DiagnosticState {
        configuration.profiles.prefix(6).contains { $0.id == configuration.activeProfile && $0.enabled } ? .pass : .fail
    }

    private var activeStageText: String {
        guard let profile = configuration.profiles.first(where: { $0.id == configuration.activeProfile }) else { return "Missing" }
        return "Stage \(profile.id + 1) · \(profile.dpi) DPI"
    }

    private var latestBackupText: String {
        guard let backup = model.latestBackup else { return "None" }
        return backup.createdAt.formatted(.relative(presentation: .numeric))
    }

    private var overallStatus: String {
        validationState == .pass && reportState == .pass && activeStageState == .pass ? "All checks passed" : "Needs attention"
    }

    private var rawPreview: String {
        let bytes = Array([UInt8](configuration.rawReport).prefix(64))
        return stride(from: 0, to: bytes.count, by: 16).map { offset in
            let line = bytes[offset..<min(offset + 16, bytes.count)]
                .map { String(format: "%02X", $0) }
                .joined(separator: " ")
            return String(format: "%04X  ", offset) + line
        }.joined(separator: "\n")
    }
}

private enum DiagnosticState { case pass, fail }

private struct DiagnosticRow: View {
    let label: String
    let value: String
    let state: DiagnosticState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state == .pass ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(state == .pass ? Color.green : Color.orange)
            Text(label)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 10)
    }
}

private struct DiagnosticFact: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .padding(.vertical, 10)
    }
}

private struct DiagnosticMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
