import Foundation
import Security

enum KeychainError: Error {
    case saveFailed(OSStatus)
}

enum KeychainStore {
    private static let defaultService = "me.xupeng.QuickInput"

    static func save(_ value: String, service: String = defaultService, account: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func retrieve(service: String = defaultService, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(service: String = defaultService, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // Convenience methods for the app's specific keys
    static var notionToken: String? {
        get { retrieve(account: "notion-api-token") }
        set {
            if let value = newValue {
                try? save(value, account: "notion-api-token")
            } else {
                delete(account: "notion-api-token")
            }
        }
    }
}
