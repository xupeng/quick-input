import SwiftUI

@main
struct QuickInputApp: App {
    var body: some Scene {
        MenuBarExtra("Quick Input", systemImage: "note.text") {
            Text("Quick Input is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
