import Foundation

struct FolderAnalysisNode: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let totalBytes: Int64
    let children: [FolderAnalysisNode]

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var expandableChildren: [FolderAnalysisNode]? {
        children.isEmpty ? nil : children
    }
}
