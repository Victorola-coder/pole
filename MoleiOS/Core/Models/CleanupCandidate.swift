import Foundation

enum CleanupSource: String, CaseIterable, Identifiable {
    case photos
    case files

    var id: String { rawValue }
}

struct CleanupCandidate: Identifiable {
    let id = UUID()
    let source: CleanupSource
    let displayName: String
    let sizeBytes: Int64
    let createdAt: Date?
    let detailText: String?
    let photoAssetLocalIdentifier: String?
    let fileURL: URL?
}

extension CleanupCandidate {
    var sizeGigabytes: Double {
        Double(sizeBytes) / 1_073_741_824.0
    }

    var sourceSymbolName: String {
        switch source {
        case .photos:
            return "photo.on.rectangle"
        case .files:
            return "doc.fill"
        }
    }
}
