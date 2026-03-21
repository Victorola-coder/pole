import XCTest
@testable import Pole

final class AppStateTests: XCTestCase {
    func testPreferencesPersistAcrossInstances() {
        let defaults = UserDefaults(suiteName: "AppStateTests")!
        defaults.removePersistentDomain(forName: "AppStateTests")
        let folderStore = MockScopedFolderStore()

        var state: AppState? = AppState(defaults: defaults, folderStore: folderStore)
        state?.autoScanOnLaunch = false
        state?.minimumCandidateSizeMB = 256
        state?.includeVideosInScan = false
        state?.strictDeleteConfirmation = true
        state?.dryRunDeletionEnabled = true
        state?.appearance = .dark
        state?.accent = .orange
        state = nil

        let reloaded = AppState(defaults: defaults, folderStore: folderStore)
        XCTAssertFalse(reloaded.autoScanOnLaunch)
        XCTAssertEqual(reloaded.minimumCandidateSizeMB, 256)
        XCTAssertFalse(reloaded.includeVideosInScan)
        XCTAssertTrue(reloaded.strictDeleteConfirmation)
        XCTAssertTrue(reloaded.dryRunDeletionEnabled)
        XCTAssertEqual(reloaded.appearance, .dark)
        XCTAssertEqual(reloaded.accent, .orange)
    }
}

private final class MockScopedFolderStore: ScopedFolderStoring {
    func scopedFolders() -> [URL] { [] }
    func protectedFolders() -> [URL] { [] }
    func addFolder(_ url: URL) throws {}
    func addProtectedFolder(_ url: URL) throws {}
    func removeProtectedFolder(_ url: URL) {}
    func clearFolders() {}
    func clearProtectedFolders() {}
}
