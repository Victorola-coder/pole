import Foundation

struct LocalFileScanner {
    private let directories: [URL]

    init(additionalDirectories: [URL], fileManager: FileManager = .default) {
        let appManagedDirectories = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        ]
            .compactMap { $0 }
        let merged = appManagedDirectories + additionalDirectories
        self.directories = Array(
            Dictionary(grouping: merged, by: { $0.standardizedFileURL.path }).values.compactMap { $0.first }
        )
    }

    func scanInsights() async throws -> [StorageInsight] {
        // Do not use Task.detached here — it does not inherit cancellation from the scan task, so “Cancel Scan” would not stop work.
        var bytes: Int64 = 0
        for directory in directories {
            try Task.checkCancellation()
            bytes += try recursiveDirectoryBytes(at: directory)
        }

        return [
            StorageInsight(
                category: "Local Files",
                usedGigabytes: bytesToGigabytes(bytes),
                suggestedSavingsGigabytes: bytesToGigabytes(Int64(Double(bytes) * 0.25))
            )
        ]
    }

    func scanCandidates(limit: Int = 50) async throws -> [CleanupCandidate] {
        var collected: [CleanupCandidate] = []
        for directory in directories {
            try Task.checkCancellation()
            collected.append(contentsOf: try fileCandidates(in: directory))
        }

        return collected
            .sorted { $0.sizeBytes > $1.sizeBytes }
            .prefix(limit)
            .map { $0 }
    }

    func scanFolderAnalysis(maxDepth: Int = 2, maxChildrenPerNode: Int = 8) async throws -> [FolderAnalysisNode] {
        try directories.map { root in
            try Task.checkCancellation()
            return try buildFolderNode(
                at: root,
                currentDepth: 0,
                maxDepth: maxDepth,
                maxChildrenPerNode: maxChildrenPerNode
            )
        }
    }

    private func recursiveDirectoryBytes(at root: URL) throws -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .creationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys)) else {
            return 0
        }

        var bytes: Int64 = 0
        var processedCount = 0
        for case let url as URL in enumerator {
            processedCount += 1
            if processedCount.isMultiple(of: 200) {
                try Task.checkCancellation()
            }
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.fileSize
            else {
                continue
            }
            bytes += Int64(size)
        }
        return bytes
    }

    private func fileCandidates(in root: URL) throws -> [CleanupCandidate] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys)) else {
            return []
        }

        var items: [CleanupCandidate] = []
        let minimumBytes = Int64(AppPreferences.minimumCandidateSizeMB * 1_024 * 1_024)
        var processedCount = 0
        for case let url as URL in enumerator {
            processedCount += 1
            if processedCount.isMultiple(of: 200) {
                try Task.checkCancellation()
            }
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.fileSize,
                  Int64(size) >= minimumBytes
            else {
                continue
            }

            items.append(
                CleanupCandidate(
                    source: .files,
                    displayName: url.lastPathComponent,
                    sizeBytes: Int64(size),
                    createdAt: values.creationDate,
                    detailText: url.deletingLastPathComponent().path,
                    photoAssetLocalIdentifier: nil,
                    fileURL: url
                )
            )
        }
        return items
    }

    private func buildFolderNode(
        at url: URL,
        currentDepth: Int,
        maxDepth: Int,
        maxChildrenPerNode: Int
    ) throws -> FolderAnalysisNode {
        try Task.checkCancellation()
        var children: [FolderAnalysisNode] = []
        if currentDepth < maxDepth {
            let childDirectories = immediateSubdirectories(of: url)
            children = try childDirectories.map {
                try buildFolderNode(
                    at: $0,
                    currentDepth: currentDepth + 1,
                    maxDepth: maxDepth,
                    maxChildrenPerNode: maxChildrenPerNode
                )
            }
            .sorted { $0.totalBytes > $1.totalBytes }
            .prefix(maxChildrenPerNode)
            .map { $0 }
        }

        let ownBytes = try recursiveDirectoryBytes(at: url)
        return FolderAnalysisNode(
            name: url.lastPathComponent,
            path: url.path,
            totalBytes: ownBytes,
            children: children
        )
    }

    private func immediateSubdirectories(of root: URL) -> [URL] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else {
            return []
        }
        return urls.filter { url in
            guard let values = try? url.resourceValues(forKeys: keys) else {
                return false
            }
            return values.isDirectory == true && values.isHidden != true
        }
    }

    private func bytesToGigabytes(_ bytes: Int64) -> Double {
        Double(bytes) / 1_073_741_824.0
    }
}
