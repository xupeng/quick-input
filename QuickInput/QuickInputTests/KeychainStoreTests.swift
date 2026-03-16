import Testing
@testable import Quick_Input

@Suite("KeychainStore Tests")
struct KeychainStoreTests {
    let testService = "me.xupeng.QuickInput.test"
    let testAccount = "test-token"

    init() {
        // Clean up before each test
        KeychainStore.delete(service: testService, account: testAccount)
    }

    @Test("save and retrieve value")
    func saveAndRetrieve() throws {
        try KeychainStore.save("secret-token", service: testService, account: testAccount)
        let retrieved = KeychainStore.retrieve(service: testService, account: testAccount)
        #expect(retrieved == "secret-token")
    }

    @Test("returns nil for missing key")
    func missingKey() {
        let result = KeychainStore.retrieve(service: testService, account: "nonexistent")
        #expect(result == nil)
    }

    @Test("update existing value")
    func updateExisting() throws {
        try KeychainStore.save("old", service: testService, account: testAccount)
        try KeychainStore.save("new", service: testService, account: testAccount)
        #expect(KeychainStore.retrieve(service: testService, account: testAccount) == "new")
    }

    @Test("delete value")
    func deleteValue() throws {
        try KeychainStore.save("to-delete", service: testService, account: testAccount)
        KeychainStore.delete(service: testService, account: testAccount)
        #expect(KeychainStore.retrieve(service: testService, account: testAccount) == nil)
    }
}
