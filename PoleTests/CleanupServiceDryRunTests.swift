import XCTest
@testable import Pole

final class CleanupServiceDryRunTests: XCTestCase {
    func testDryRunDoesNotDeleteFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("sample.log")
        try Data("hello".utf8).write(to: fileURL)

        let folderStore = TestScopedFolderStore(scoped: [], protected: [])
        let logger = InMemoryDeletionAuditLogger()
        let service = CleanupService(folderStore: folderStore, auditLogger: logger)
        let candidate = CleanupCandidate(
            source: .files,
            displayName: "sample.log",
            sizeBytes: 5,
            createdAt: nil,
            detailText: nil,
            photoAssetLocalIdentifier: nil,
            fileURL: fileURL
        )

        try await service.delete(candidate: candidate, options: DeletionOptions(dryRun: true))

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(logger.recentEntries(limit: 1).first?.result, .dryRun)
    }

    func testProtectedFolderBlocksDeletion() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let protectedDir = tempDir.appendingPathComponent("protected", isDirectory: true)
        try? FileManager.default.createDirectory(at: protectedDir, withIntermediateDirectories: true)
        let fileURL = protectedDir.appendingPathComponent("sample.log")
        try? Data("hello".utf8).write(to: fileURL)

        let folderStore = TestScopedFolderStore(scoped: [], protected: [protectedDir])
        let logger = InMemoryDeletionAuditLogger()
        let service = CleanupService(folderStore: folderStore, auditLogger: logger)
        let candidate = CleanupCandidate(
            source: .files,
            displayName: "sample.log",
            sizeBytes: 5,
            createdAt: nil,
            detailText: nil,
            photoAssetLocalIdentifier: nil,
            fileURL: fileURL
        )

        do {
            try await service.delete(candidate: candidate, options: .live)
            XCTFail("Expected protectedPath error")
        } catch let error as CleanupError {
            XCTAssertEqual(error.errorDescription, CleanupError.protectedPath.errorDescription)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(logger.recentEntries(limit: 1).first?.result, .blocked)
    }
}

private struct TestScopedFolderStore: ScopedFolderStoring {
    let scoped: [URL]
    let protected: [URL]

    func scopedFolders() -> [URL] { scoped }
    func protectedFolders() -> [URL] { protected }
    func addFolder(_ url: URL) throws {}
    func addProtectedFolder(_ url: URL) throws {}
    func removeProtectedFolder(_ url: URL) {}
    func clearFolders() {}
    func clearProtectedFolders() {}
}
