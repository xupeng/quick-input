import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var hotkeyManager: GlobalHotkeyManager
    @State private var token: String = UserDefaults.standard.string(forKey: "notionToken") ?? ""
    @State private var databaseId: String = UserDefaults.standard.string(forKey: "notionDatabaseId") ?? ""
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section("Notion Configuration") {
                SecureField("API Token", text: $token)

                TextField("Database ID", text: $databaseId)
                    .help("32-character hex ID from your Notion database URL")

                HStack {
                    Button("Test Connection") { testConnection() }
                        .disabled(token.isEmpty || databaseId.isEmpty || isTesting)
                    if isTesting {
                        ProgressView().controlSize(.small)
                    }
                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("\u{2713}") ? .green : .red)
                    }
                }
            }

            Section("Shortcuts") {
                if !hotkeyManager.isAccessibilityGranted {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Accessibility access required for global hotkey")
                            .font(.caption)
                    }
                    Button("Grant Accessibility Access") {
                        hotkeyManager.requestAccessibility()
                    }
                }
                LabeledContent("Global Hotkey") {
                    KeyRecorderView(
                        binding: $hotkeyManager.binding,
                        isRecording: Binding(
                            get: { hotkeyManager.isRecordingHotkey },
                            set: { hotkeyManager.setRecording($0) }
                        )
                    )
                    .frame(width: 160, height: 24)
                }
                if !hotkeyManager.binding.isValid {
                    Text("Shortcut must include ⌘ or ⌃")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if hotkeyManager.binding != .default {
                    Button("Reset to Default") {
                        hotkeyManager.binding = .default
                    }
                    .font(.caption)
                }
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        if newValue {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 380)
        .onChange(of: token) { _, newValue in
            UserDefaults.standard.set(newValue.isEmpty ? nil : newValue, forKey: "notionToken")
            NotificationCenter.default.post(name: .notionSettingsChanged, object: nil)
        }
        .onChange(of: databaseId) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "notionDatabaseId")
            NotificationCenter.default.post(name: .notionSettingsChanged, object: nil)
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        let currentToken = token
        let normalizedId = NotionService.normalizeDatabaseId(databaseId)
        Task {
            do {
                var request = URLRequest(
                    url: URL(string: "https://api.notion.com/v1/databases/\(normalizedId)")!)
                request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
                request.setValue("2026-03-11", forHTTPHeaderField: "Notion-Version")
                let (_, response) = try await URLSession.shared.data(for: request)
                let httpResponse = response as? HTTPURLResponse
                if httpResponse?.statusCode == 200 {
                    testResult = "\u{2713} Connected successfully"
                } else {
                    testResult = "\u{2717} HTTP \(httpResponse?.statusCode ?? 0)"
                }
            } catch {
                testResult = "\u{2717} \(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}
