import SwiftUI

@main
struct StorageClearerDesktopApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Scan storage") {
                    model.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
