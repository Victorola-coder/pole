import Foundation
import Photos

struct CompositeScanResult {
    let insights: [StorageInsight]
    let candidates: [CleanupCandidate]
    let folderAnalysis: [FolderAnalysisNode]
}

struct CompositeStorageScanner: StorageScanning {
    private let photoScanner = PhotoLibraryScanner()
    private let folderStore: ScopedFolderStoring

    init(folderStore: ScopedFolderStoring) {
        self.folderStore = folderStore
    }

    func scanAll(
        progress: @escaping @Sendable (_ value: Double, _ status: String) async -> Void
    ) async throws -> CompositeScanResult {
        await progress(0.02, "Preparing scan...")
        try Task.checkCancellation()

        let localFileScanner = LocalFileScanner(additionalDirectories: folderStore.scopedFolders())
        var insights: [StorageInsight] = []
        var candidates: [CleanupCandidate] = []

        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
            || PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            await progress(0.08, "Scanning photo/video usage (1/6)...")
            insights.append(contentsOf: try await photoScanner.scanInsights())
        }

        await progress(0.25, "Scanning app/local files usage (2/6)...")
        insights.append(contentsOf: try await localFileScanner.scanInsights())
        try Task.checkCancellation()

        await progress(0.45, "Collecting local cleanup candidates (3/6)...")
        candidates.append(contentsOf: try await localFileScanner.scanCandidates())
        try Task.checkCancellation()

        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
            || PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            await progress(0.68, "Collecting photo/video cleanup candidates (4/6)...")
            candidates.append(contentsOf: try await photoScanner.scanCandidates())
        }
        candidates.sort { $0.sizeBytes > $1.sizeBytes }

        await progress(0.86, "Analyzing folder structure (5/6)...")
        let folderAnalysis = try await localFileScanner.scanFolderAnalysis()
        try Task.checkCancellation()

        await progress(0.98, "Finalizing scan (6/6)...")
        return CompositeScanResult(
            insights: insights,
            candidates: candidates,
            folderAnalysis: folderAnalysis
        )
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
