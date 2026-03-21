import Foundation

struct LocalFileScanner {
    private let directories: [URL]

    init(additionalDirectories: [URL], fileManager: FileManager = .default) {
        self.directories = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        ]
        .compactMap { $0 } + additionalDirectories
    }

    func scanInsights() async -> [StorageInsight] {
        let bytes = directories.reduce(Int64(0)) { partialResult, directory in
            partialResult + recursiveDirectoryBytes(at: directory)
        }

        return [
            StorageInsight(
                category: "Local Files",
                usedGigabytes: bytesToGigabytes(bytes),
                suggestedSavingsGigabytes: bytesToGigabytes(Int64(Double(bytes) * 0.25))
            )
        ]
    }

    func scanCandidates(limit: Int = 50) async -> [CleanupCandidate] {
        var candidates: [CleanupCandidate] = []
        for directory in directories {
            candidates.append(contentsOf: fileCandidates(in: directory))
        }

        return candidates
            .sorted { $0.sizeBytes > $1.sizeBytes }
            .prefix(limit)
            .map { $0 }
    }

    private func recursiveDirectoryBytes(at root: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .creationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys)) else {
            return 0
        }

        var bytes: Int64 = 0
        for case let url as URL in enumerator {
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

    private func fileCandidates(in root: URL) -> [CleanupCandidate] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys)) else {
            return []
        }

        var items: [CleanupCandidate] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.fileSize,
                  size >= 10 * 1_024 * 1_024
            else {
                continue
            }

            items.append(
                CleanupCandidate(
                    source: .files,
                    displayName: url.lastPathComponent,
                    sizeBytes: Int64(size),
                    createdAt: values.creationDate,
                    detailText: root.path,
                    photoAssetLocalIdentifier: nil,
                    fileURL: url
                )
            )
        }
        return items
    }

    private func bytesToGigabytes(_ bytes: Int64) -> Double {
        Double(bytes) / 1_073_741_824.0
    }
}
