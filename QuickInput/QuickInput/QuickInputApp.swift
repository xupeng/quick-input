import SwiftData
import SwiftUI

@main
struct QuickInputApp: App {
    @State private var noteStore: NoteStore?
    @StateObject private var hotkeyManager = GlobalHotkeyManager()
    @StateObject private var panelManager = FloatingPanelManager()

    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Note.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Group {
                if let noteStore {
                    MenuBarView(onNewNote: toggleInputPanel)
                        .environment(noteStore)
                        .environmentObject(hotkeyManager)
                } else {
                    Text("Loading...")
                }
            }
            .onAppear { setupOnFirstAppear() }
        } label: {
            let badge = (noteStore?.failedCount ?? 0) + (noteStore?.pendingCount ?? 0)
            if (noteStore?.failedCount ?? 0) > 0 {
                Label(
                    badge > 0 ? "\(badge)" : "Quick Input",
                    systemImage: "exclamationmark.triangle"
                )
            } else {
                Label(
                    badge > 0 ? "\(badge)" : "Quick Input",
                    image: "MenuBarIcon"
                )
            }
        }
        .modelContainer(modelContainer)

        Settings {
            SettingsView()
                .environmentObject(hotkeyManager)
        }
    }

    private func setupOnFirstAppear() {
        guard noteStore == nil else { return }

        let context = ModelContext(modelContainer)
        let store = NoteStore(modelContext: context)
        noteStore = store

        hotkeyManager.onHotkey = { @MainActor @Sendable in
            self.toggleInputPanel()
        }

        if hotkeyManager.checkAccessibility() {
            hotkeyManager.start()
        }

        store.retryAllFailed()
    }

    private func toggleInputPanel() {
        guard let noteStore else { return }
        panelManager.toggle {
            InputView(onDismiss: { panelManager.close() })
                .environment(noteStore)
        }
    }
}
