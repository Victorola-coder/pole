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
    var sizeMegabytes: Double {
        Double(sizeBytes) / 1_048_576.0
    }

    var sizeGigabytes: Double {
        Double(sizeBytes) / 1_073_741_824.0
    }

    var sizeLabel: String {
        String(format: "%.0f MB (%.2f GB)", sizeMegabytes, sizeGigabytes)
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
