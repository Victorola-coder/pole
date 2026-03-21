import Foundation
import Photos

struct CompositeStorageScanner: StorageScanning {
    private let photoScanner = PhotoLibraryScanner()
    private let folderStore: ScopedFolderStoring

    init(folderStore: ScopedFolderStoring) {
        self.folderStore = folderStore
    }

    func scan() async throws -> [StorageInsight] {
        var insights: [StorageInsight] = []
        let localFileScanner = LocalFileScanner(additionalDirectories: folderStore.scopedFolders())
        try Task.checkCancellation()

        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
            || PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            insights.append(contentsOf: try await photoScanner.scanInsights())
        }

        try Task.checkCancellation()
        insights.append(contentsOf: try await localFileScanner.scanInsights())
        return insights
    }

    func scanCandidates() async throws -> [CleanupCandidate] {
        let localFileScanner = LocalFileScanner(additionalDirectories: folderStore.scopedFolders())
        try Task.checkCancellation()
        var candidates: [CleanupCandidate] = try await localFileScanner.scanCandidates()

        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
            || PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            try Task.checkCancellation()
            candidates.append(contentsOf: try await photoScanner.scanCandidates())
        }

        return candidates.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    func scanFolderAnalysis() async throws -> [FolderAnalysisNode] {
        let localFileScanner = LocalFileScanner(additionalDirectories: folderStore.scopedFolders())
        try Task.checkCancellation()
        return try await localFileScanner.scanFolderAnalysis()
    }
}
