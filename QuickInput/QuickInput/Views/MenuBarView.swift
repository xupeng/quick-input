import SwiftUI

struct MenuBarView: View {
    @Environment(NoteStore.self) private var noteStore
    @EnvironmentObject var hotkeyManager: GlobalHotkeyManager
    var onNewNote: () -> Void

    private var hotkeyDisplayString: String {
        hotkeyManager.binding.displayString
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("New Note (\(hotkeyDisplayString))") { onNewNote() }

            Divider()

            if noteStore.pendingCount > 0 {
                Label("\(noteStore.pendingCount) syncing...", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            if noteStore.failedCount > 0 {
                Label("\(noteStore.failedCount) failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Button("Retry All") { noteStore.retryAllFailed() }
            }

            // List recent unsynced notes
            let notes = noteStore.fetchUnsyncedNotes()
            if !notes.isEmpty {
                Divider()
                ForEach(notes.prefix(5)) { note in
                    HStack {
                        Text(note.title)
                            .lineLimit(1)
                            .font(.caption)
                        Spacer()
                        Image(systemName: note.syncStatus == .failed ? "xmark.circle" : "clock")
                            .foregroundStyle(note.syncStatus == .failed ? .orange : .secondary)
                            .font(.caption2)
                    }
                }
            }

            Divider()
            SettingsLink { Text("Settings...") }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(8)
    }
}
