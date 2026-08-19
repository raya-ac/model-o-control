import SwiftUI

@main
struct ModelOControlApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Model O Control", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 940, minHeight: 650)
                .task { model.start() }
        }
        .defaultSize(width: 1040, height: 720)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)

        MenuBarExtra("Model O Control", systemImage: "computermouse.fill") {
            MenuBarControlView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}
