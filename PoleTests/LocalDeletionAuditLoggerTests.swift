import XCTest
@testable import Pole

final class LocalDeletionAuditLoggerTests: XCTestCase {
    func testRecordAndReadEntries() {
        let logger = InMemoryDeletionAuditLogger()
        logger.record(
            DeletionAuditEntry(
                candidateName: "video.mov",
                source: .files,
                sizeBytes: 1024,
                result: .deleted
            )
        )
        logger.record(
            DeletionAuditEntry(
                candidateName: "photo",
                source: .photos,
                sizeBytes: 2048,
                result: .dryRun
            )
        )

        let recent = logger.recentEntries(limit: 2)
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(recent[0].result, .dryRun)
        XCTAssertEqual(recent[1].result, .deleted)
    }

    func testClearRemovesEntries() {
        let logger = InMemoryDeletionAuditLogger()
        logger.record(
            DeletionAuditEntry(
                candidateName: "item",
                source: .files,
                sizeBytes: 1,
                result: .deleted
            )
        )
        logger.clear()
        XCTAssertTrue(logger.recentEntries(limit: 10).isEmpty)
    }
}
