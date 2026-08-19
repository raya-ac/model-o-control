import AppKit
import ModelOCore
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case device = "Device"
    case profiles = "Profiles"
    case buttons = "Buttons"
    case macros = "Macros"
    case tester = "Tester"
    case diagnostics = "Diagnostics"
    case automation = "Automation"
    case sensitivity = "Sensitivity"
    case lighting = "Lighting"
    case advanced = "Advanced"
    case backups = "Backups"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .device: "computermouse"
        case .profiles: "square.stack.3d.up"
        case .buttons: "button.programmable"
        case .macros: "command.square"
        case .tester: "waveform.path.ecg"
        case .diagnostics: "checkmark.shield"
        case .automation: "bolt.badge.clock"
        case .sensitivity: "scope"
        case .lighting: "lightbulb"
        case .advanced: "slider.horizontal.3"
        case .backups: "clock.arrow.circlepath"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: AppSection? = .device

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 228, max: 250)
        } detail: {
            detail
                .background(Color(nsColor: .windowBackgroundColor))
                .overlay(alignment: .bottom) {
                    if model.connectionState == .connected, model.hasChanges {
                        ApplyBar()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.snappy(duration: 0.28), value: model.hasChanges)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Color(red: 0.49, green: 0.36, blue: 1.0))
        .sheet(isPresented: $model.showsApplyConfirmation) {
            ApplyConfirmationView()
                .environmentObject(model)
        }
        .sheet(isPresented: $model.showsRestoreConfirmation) {
            RestoreConfirmationView()
                .environmentObject(model)
        }
        .alert("Model O Control", isPresented: Binding(
            get: { model.notice != nil },
            set: { if !$0 { model.notice = nil } }
        )) {
            Button("OK") { model.notice = nil }
        } message: {
            Text(model.notice ?? "")
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Group {
                    if let icon = SidebarIconAsset.image {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentColor.opacity(0.14))
                            Image(systemName: "computermouse.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MODEL O")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(1.2)
                    Text("CONTROL")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(1.8)
                }
                Spacer()
            }
            .padding(.horizontal, 17)
            .padding(.top, 26)
            .padding(.bottom, 18)

            List(AppSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .tag(section)
                    .padding(.vertical, 3)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            SidebarStatus()
                .padding(16)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var detail: some View {
        switch model.connectionState {
        case .scanning:
            StateView(
                symbol: "dot.radiowaves.left.and.right",
                title: "Looking for Model O",
                message: "Reading the wired mouse on USB 258A:0036.",
                actionTitle: nil,
                action: nil
            )
        case .permissionRequired:
            PermissionView()
        case .disconnected:
            StateView(
                symbol: "cable.connector.slash",
                title: "Connect the wired Model O",
                message: "This build supports the original Model O/O− at USB 258A:0036.",
                actionTitle: "Scan again",
                action: { model.refresh() }
            )
        case .failed(let message):
            StateView(
                symbol: "exclamationmark.triangle",
                title: "Couldn’t read the mouse",
                message: message,
                actionTitle: "Try again",
                action: { model.refresh() }
            )
        case .connected:
            if model.editing != nil, model.editingButtons != nil {
                let configuration = Binding<MouseConfiguration>(
                    get: { model.editing! },
                    set: { model.editing = $0 }
                )
                let buttonMapping = Binding<ModelOButtonMapping>(
                    get: { model.editingButtons! },
                    set: { model.editingButtons = $0 }
                )
                Group {
                    switch selection ?? .device {
                    case .device: DeviceView(configuration: configuration)
                    case .profiles: ProfilesView(configuration: configuration)
                    case .buttons: ButtonsView(mapping: buttonMapping)
                    case .macros: MacrosView()
                    case .tester: MouseTesterView()
                    case .diagnostics: DiagnosticsView(configuration: configuration)
                    case .automation: AutomationView()
                    case .sensitivity: SensitivityView(configuration: configuration)
                    case .lighting: LightingView(configuration: configuration)
                    case .advanced: AdvancedView(configuration: configuration)
                    case .backups: BackupsView()
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

private enum SidebarIconAsset {
    static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "model-o-sidebar-icon", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()
}

struct SidebarStatus: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.5), radius: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 12, weight: .semibold))
                if let device = model.device {
                    Text(device.usbIdentifier)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Read from mouse")
        }
    }

    private var statusTitle: String {
        switch model.connectionState {
        case .connected: "Connected"
        case .permissionRequired: "Permission needed"
        case .scanning: "Scanning"
        case .disconnected: "Not connected"
        case .failed: "Read error"
        }
    }

    private var statusColor: Color {
        switch model.connectionState {
        case .connected: .green
        case .scanning: .yellow
        case .permissionRequired: .orange
        case .disconnected, .failed: .secondary
        }
    }
}

struct StateView: View {
    var symbol: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating.speed(0.45), isActive: actionTitle == nil)
            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct PermissionView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            HStack(alignment: .top, spacing: 32) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 128, height: 128)
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 13) {
                    Text("One macOS permission")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text("The Model O exposes its configuration channel as a keyboard-capable HID interface. macOS therefore requires Input Monitoring before this app can read or write its onboard settings.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Model O Control does not record keystrokes. It matches only USB 258A:0036 and communicates through feature reports.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    HStack(spacing: 10) {
                        Button("Allow Input Monitoring") { model.requestPermission() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        Button("Open Settings") { model.openInputMonitoringSettings() }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: 510, alignment: .leading)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(54)
    }
}

struct ApplyBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(Color.accentColor)
            Text("Local changes not yet written")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button("Discard") { model.discardChanges() }
                .buttonStyle(.borderless)
            Button("Review & Apply") { model.showsApplyConfirmation = true }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(.thickMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

struct ApplyConfirmationView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "arrow.down.to.line.compact")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 6) {
                Text("Write to onboard memory?")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text("The current raw configuration will be backed up before any persistent report is sent.")
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(model.changeDetails, id: \.self) { item in
                    Label(item, systemImage: "checkmark")
                }
            }
            .font(.system(size: 13, weight: .medium))
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Back Up & Apply") {
                    dismiss()
                    model.applyChanges()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 430)
    }
}

struct RestoreConfirmationView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)
            Text("Restore the latest backup?")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            if let backup = model.latestBackup {
                Text("This restores the raw onboard report saved \(backup.createdAt.formatted(date: .abbreviated, time: .shortened)). Your current configuration will be backed up first.")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Restore Backup") {
                    dismiss()
                    model.restoreLatestBackup()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 430)
    }
}
