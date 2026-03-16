import SwiftUI

struct InputView: View {
    @Environment(NoteStore.self) private var noteStore
    // Persist draft across panel show/hide — Esc closes without losing content
    @AppStorage("draftContent") private var text = ""
    @State private var showToast = false
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                MarkdownTextEditor(text: $text, onSubmit: submit)
                    .frame(minHeight: 200)

                Divider()

                HStack {
                    Text("⌘+Enter submit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Esc close")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            // Toast overlay
            if showToast {
                VStack {
                    Spacer()
                    Text("Saved ✓")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 480, minHeight: 280)
        .onExitCommand { onDismiss() }
    }

    private func submit() {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        noteStore.submitNote(content: content)
        text = ""

        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showToast = false }
            onDismiss()
        }
    }
}
