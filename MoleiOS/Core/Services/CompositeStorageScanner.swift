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

    /// - Parameter resume: If present, completed phases are skipped and partial arrays are reused (see `ScanFailure`).
    func scanAll(
        progress: @escaping @Sendable (_ value: Double, _ status: String) async -> Void,
        resume: ScanResumeSnapshot? = nil
    ) async throws -> CompositeScanResult {
        await progress(0.02, "Preparing scan...")
        try Task.checkCancellation()

        let localFileScanner = LocalFileScanner(additionalDirectories: folderStore.scopedFolders())
        let photoAuth = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
            || PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited

        var insights = resume?.insights ?? []
        var candidates = resume?.candidates ?? []
        let resumeFrom = resume?.resumePhase

        func shouldRun(_ phase: ScanResumePhase) -> Bool {
            guard let start = resumeFrom else { return true }
            return phase >= start
        }

        if photoAuth && shouldRun(.photoLibraryInsights) {
            do {
                await progress(0.08, "Scanning photo/video usage (1/6)...")
                insights.append(contentsOf: try await photoScanner.scanInsights { fraction, status in
                    await progress(0.08 + fraction * 0.16, status)
                })
            } catch {
                throw ScanFailure(
                    snapshot: ScanResumeSnapshot(insights: insights, candidates: candidates, resumePhase: .photoLibraryInsights),
                    underlying: error
                )
            }
        }

        if shouldRun(.localFileInsights) {
            do {
                await progress(0.25, "Scanning app/local files usage (2/6)...")
                insights.append(contentsOf: try await localFileScanner.scanInsights())
            } catch {
                throw ScanFailure(
                    snapshot: ScanResumeSnapshot(insights: insights, candidates: candidates, resumePhase: .localFileInsights),
                    underlying: error
                )
            }
        }
        try Task.checkCancellation()

        if shouldRun(.localFileCandidates) {
            do {
                await progress(0.45, "Collecting local cleanup candidates (3/6)...")
                candidates.append(contentsOf: try await localFileScanner.scanCandidates())
            } catch {
                throw ScanFailure(
                    snapshot: ScanResumeSnapshot(insights: insights, candidates: candidates, resumePhase: .localFileCandidates),
                    underlying: error
                )
            }
        }
        try Task.checkCancellation()

        if photoAuth && shouldRun(.photoLibraryCandidates) {
            if resume != nil {
                candidates.removeAll { $0.source == .photos }
            }
            do {
                await progress(0.68, "Collecting photo/video cleanup candidates (4/6)...")
                candidates.append(contentsOf: try await photoScanner.scanCandidates(limit: 50) { fraction, status in
                    await progress(0.68 + fraction * 0.14, status)
                })
            } catch {
                throw ScanFailure(
                    snapshot: ScanResumeSnapshot(insights: insights, candidates: candidates, resumePhase: .photoLibraryCandidates),
                    underlying: error
                )
            }
        }
        candidates.sort { $0.sizeBytes > $1.sizeBytes }

        do {
            await progress(0.86, "Analyzing folder structure (5/6)...")
            let folderAnalysis = try await localFileScanner.scanFolderAnalysis()
            try Task.checkCancellation()
            await progress(0.98, "Finalizing scan (6/6)...")
            return CompositeScanResult(insights: insights, candidates: candidates, folderAnalysis: folderAnalysis)
        } catch {
            throw ScanFailure(
                snapshot: ScanResumeSnapshot(insights: insights, candidates: candidates, resumePhase: .folderStructureAnalysis),
                underlying: error
            )
        }
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
