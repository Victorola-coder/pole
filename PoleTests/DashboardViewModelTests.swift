import XCTest
@testable import Pole

@MainActor
final class DashboardViewModelTests: XCTestCase {
    func testLoadPopulatesInsightsAndCandidates() async {
        let scanner = MockScanner()
        let viewModel = DashboardViewModel(
            scanner: scanner,
            cleanupService: MockCleanupService(),
            permissionService: MockPermissionService(),
            scopedFolderStore: MockScopedFolderStore()
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.insights.count, 1)
        XCTAssertEqual(viewModel.candidates.count, 1)
        XCTAssertEqual(viewModel.scanStatusText, "Completed")
        XCTAssertEqual(viewModel.scanProgress, 1)
    }

    func testLoadFailureSurfacesReadableError() async {
        let scanner = FailingScanner()
        let viewModel = DashboardViewModel(
            scanner: scanner,
            cleanupService: MockCleanupService(),
            permissionService: MockPermissionService(),
            scopedFolderStore: MockScopedFolderStore()
        )

        await viewModel.load()
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.scanStatusText, "Scan failed")
    }
}

private struct MockScanner: StorageScanning {
    func scan() async throws -> [StorageInsight] {
        [.init(category: "Files", usedGigabytes: 1, suggestedSavingsGigabytes: 0.2)]
    }

    func scanCandidates() async throws -> [CleanupCandidate] {
        [
            .init(
                source: .files,
                displayName: "video.mov",
                sizeBytes: 80 * 1_024 * 1_024,
                createdAt: nil,
                detailText: nil,
                photoAssetLocalIdentifier: nil,
                fileURL: nil
            )
        ]
    }

    func scanFolderAnalysis() async throws -> [FolderAnalysisNode] {
        []
    }
}

private struct FailingScanner: StorageScanning {
    enum ScanError: LocalizedError {
        case failed
        var errorDescription: String? { "No permission to scan selected folders." }
    }

    func scan() async throws -> [StorageInsight] { throw ScanError.failed }
    func scanCandidates() async throws -> [CleanupCandidate] { [] }
    func scanFolderAnalysis() async throws -> [FolderAnalysisNode] { [] }
}

private struct MockCleanupService: CleanupServicing {
    func delete(candidate: CleanupCandidate, options: DeletionOptions) async throws {}
}

private struct MockPermissionService: PermissionServicing {
    var canScanPhotos: Bool { true }
    func requestPhotoAccess() async -> Bool { true }
}

private struct MockScopedFolderStore: ScopedFolderStoring {
    func scopedFolders() -> [URL] { [] }
    func protectedFolders() -> [URL] { [] }
    func addFolder(_ url: URL) throws {}
    func addProtectedFolder(_ url: URL) throws {}
    func removeProtectedFolder(_ url: URL) {}
    func clearFolders() {}
    func clearProtectedFolders() {}
}
