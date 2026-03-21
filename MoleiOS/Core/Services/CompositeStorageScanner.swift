import Foundation
import Photos

struct CompositeStorageScanner: StorageScanning {
    private let photoScanner = PhotoLibraryScanner()
    private let localFileScanner = LocalFileScanner()

    func scan() async throws -> [StorageInsight] {
        var insights: [StorageInsight] = []

        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
            || PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            insights.append(contentsOf: await photoScanner.scanInsights())
        }

        insights.append(contentsOf: await localFileScanner.scanInsights())
        return insights
    }

    func scanCandidates() async throws -> [CleanupCandidate] {
        var candidates: [CleanupCandidate] = await localFileScanner.scanCandidates()

        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
            || PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            candidates.append(contentsOf: await photoScanner.scanCandidates())
        }

        return candidates.sorted { $0.sizeBytes > $1.sizeBytes }
    }
}
