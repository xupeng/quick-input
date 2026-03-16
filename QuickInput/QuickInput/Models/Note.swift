import Foundation
import SwiftData

enum SyncStatus: String, Codable, Sendable {
    case pending
    case syncing
    case failed
}

@Model
final class Note: Identifiable {
    var id: UUID
    var content: String
    var title: String
    var createdAt: Date
    // Stored as raw string for SwiftData #Predicate compatibility
    var syncStatusRaw: String
    var notionPageId: String?
    var lastError: String?

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(content: String, title: String) {
        self.id = UUID()
        self.content = content
        self.title = title
        self.createdAt = Date()
        self.syncStatusRaw = SyncStatus.pending.rawValue
    }
}
