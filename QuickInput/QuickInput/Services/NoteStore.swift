import Foundation
import Network
import SwiftData
import SwiftUI

extension Notification.Name {
    static let notionSettingsChanged = Notification.Name("notionSettingsChanged")
}

@MainActor
@Observable
final class NoteStore {
    private let modelContext: ModelContext
    private(set) var notionService: NotionService?
    private nonisolated(unsafe) let networkMonitor = NWPathMonitor()

    var pendingCount: Int = 0
    var failedCount: Int = 0

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        rebuildNotionService()
        resetStaleSyncing()
        refreshCounts()
        startNetworkMonitor()
        observeSettingsChanges()
    }

    func rebuildNotionService() {
        if let token = UserDefaults.standard.string(forKey: "notionToken"),
           let dbId = UserDefaults.standard.string(forKey: "notionDatabaseId"),
           !token.isEmpty, !dbId.isEmpty {
            notionService = NotionService(token: token, databaseId: dbId)
        } else {
            notionService = nil
        }
    }

    private func resetStaleSyncing() {
        let syncingRaw = SyncStatus.syncing.rawValue
        let predicate = #Predicate<Note> { $0.syncStatusRaw == syncingRaw }
        if let stale = try? modelContext.fetch(FetchDescriptor(predicate: predicate)) {
            for note in stale {
                note.syncStatus = .pending
            }
            try? modelContext.save()
        }
    }

    func refreshCounts() {
        let pendingRaw = SyncStatus.pending.rawValue
        let failedRaw = SyncStatus.failed.rawValue
        let pendingPred = #Predicate<Note> { $0.syncStatusRaw == pendingRaw }
        let failedPred = #Predicate<Note> { $0.syncStatusRaw == failedRaw }
        pendingCount = (try? modelContext.fetchCount(FetchDescriptor(predicate: pendingPred))) ?? 0
        failedCount = (try? modelContext.fetchCount(FetchDescriptor(predicate: failedPred))) ?? 0
    }

    func submitNote(content: String) {
        let title = MarkdownHighlighter.extractTitle(from: content)
        let note = Note(content: content, title: title)
        modelContext.insert(note)
        try? modelContext.save()
        refreshCounts()

        Task { @MainActor in await syncNote(note) }
    }

    func retryAllFailed() {
        let pendingRaw = SyncStatus.pending.rawValue
        let failedRaw = SyncStatus.failed.rawValue
        let predicate = #Predicate<Note> { $0.syncStatusRaw == failedRaw || $0.syncStatusRaw == pendingRaw }
        guard let notes = try? modelContext.fetch(FetchDescriptor(predicate: predicate)) else { return }
        for note in notes {
            Task { @MainActor in await syncNote(note) }
        }
    }

    func fetchUnsyncedNotes() -> [Note] {
        let pendingRaw = SyncStatus.pending.rawValue
        let failedRaw = SyncStatus.failed.rawValue
        let predicate = #Predicate<Note> { $0.syncStatusRaw == pendingRaw || $0.syncStatusRaw == failedRaw }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func syncNote(_ note: Note, retryCount: Int = 0) async {
        guard let service = notionService else {
            note.syncStatus = .failed
            note.lastError = "Notion not configured"
            try? modelContext.save()
            refreshCounts()
            return
        }

        note.syncStatus = .syncing
        try? modelContext.save()

        do {
            _ = try await service.createPage(title: note.title, markdown: note.content)
            modelContext.delete(note)
            try? modelContext.save()
        } catch let error as NotionError {
            switch error {
            case .rateLimited(let retryAfter) where retryCount < 3:
                try? await Task.sleep(for: .seconds(retryAfter))
                await syncNote(note, retryCount: retryCount + 1)
                return
            default:
                note.syncStatus = .failed
                note.lastError = "\(error)"
                try? modelContext.save()
            }
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet
            || urlError.code == .networkConnectionLost
            || urlError.code == .dataNotAllowed {
            // Network unreachable: keep as pending, silent wait for reconnection
            note.syncStatus = .pending
            try? modelContext.save()
        } catch {
            note.syncStatus = .failed
            note.lastError = error.localizedDescription
            try? modelContext.save()
        }
        refreshCounts()
    }

    // Rebuild NotionService when settings change
    private func observeSettingsChanges() {
        NotificationCenter.default.addObserver(
            forName: .notionSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildNotionService()
        }
    }

    // Auto-retry when network comes back online
    private func startNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                Task { @MainActor in self?.retryAllFailed() }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }
}
