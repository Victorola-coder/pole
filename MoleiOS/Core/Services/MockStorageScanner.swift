import Foundation

protocol StorageScanning {
    func scan() async throws -> [StorageInsight]
    func scanCandidates() async throws -> [CleanupCandidate]
    func scanFolderAnalysis() async throws -> [FolderAnalysisNode]
}

struct MockStorageScanner: StorageScanning {
    func scan() async throws -> [StorageInsight] {
        try await Task.sleep(for: .milliseconds(450))
        return StorageInsight.mockData
    }

    func scanCandidates() async throws -> [CleanupCandidate] {
        [
            CleanupCandidate(
                source: .photos,
                displayName: "Large video sample",
                sizeBytes: 750 * 1_024 * 1_024,
                createdAt: Date().addingTimeInterval(-86_400 * 30),
                detailText: "Likely old screen recording",
                photoAssetLocalIdentifier: nil,
                fileURL: nil
            ),
            CleanupCandidate(
                source: .files,
                displayName: "Unused download",
                sizeBytes: 120 * 1_024 * 1_024,
                createdAt: Date().addingTimeInterval(-86_400 * 90),
                detailText: "Downloads folder",
                photoAssetLocalIdentifier: nil,
                fileURL: nil
            )
        ]
    }

    func scanFolderAnalysis() async throws -> [FolderAnalysisNode] {
        [
            FolderAnalysisNode(
                name: "Documents",
                path: "/Documents",
                totalBytes: 230 * 1_024 * 1_024,
                children: []
            )
        ]
    }
}
