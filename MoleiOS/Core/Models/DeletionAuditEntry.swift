import Foundation

enum DeletionAuditResult: String, Codable {
    case deleted
    case dryRun
    case blocked
    case failed
}

struct DeletionAuditEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let candidateName: String
    let source: CleanupSource
    let sizeBytes: Int64
    let result: DeletionAuditResult
    let message: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        candidateName: String,
        source: CleanupSource,
        sizeBytes: Int64,
        result: DeletionAuditResult,
        message: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.candidateName = candidateName
        self.source = source
        self.sizeBytes = sizeBytes
        self.result = result
        self.message = message
    }
}
