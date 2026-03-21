import XCTest
@testable import Pole

final class ScopedFolderAnalyzerTests: XCTestCase {
    func testFolderAnalysisIncludesRootNode() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let sub = root.appendingPathComponent("A", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        let file = sub.appendingPathComponent("data.bin")
        try Data(repeating: 1, count: 4096).write(to: file)

        let scanner = LocalFileScanner(additionalDirectories: [root])
        let analysis = await scanner.scanFolderAnalysis(maxDepth: 2, maxChildrenPerNode: 5)
        let rootNode = analysis.first(where: { $0.path == root.path })

        XCTAssertNotNil(rootNode)
        XCTAssertTrue((rootNode?.totalBytes ?? 0) > 0)
    }
}
