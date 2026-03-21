import Foundation

protocol StorageScanning {
    func scan() async throws -> [StorageInsight]
}

struct MockStorageScanner: StorageScanning {
    func scan() async throws -> [StorageInsight] {
        try await Task.sleep(for: .milliseconds(450))
        return StorageInsight.mockData
    }
}
