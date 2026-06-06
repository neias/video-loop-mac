import SwiftUI
import AppKit

@main
struct VideoLoopApp: App {
    init() {
        // Çıplak çalıştırıldığında bile Dock'ta görünmesi ve öne gelmesi için.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("VideoLoop") {
            ContentView()
                .frame(minWidth: 620, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
    }
}
