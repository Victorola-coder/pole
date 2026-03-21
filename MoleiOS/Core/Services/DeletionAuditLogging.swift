import Foundation

protocol DeletionAuditLogging {
    func record(_ entry: DeletionAuditEntry)
    func recentEntries(limit: Int) -> [DeletionAuditEntry]
    func clear()
}

final class LocalDeletionAuditLogger: DeletionAuditLogging {
    private let queue = DispatchQueue(label: "com.victor.pole.auditlog", qos: .utility)
    private let fileURL: URL
    private let maxEntries: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default, maxEntries: Int = 500) {
        self.maxEntries = maxEntries
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appDir = base.appendingPathComponent("Pole", isDirectory: true)
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        self.fileURL = appDir.appendingPathComponent("deletion_audit.json", isDirectory: false)
    }

    func record(_ entry: DeletionAuditEntry) {
        queue.sync {
            var items = loadEntries()
            items.insert(entry, at: 0)
            if items.count > maxEntries {
                items = Array(items.prefix(maxEntries))
            }
            saveEntries(items)
        }
    }

    func recentEntries(limit: Int) -> [DeletionAuditEntry] {
        queue.sync {
            Array(loadEntries().prefix(max(0, limit)))
        }
    }

    func clear() {
        queue.sync {
            saveEntries([])
        }
    }

    private func loadEntries() -> [DeletionAuditEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? decoder.decode([DeletionAuditEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func saveEntries(_ entries: [DeletionAuditEntry]) {
        guard let data = try? encoder.encode(entries) else {
            return
        }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

final class InMemoryDeletionAuditLogger: DeletionAuditLogging {
    private var entries: [DeletionAuditEntry] = []

    func record(_ entry: DeletionAuditEntry) {
        entries.insert(entry, at: 0)
    }

    func recentEntries(limit: Int) -> [DeletionAuditEntry] {
        Array(entries.prefix(max(0, limit)))
    }

    func clear() {
        entries.removeAll()
    }
}
