import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var token: String = ""
    @State private var databaseId: String = UserDefaults.standard.string(forKey: "notionDatabaseId") ?? ""
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section("Notion Configuration") {
                SecureField("API Token", text: $token)
                    .onAppear { token = KeychainStore.notionToken ?? "" }

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
        .frame(width: 450, height: 300)
        .onChange(of: token) { _, newValue in
            KeychainStore.notionToken = newValue.isEmpty ? nil : newValue
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
