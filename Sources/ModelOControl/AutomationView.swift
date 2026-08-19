import AppKit
import SwiftUI

struct AppProfileRule: Codable, Identifiable, Hashable {
    let id: UUID
    let appName: String
    let bundleIdentifier: String
    let profileID: UUID

    init(appName: String, bundleIdentifier: String, profileID: UUID) {
        id = UUID()
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.profileID = profileID
    }
}

struct ConnectionActivity: Identifiable {
    let id = UUID()
    let date: Date
    let text: String
    let success: Bool
}

struct RunningAppChoice: Identifiable, Hashable {
    let id: String
    let name: String
}

struct AutomationView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedAppID = ""
    @State private var selectedProfileID: UUID?

    var body: some View {
        PageScaffold(
            title: "Automation",
            subtitle: "Quick access and optional app-aware profile staging."
        ) {
            SettingSection("Startup and menu bar") {
                Toggle("Launch Model O Control at login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
                Toggle("Stage per-app profile rules", isOn: Binding(
                    get: { model.appRulesEnabled },
                    set: { model.setAppRulesEnabled($0) }
                ))
                HStack(spacing: 10) {
                    Image(systemName: "menubar.rectangle")
                        .foregroundStyle(Color.accentColor)
                    Text("The menu-bar control shows connection state, active DPI, lighting and favourite profiles even when the main window is closed.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            SettingSection("Per-app rules", detail: "Stages a draft · never writes automatically") {
                HStack(spacing: 10) {
                    Picker("Application", selection: $selectedAppID) {
                        Text("Choose running app").tag("")
                        ForEach(model.runningApps) { Text($0.name).tag($0.id) }
                    }
                    .frame(maxWidth: 230)
                    Picker("Profile", selection: $selectedProfileID) {
                        Text("Choose profile").tag(UUID?.none)
                        ForEach(model.savedProfiles) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .frame(maxWidth: 230)
                    Button("Add Rule") {
                        model.addAppRule(bundleIdentifier: selectedAppID, profileID: selectedProfileID)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedAppID.isEmpty || selectedProfileID == nil)
                    Button {
                        model.refreshRunningApps()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                if model.appRules.isEmpty {
                    Text("No app rules yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.appRules) { rule in
                            HStack {
                                Image(systemName: "app")
                                    .foregroundStyle(Color.accentColor)
                                Text(rule.appName).font(.system(size: 12, weight: .semibold))
                                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                                Text(model.savedProfiles.first(where: { $0.id == rule.profileID })?.name ?? "Missing profile")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    model.deleteAppRule(rule)
                                } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 10)
                            if rule.id != model.appRules.last?.id { Divider() }
                        }
                    }
                }
            }

            SettingSection("Connection history", detail: "This session") {
                VStack(spacing: 0) {
                    ForEach(model.connectionActivity.prefix(10)) { event in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(event.success ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                            Text(event.text).font(.system(size: 11, weight: .medium))
                            Spacer()
                            Text(event.date.formatted(date: .omitted, time: .standard))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        if event.id != model.connectionActivity.prefix(10).last?.id { Divider() }
                    }
                }
            }
        }
        .onAppear {
            model.refreshRunningApps()
            if selectedProfileID == nil { selectedProfileID = model.savedProfiles.first?.id }
        }
    }
}

struct MenuBarControlView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.menuBarStatus)
                .font(.headline)
            if let editing = model.editing {
                let dpi = editing.profiles.first(where: { $0.id == editing.activeProfile })?.dpi ?? 0
                Text("\(dpi) DPI · \(editing.pollingRate.hertz) Hz · \(editing.lightingEffect.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            if !model.savedProfiles.isEmpty {
                Text("Stage profile").font(.caption).foregroundStyle(.secondary)
                ForEach(model.savedProfiles.filter { $0.isFavorite == true }.prefix(5)) { profile in
                    Button(profile.name) { model.loadSavedProfile(profile) }
                }
            }
            Divider()
            Button("Refresh Mouse") { model.refresh() }
            Button("Open Model O Control") { openWindow(id: "main") }
        }
        .padding(10)
        .frame(width: 260)
    }
}
