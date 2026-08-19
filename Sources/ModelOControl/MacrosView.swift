import SwiftUI

struct MacrosView: View {
    @EnvironmentObject private var model: AppModel
    @State private var bank1Preset = ModelOMacroPreset.builtIns[0].id
    @State private var bank2Preset = ModelOMacroPreset.builtIns[3].id
    @State private var pendingBank: Int?

    var body: some View {
        PageScaffold(
            title: "Macros",
            subtitle: "Program two hardware macro banks, then assign them from Buttons."
        ) {
            SettingSection("Macro banks", detail: "Write-only V1 protocol") {
                VStack(spacing: 0) {
                    MacroBankRow(bank: 1, selection: $bank1Preset) { pendingBank = 1 }
                    Divider()
                    MacroBankRow(bank: 2, selection: $bank2Preset) { pendingBank = 2 }
                }
            }

            SettingSection("Available sequences") {
                VStack(spacing: 0) {
                    ForEach(ModelOMacroPreset.builtIns) { preset in
                        HStack {
                            Text(preset.name)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 130, alignment: .leading)
                            Text(preset.detail)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(preset.events.count) events")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 9)
                        if preset.id != ModelOMacroPreset.builtIns.last?.id { Divider() }
                    }
                }
            }

            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("The known V1 protocol can write macro banks but cannot read them back. Existing bank contents cannot be backed up or verified. Programming a bank permanently replaces that bank; assigning it to a button is still a separate Review & Apply change.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .alert("Replace macro bank \(pendingBank ?? 0)?", isPresented: Binding(
            get: { pendingBank != nil },
            set: { if !$0 { pendingBank = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingBank = nil }
            Button("Program Bank", role: .destructive) {
                guard let bank = pendingBank else { return }
                let preset = ModelOMacroPreset.preset(id: bank == 1 ? bank1Preset : bank2Preset)
                model.programMacro(bank: bank, preset: preset)
                pendingBank = nil
            }
        } message: {
            Text("This bank is write-only and its previous contents cannot be restored by the app.")
        }
    }
}

private struct MacroBankRow: View {
    let bank: Int
    @Binding var selection: String
    let program: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
                Text("\(bank)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text("Macro bank \(bank)").font(.system(size: 13, weight: .semibold))
                Text(ModelOMacroPreset.preset(id: selection).detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Preset", selection: $selection) {
                ForEach(ModelOMacroPreset.builtIns) { Text($0.name).tag($0.id) }
            }
            .labelsHidden()
            .frame(width: 170)
            Button("Program") { program() }
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 12)
    }
}
