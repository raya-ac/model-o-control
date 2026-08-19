import ModelOCore
import SwiftUI

struct PageScaffold<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                content
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 42)
            .padding(.top, 38)
            .padding(.bottom, 96)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct SettingSection<Content: View>: View {
    var title: String
    var detail: String?
    @ViewBuilder var content: Content

    init(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            Divider()
            content
        }
    }
}

struct DeviceView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var configuration: MouseConfiguration

    var body: some View {
        PageScaffold(
            title: "Model O",
            subtitle: "Original wired V1 · settings read directly from onboard memory"
        ) {
            HStack(spacing: 46) {
                ModelOMouseVisual(
                    color: configuration.lightingColor.swiftUIColor,
                    effect: configuration.lightingEffect,
                    size: 265,
                    brightness: configuration.lightingBrightness,
                    speed: configuration.lightingSpeed
                )
                .frame(width: 310, height: 330)

                VStack(spacing: 0) {
                    DeviceFact(label: "Connection", value: "USB wired", accent: true)
                    Divider()
                    DeviceFact(label: "USB identifier", value: model.device?.usbIdentifier ?? "258A:0036", monospaced: true)
                    Divider()
                    DeviceFact(label: "Firmware", value: configuration.firmwareVersion, monospaced: true)
                    Divider()
                    DeviceFact(label: "Polling", value: "\(configuration.pollingRate.hertz) Hz")
                    Divider()
                    DeviceFact(label: "Active DPI", value: "\(activeDPI)")
                }
                .frame(maxWidth: 330)
            }
            .frame(maxWidth: .infinity)

            SettingSection("Onboard state") {
                HStack(spacing: 36) {
                    Metric(value: "\(configuration.profiles.filter(\.enabled).count)", label: "DPI profiles")
                    Metric(value: "\(configuration.debounceMilliseconds) ms", label: "Debounce")
                    Metric(value: "\(configuration.liftOffDistanceMillimeters) mm", label: "Lift-off")
                    Metric(value: configuration.lightingEffect.title, label: "Lighting")
                }
            }

            SettingSection("Utilities") {
                HStack(spacing: 10) {
                    Button {
                        model.saveCurrentProfile()
                    } label: {
                        Label("Save as profile", systemImage: "bookmark")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        model.copySetupSummary()
                    } label: {
                        Label("Copy setup summary", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                    Text("Local tools · no mouse write")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var activeDPI: Int {
        configuration.profiles.first(where: { $0.id == configuration.activeProfile })?.dpi ?? 0
    }
}

private struct DeviceFact: View {
    var label: String
    var value: String
    var monospaced = false
    var accent = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 7) {
                if accent {
                    Circle().fill(.green).frame(width: 7, height: 7)
                }
                Text(value)
                    .font(monospaced ? .system(size: 12, weight: .medium, design: .monospaced) : .system(size: 13, weight: .medium))
            }
        }
        .padding(.vertical, 13)
    }
}

private struct Metric: View {
    var value: String
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfilesView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var configuration: MouseConfiguration
    @State private var profilePendingDeletion: SavedDeviceProfile?
    @State private var profilePendingRename: SavedDeviceProfile?
    @State private var profileRenameText = ""

    var body: some View {
        PageScaffold(
            title: "Profiles",
            subtitle: "Whole-device starting points for DPI, response and lighting."
        ) {
            SettingSection("Built-in profiles", detail: "Draft only until Review & Apply") {
                VStack(spacing: 0) {
                    ForEach(DevicePreset.builtIns) { preset in
                        Button {
                            withAnimation(.snappy(duration: 0.26)) {
                                preset.apply(to: &configuration)
                            }
                        } label: {
                            DevicePresetRow(preset: preset, isSelected: preset.matches(configuration))
                        }
                        .buttonStyle(.plain)
                        if preset.id != DevicePreset.builtIns.last?.id { Divider() }
                    }
                }
            }

            SettingSection("Saved by you", detail: "\(model.savedProfiles.count) local") {
                HStack {
                    Button {
                        model.saveCurrentProfile()
                    } label: {
                        Label("Save current draft", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        model.revealSavedProfiles()
                    } label: {
                        Label("Show folder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    Button("Import") { model.importSavedProfiles() }
                        .buttonStyle(.bordered)
                    Button("Export") { model.exportSavedProfiles() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Text("Loads editable fields onto the current raw report")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                if model.savedProfiles.isEmpty {
                    Text("No custom profiles yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.savedProfiles.prefix(8)) { profile in
                            HStack(spacing: 10) {
                                Button {
                                    withAnimation(.snappy(duration: 0.24)) {
                                        model.loadSavedProfile(profile)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "bookmark")
                                            .foregroundStyle(Color.accentColor)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(profile.name)
                                                .font(.system(size: 13, weight: .semibold))
                                            Text(profile.summary)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(profile.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    model.toggleFavoriteProfile(profile)
                                } label: {
                                    Image(systemName: profile.isFavorite == true ? "star.fill" : "star")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(profile.isFavorite == true ? Color.yellow : Color.secondary)

                                Menu {
                                    Button("Rename") {
                                        profileRenameText = profile.name
                                        profilePendingRename = profile
                                    }
                                    Button("Duplicate") { model.duplicateSavedProfile(profile) }
                                    Divider()
                                    Button("Delete", role: .destructive) { profilePendingDeletion = profile }
                                } label: {
                                    Image(systemName: "ellipsis")
                                }
                                .menuStyle(.borderlessButton)
                                .frame(width: 22)
                            }
                            if profile.id != model.savedProfiles.prefix(8).last?.id { Divider() }
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .foregroundStyle(Color.accentColor)
                Text("Profiles replace the visible draft only. Use Discard to return to the current onboard setup, or Review & Apply to write it with a backup.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .alert("Delete saved profile?", isPresented: Binding(
            get: { profilePendingDeletion != nil },
            set: { if !$0 { profilePendingDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) { profilePendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let profilePendingDeletion { model.deleteSavedProfile(profilePendingDeletion) }
                profilePendingDeletion = nil
            }
        } message: {
            Text(profilePendingDeletion?.name ?? "This local profile will be removed.")
        }
        .alert("Rename saved profile", isPresented: Binding(
            get: { profilePendingRename != nil },
            set: { if !$0 { profilePendingRename = nil } }
        )) {
            TextField("Profile name", text: $profileRenameText)
            Button("Cancel", role: .cancel) { profilePendingRename = nil }
            Button("Rename") {
                if let profilePendingRename { model.renameSavedProfile(profilePendingRename, to: profileRenameText) }
                profilePendingRename = nil
            }
        }
    }
}

private struct DevicePresetRow: View {
    let preset: DevicePreset
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.045))
                Image(systemName: isSelected ? "checkmark" : preset.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(preset.name)
                        .font(.system(size: 14, weight: .semibold))
                    Text(preset.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("\(preset.dpiSummary) DPI")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(preset.pollingRate.hertz) Hz")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(preset.debounce) ms · \(preset.liftOffDistance) mm")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 13)
    }
}

struct SensitivityView: View {
    @Binding var configuration: MouseConfiguration
    @State private var gameSensitivity = 1.0
    @State private var targetDPI = 1_600

    var body: some View {
        PageScaffold(
            title: "Sensitivity",
            subtitle: "Choose the DPI stages stored on the mouse and its USB report rate."
        ) {
            SettingSection("DPI stages", detail: "100–25,600 · 100 DPI steps") {
                VStack(spacing: 0) {
                    ForEach(0..<min(6, configuration.profiles.count), id: \.self) { index in
                        DPIProfileRow(
                            profile: $configuration.profiles[index],
                            isActive: configuration.activeProfile == index,
                            canDisable: configuration.profiles.filter(\.enabled).count > 1,
                            makeActive: {
                                configuration.activeProfile = index
                                configuration.profiles[index].enabled = true
                            },
                            setEnabled: { enabled in
                                setProfile(index, enabled: enabled)
                            }
                        )
                        if index < min(6, configuration.profiles.count) - 1 { Divider() }
                    }
                }
            }

            SettingSection("Stage tools", detail: "Fast ways to reshape the ladder") {
                HStack(spacing: 10) {
                    Button {
                        competitiveLadder()
                    } label: {
                        Label("Competitive 3", systemImage: "scope")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        classicLadder()
                    } label: {
                        Label("Classic 6", systemImage: "list.number")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        lockCurrentStage()
                    } label: {
                        Label("Lock current", systemImage: "lock.fill")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        recolorStages()
                    } label: {
                        Label("Recolour", systemImage: "paintpalette")
                    }
                    .buttonStyle(.bordered)

                }
            }

            SettingSection("Polling rate", detail: "Higher rates report movement more often") {
                Picker("Polling rate", selection: $configuration.pollingRate) {
                    ForEach(PollingRate.allCases) { rate in
                        Text("\(rate.hertz) Hz").tag(rate)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(spacing: 36) {
                    PollingMetric(value: pollingIntervalText, label: "Interval")
                    PollingMetric(value: "\(configuration.pollingRate.hertz)", label: "Reports / second")
                    PollingMetric(value: "\(configuration.pollingRate.hertz * 60)", label: "Reports / minute")
                    Spacer()
                }
                .padding(.top, 5)
            }

            SettingSection("DPI converter", detail: "Keeps the same effective sensitivity") {
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 7) {
                            Text("\(activeDPI)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .frame(width: 58, alignment: .trailing)
                            Text("DPI ×")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            TextField("Sensitivity", value: $gameSensitivity, format: .number.precision(.fractionLength(0...4)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                        }
                    }

                    Image(systemName: "equal")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 18)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Converted")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 7) {
                            TextField("Target DPI", value: $targetDPI, format: .number.grouping(.never))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 78)
                            Text("DPI ×")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(convertedSensitivity.formatted(.number.precision(.fractionLength(0...4))))
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .frame(width: 80, alignment: .leading)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(eDPI.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("eDPI")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var activeDPI: Int {
        configuration.profiles.first(where: { $0.id == configuration.activeProfile })?.dpi ?? 800
    }

    private var eDPI: Double { Double(activeDPI) * max(0, gameSensitivity) }

    private var convertedSensitivity: Double {
        guard targetDPI > 0 else { return 0 }
        return eDPI / Double(targetDPI)
    }

    private var pollingIntervalText: String {
        let interval = 1_000.0 / Double(configuration.pollingRate.hertz)
        return interval.formatted(.number.precision(.fractionLength(0...2))) + " ms"
    }

    private func setProfile(_ index: Int, enabled: Bool) {
        if enabled {
            configuration.profiles[index].enabled = true
            return
        }
        guard configuration.profiles.filter(\.enabled).count > 1 else { return }
        configuration.profiles[index].enabled = false
        if configuration.activeProfile == index,
           let replacement = configuration.profiles.first(where: \.enabled) {
            configuration.activeProfile = replacement.id
        }
    }

    private func competitiveLadder() {
        setLadder([400, 800, 1600], active: 1)
    }

    private func classicLadder() {
        setLadder([400, 800, 1600, 3200, 6400, 12_000], active: min(configuration.activeProfile, 5))
    }

    private func setLadder(_ values: [Int], active: Int) {
        withAnimation(.snappy(duration: 0.24)) {
            for index in 0..<min(6, configuration.profiles.count) {
                configuration.profiles[index].enabled = index < values.count
                if index < values.count { configuration.profiles[index].dpi = values[index] }
            }
            configuration.activeProfile = min(active, max(0, values.count - 1))
        }
    }

    private func lockCurrentStage() {
        withAnimation(.snappy(duration: 0.24)) {
            for index in 0..<min(6, configuration.profiles.count) {
                configuration.profiles[index].enabled = index == configuration.activeProfile
            }
        }
    }

    private func recolorStages() {
        withAnimation(.easeOut(duration: 0.18)) {
            for index in 0..<min(6, configuration.profiles.count) {
                configuration.profiles[index].color = StagePalette.color(at: index)
            }
        }
    }

}

private struct PollingMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct DPIProfileRow: View {
    @Binding var profile: DPIProfile
    var isActive: Bool
    var canDisable: Bool
    var makeActive: () -> Void
    var setEnabled: (Bool) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: makeActive) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(isActive ? profile.color.swiftUIColor : Color.secondary.opacity(0.35), lineWidth: 1.5)
                        if isActive {
                            Circle()
                                .fill(profile.color.swiftUIColor)
                                .padding(4)
                                .shadow(color: profile.color.swiftUIColor.opacity(0.65), radius: 4)
                        }
                    }
                    .frame(width: 17, height: 17)
                    Text("Stage \(profile.id + 1)")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(width: 92, height: 30, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Make active")

            TextField("DPI", value: $profile.dpi, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .frame(width: 94)
            Text("DPI")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            ColorPicker("", selection: Binding(
                get: { profile.color.swiftUIColor },
                set: { profile.color = MouseColor($0) }
            ), supportsOpacity: false)
            .labelsHidden()

            Spacer()
            Toggle("Enabled", isOn: Binding(
                get: { profile.enabled },
                set: setEnabled
            ))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(profile.enabled && !canDisable)
        }
        .padding(.vertical, 11)
        .opacity(profile.enabled ? 1 : 0.48)
    }
}

struct LightingView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var configuration: MouseConfiguration
    @State private var lightingLookPendingDeletion: SavedLightingLook?

    var body: some View {
        PageScaffold(
            title: "Lighting",
            subtitle: "Preview the look here, then write it once to onboard memory."
        ) {
            HStack(spacing: 44) {
                ModelOMouseVisual(
                    color: configuration.lightingColor.swiftUIColor,
                    effect: configuration.lightingEffect,
                    size: 235,
                    brightness: configuration.lightingBrightness,
                    speed: configuration.lightingSpeed
                )
                .frame(width: 300, height: 300)

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Effect")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Picker("Effect", selection: $configuration.lightingEffect) {
                            ForEach(LightingEffect.allCases) { effect in
                                Text(effect.title).tag(effect)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }

                    if configuration.lightingEffect.supportsPrimaryColor {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Primary colour")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ColorPicker("Primary colour", selection: Binding(
                                get: { configuration.lightingColor.swiftUIColor },
                                set: { configuration.lightingColor = MouseColor($0) }
                            ), supportsOpacity: false)
                            .labelsHidden()
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: 290)
            }
            .frame(maxWidth: .infinity)
            .animation(.snappy(duration: 0.22), value: configuration.lightingEffect)

            SettingSection("Quick looks", detail: "Preview only · writes with Review & Apply") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                    ForEach(LightingPreset.builtIns) { preset in
                        LightingPresetButton(
                            preset: preset,
                            isSelected: preset.matches(configuration)
                        ) {
                            withAnimation(.snappy(duration: 0.24)) {
                                preset.apply(to: &configuration)
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        matchActiveDPI()
                    } label: {
                        Label("Match active DPI", systemImage: "scope")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        surpriseMe()
                    } label: {
                        Label("Surprise me", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                    Text("V1 firmware effects")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            }

            SettingSection("Saved lighting", detail: "\(model.savedLightingLooks.count) local") {
                HStack(spacing: 10) {
                    Button {
                        model.saveCurrentLightingLook()
                    } label: {
                        Label("Save current look", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)

                    if model.savedLightingLooks.isEmpty {
                        Text("Save any effect, colour, brightness and speed combination.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                if !model.savedLightingLooks.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                        ForEach(model.savedLightingLooks.prefix(9)) { look in
                            HStack(spacing: 8) {
                                Button {
                                    withAnimation(.snappy(duration: 0.22)) { model.loadLightingLook(look) }
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(look.color.swiftUIColor)
                                            .frame(width: 14, height: 14)
                                            .shadow(color: look.color.swiftUIColor.opacity(0.5), radius: 4)
                                        Text(look.name)
                                            .font(.system(size: 10, weight: .semibold))
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Button {
                                    lightingLookPendingDeletion = look
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.tertiary)
                            }
                            .padding(9)
                            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                    }
                }
            }

            if configuration.lightingEffect.supportsPrimaryColor {
                SettingSection("Colour palette", detail: "or choose any colour above") {
                    HStack(spacing: 13) {
                        ForEach(LightingPalette.colors, id: \.self) { color in
                            Button {
                                withAnimation(.easeOut(duration: 0.16)) {
                                    configuration.lightingColor = color
                                }
                            } label: {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 24, height: 24)
                                    .overlay {
                                        Circle().stroke(.white.opacity(configuration.lightingColor == color ? 0.9 : 0.16), lineWidth: configuration.lightingColor == color ? 2 : 1)
                                    }
                                    .shadow(color: color.swiftUIColor.opacity(0.45), radius: 5)
                            }
                            .buttonStyle(.plain)
                            .help(color.hexString)
                        }
                        Spacer()
                        HexColorField(color: $configuration.lightingColor)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if configuration.lightingEffect.supportsBrightness || configuration.lightingEffect.supportsSpeed {
                SettingSection("Motion") {
                    VStack(spacing: 18) {
                        if configuration.lightingEffect.supportsBrightness {
                            ValueSlider(label: "Brightness", value: $configuration.lightingBrightness, range: 0...4)
                        }
                        if configuration.lightingEffect.supportsSpeed {
                            ValueSlider(label: "Speed", value: $configuration.lightingSpeed, range: 0...3)
                        }
                    }
                }
            }
        }
        .alert("Delete saved lighting look?", isPresented: Binding(
            get: { lightingLookPendingDeletion != nil },
            set: { if !$0 { lightingLookPendingDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) { lightingLookPendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let lightingLookPendingDeletion { model.deleteLightingLook(lightingLookPendingDeletion) }
                lightingLookPendingDeletion = nil
            }
        }
    }

    private func matchActiveDPI() {
        guard let active = configuration.profiles.first(where: { $0.id == configuration.activeProfile }) else { return }
        withAnimation(.snappy(duration: 0.24)) {
            configuration.lightingEffect = .single
            configuration.lightingColor = active.color
            configuration.lightingBrightness = 4
        }
    }

    private func surpriseMe() {
        guard let preset = LightingPreset.builtIns.filter({ $0.effect != .off }).randomElement() else { return }
        withAnimation(.snappy(duration: 0.24)) {
            preset.apply(to: &configuration)
        }
    }
}

private struct HexColorField: View {
    @Binding var color: MouseColor
    @State private var text = ""

    var body: some View {
        TextField("#RRGGBB", text: $text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .textFieldStyle(.roundedBorder)
            .frame(width: 88)
            .onAppear { text = color.hexString }
            .onChange(of: color) { _, newValue in text = newValue.hexString }
            .onSubmit { apply() }
    }

    private func apply() {
        let cleaned = text.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            text = color.hexString
            return
        }
        color = MouseColor(
            red: UInt8((value >> 16) & 0xFF),
            green: UInt8((value >> 8) & 0xFF),
            blue: UInt8(value & 0xFF)
        )
        text = color.hexString
    }
}

private struct LightingPreset: Identifiable {
    let id: String
    let name: String
    let note: String
    let effect: LightingEffect
    let color: MouseColor
    let brightness: Int
    let speed: Int
    let swatches: [MouseColor]

    func apply(to configuration: inout MouseConfiguration) {
        configuration.lightingEffect = effect
        if effect.supportsPrimaryColor { configuration.lightingColor = color }
        if effect.supportsBrightness { configuration.lightingBrightness = brightness }
        if effect.supportsSpeed { configuration.lightingSpeed = speed }
    }

    func matches(_ configuration: MouseConfiguration) -> Bool {
        guard configuration.lightingEffect == effect else { return false }
        if effect.supportsPrimaryColor, configuration.lightingColor != color { return false }
        if effect.supportsBrightness, configuration.lightingBrightness != brightness { return false }
        if effect.supportsSpeed, configuration.lightingSpeed != speed { return false }
        return true
    }

    static let builtIns: [LightingPreset] = [
        .init(id: "prism", name: "Prism", note: "Signature RGB", effect: .glorious, color: .violet, brightness: 4, speed: 2, swatches: [.init(red: 255, green: 46, blue: 122), .init(red: 90, green: 94, blue: 255), .init(red: 40, green: 225, blue: 255)]),
        .init(id: "aurora", name: "Aurora", note: "Slow spectrum", effect: .wave, color: .violet, brightness: 3, speed: 0, swatches: [.init(red: 54, green: 255, blue: 190), .init(red: 75, green: 105, blue: 255), .init(red: 205, green: 84, blue: 255)]),
        .init(id: "plasma", name: "Plasma", note: "Hot rave", effect: .rave, color: .init(red: 255, green: 31, blue: 166), brightness: 4, speed: 2, swatches: [.init(red: 255, green: 31, blue: 166), .init(red: 125, green: 56, blue: 255)]),
        .init(id: "arctic", name: "Arctic", note: "Cool breathing", effect: .singleBreathing, color: .init(red: 45, green: 220, blue: 255), brightness: 3, speed: 1, swatches: [.init(red: 45, green: 220, blue: 255), .init(red: 190, green: 244, blue: 255)]),
        .init(id: "ember", name: "Ember", note: "Warm breathing", effect: .singleBreathing, color: .init(red: 255, green: 72, blue: 18), brightness: 3, speed: 1, swatches: [.init(red: 255, green: 36, blue: 8), .init(red: 255, green: 162, blue: 36)]),
        .init(id: "sakura", name: "Sakura", note: "Soft pulse", effect: .singleBreathing, color: .init(red: 255, green: 92, blue: 171), brightness: 3, speed: 0, swatches: [.init(red: 255, green: 92, blue: 171), .init(red: 255, green: 193, blue: 221)]),
        .init(id: "matrix", name: "Matrix", note: "Solid green", effect: .single, color: .init(red: 42, green: 255, blue: 88), brightness: 2, speed: 1, swatches: [.init(red: 42, green: 255, blue: 88), .init(red: 0, green: 112, blue: 38)]),
        .init(id: "comet", name: "Comet", note: "Fast trail", effect: .tail, color: .violet, brightness: 4, speed: 3, swatches: [.init(red: 35, green: 190, blue: 255), .init(red: 255, green: 255, blue: 255)]),
        .init(id: "ocean", name: "Ocean", note: "Deep blue pulse", effect: .singleBreathing, color: .init(red: 24, green: 98, blue: 255), brightness: 3, speed: 1, swatches: [.init(red: 18, green: 62, blue: 190), .init(red: 35, green: 190, blue: 255)]),
        .init(id: "toxic", name: "Toxic", note: "Acid breathing", effect: .singleBreathing, color: .init(red: 145, green: 255, blue: 28), brightness: 4, speed: 2, swatches: [.init(red: 145, green: 255, blue: 28), .init(red: 24, green: 138, blue: 48)]),
        .init(id: "ghost", name: "Ghost", note: "Dim white", effect: .single, color: .init(red: 220, green: 232, blue: 255), brightness: 1, speed: 1, swatches: [.init(red: 125, green: 142, blue: 170), .init(red: 245, green: 250, blue: 255)]),
        .init(id: "royal", name: "Royal", note: "Solid violet", effect: .single, color: .init(red: 118, green: 52, blue: 255), brightness: 4, speed: 1, swatches: [.init(red: 80, green: 30, blue: 190), .init(red: 176, green: 92, blue: 255)]),
        .init(id: "inferno", name: "Inferno", note: "Red-orange rave", effect: .rave, color: .init(red: 255, green: 44, blue: 12), brightness: 4, speed: 3, swatches: [.init(red: 255, green: 20, blue: 8), .init(red: 255, green: 138, blue: 20)]),
        .init(id: "candy", name: "Candy", note: "Pink rave", effect: .rave, color: .init(red: 255, green: 54, blue: 190), brightness: 3, speed: 1, swatches: [.init(red: 255, green: 54, blue: 190), .init(red: 95, green: 120, blue: 255)]),
        .init(id: "nightdrive", name: "Nightdrive", note: "Neon trail", effect: .tail, color: .violet, brightness: 2, speed: 1, swatches: [.init(red: 30, green: 100, blue: 255), .init(red: 255, green: 30, blue: 165)]),
        .init(id: "rush", name: "RGB Rush", note: "Fast wave", effect: .wave, color: .violet, brightness: 4, speed: 3, swatches: [.init(red: 255, green: 40, blue: 85), .init(red: 255, green: 220, blue: 35), .init(red: 30, green: 220, blue: 255)]),
        .init(id: "lotus", name: "Lotus", note: "Purple breathing", effect: .singleBreathing, color: .init(red: 186, green: 70, blue: 255), brightness: 2, speed: 0, swatches: [.init(red: 90, green: 35, blue: 180), .init(red: 220, green: 120, blue: 255)]),
        .init(id: "stealth", name: "Stealth", note: "Lights out", effect: .off, color: .violet, brightness: 0, speed: 0, swatches: [.init(red: 54, green: 57, blue: 66), .init(red: 16, green: 17, blue: 20)])
    ]
}

private struct LightingPresetButton: View {
    let preset: LightingPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Capsule()
                    .fill(LinearGradient(colors: preset.swatches.map(\.swiftUIColor), startPoint: .leading, endPoint: .trailing))
                    .frame(height: 8)
                    .shadow(color: preset.swatches.first?.swiftUIColor.opacity(0.45) ?? .clear, radius: 5)
                Text(preset.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(preset.note)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.72) : Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.name), \(preset.note)")
    }
}

private enum LightingPalette {
    static let colors: [MouseColor] = [
        .init(red: 255, green: 255, blue: 255),
        .init(red: 255, green: 45, blue: 64),
        .init(red: 255, green: 118, blue: 30),
        .init(red: 255, green: 219, blue: 48),
        .init(red: 46, green: 235, blue: 99),
        .init(red: 38, green: 220, blue: 255),
        .init(red: 64, green: 108, blue: 255),
        .init(red: 137, green: 76, blue: 255),
        .init(red: 255, green: 65, blue: 179)
    ]
}

private struct ValueSlider: View {
    var label: String
    @Binding var value: Int
    var range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 15) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 76, alignment: .leading)
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0.rounded()) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
            Text("\(value)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 20)
        }
    }
}

struct AdvancedView: View {
    @Binding var configuration: MouseConfiguration

    var body: some View {
        PageScaffold(
            title: "Advanced",
            subtitle: "Sensor and click behaviour stored by the mouse firmware."
        ) {
            SettingSection("Response presets", detail: "Polling · debounce · lift-off") {
                VStack(spacing: 0) {
                    ForEach(ResponsePreset.builtIns) { preset in
                        Button {
                            withAnimation(.snappy(duration: 0.22)) {
                                preset.apply(to: &configuration)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: preset.matches(configuration) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(preset.matches(configuration) ? Color.accentColor : Color.secondary.opacity(0.55))
                                Text(preset.name)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(preset.detail)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if preset.id != ResponsePreset.builtIns.last?.id { Divider() }
                    }
                }
            }

            SettingSection("Click debounce", detail: "Lower is faster; higher resists double clicks") {
                Picker("Debounce", selection: $configuration.debounceMilliseconds) {
                    ForEach(Array(stride(from: 4, through: 16, by: 2)), id: \.self) { value in
                        Text("\(value) ms").tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            SettingSection("Lift-off distance", detail: "Tracking height above the surface") {
                Picker("Lift-off distance", selection: $configuration.liftOffDistanceMillimeters) {
                    Text("2 mm").tag(2)
                    Text("3 mm").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Guarded writes")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Startup and manual refresh use three short selector reports to read the device. Persistent configuration reports are sent only after Review & Apply. Every apply validates ranges, saves the untouched 520-byte report, then reads the device back. Hardware macros are deliberately excluded.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 4)
        }
    }
}

struct BackupsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        PageScaffold(
            title: "Backups",
            subtitle: "A raw recovery point is created before every persistent write."
        ) {
            SettingSection("Saved configurations", detail: "\(model.backups.count) local") {
                if model.backups.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 25, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("The first backup appears when you apply a change.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.backups.prefix(8)) { backup in
                            HStack {
                                Image(systemName: "doc.badge.clock")
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 13, weight: .medium))
                                    Text("Firmware \(backup.firmwareVersion) · \(backup.rawReport.count) bytes · \(backup.debounceMilliseconds) ms debounce")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if backup.id == model.latestBackup?.id {
                                    Text("LATEST")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(0.8)
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.vertical, 12)
                            if backup.id != model.backups.prefix(8).last?.id { Divider() }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Show Backup Folder") { model.revealBackups() }
                    .buttonStyle(.bordered)
                Button("Snapshot Now") { model.createRecoveryPoint() }
                    .buttonStyle(.bordered)
                Button("Compare Latest") { model.compareLatestBackup() }
                    .buttonStyle(.bordered)
                    .disabled(model.latestBackup == nil)
                Button("Export Latest") { model.exportLatestBackup() }
                    .buttonStyle(.bordered)
                    .disabled(model.latestBackup == nil)
                Button("Restore Latest") { model.showsRestoreConfirmation = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.latestBackup == nil)
            }
        }
    }
}

extension MouseColor {
    var swiftUIColor: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    init(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .purple
        self.init(
            red: UInt8(max(0, min(255, Int((nsColor.redComponent * 255).rounded())))),
            green: UInt8(max(0, min(255, Int((nsColor.greenComponent * 255).rounded())))),
            blue: UInt8(max(0, min(255, Int((nsColor.blueComponent * 255).rounded()))))
        )
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}
