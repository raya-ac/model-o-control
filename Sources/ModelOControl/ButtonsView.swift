import ModelOCore
import SwiftUI

struct ButtonsView: View {
    @Binding var mapping: ModelOButtonMapping

    var body: some View {
        PageScaffold(
            title: "Buttons",
            subtitle: "Assign the six physical controls stored in onboard memory."
        ) {
            SettingSection("Assignments", detail: "Backed up before Review & Apply") {
                VStack(spacing: 0) {
                    ForEach(0..<min(6, mapping.actions.count), id: \.self) { index in
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.11))
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(buttonNames[index])
                                    .font(.system(size: 13, weight: .semibold))
                                Text(buttonLocations[index])
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 140, alignment: .leading)

                            Spacer()
                            Picker("Button \(index + 1)", selection: $mapping.actions[index]) {
                                ForEach(categories, id: \.self) { category in
                                    Section(category) {
                                        ForEach(ModelOButtonAction.selectable.filter { $0.category == category }) { action in
                                            Text(action.title).tag(action)
                                        }
                                    }
                                }
                                if case .unknown = mapping.actions[index] {
                                    Section("Current") { Text(mapping.actions[index].title).tag(mapping.actions[index]) }
                                }
                            }
                            .labelsHidden()
                            .frame(width: 230)
                        }
                        .padding(.vertical, 11)
                        if index < 5 { Divider() }
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy(duration: 0.22)) { mapping.actions = defaultActions }
                } label: {
                    Label("Restore default map", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)

                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        mapping.actions[3] = .volumeDown
                        mapping.actions[4] = .volumeUp
                    }
                } label: {
                    Label("Side buttons → volume", systemImage: "speaker.wave.2")
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "exclamationmark.shield")
                    .foregroundStyle(.orange)
                Text("Remapping primary click buttons can make the mouse awkward to control. The untouched map is included in the automatic backup, and Backups can restore it with the rest of the configuration.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private let categories = ["Mouse", "Scroll", "DPI", "Media", "Macro", "Other"]
    private let buttonNames = ["Left button", "Right button", "Wheel click", "Back button", "Forward button", "DPI button"]
    private let buttonLocations = ["Main left", "Main right", "Scroll wheel", "Left side rear", "Left side front", "Top shell"]
    private let defaultActions: [ModelOButtonAction] = [.leftClick, .rightClick, .middleClick, .back, .forward, .dpiCycle]
}
