import Foundation
import Photos

protocol CleanupServicing {
    func delete(candidate: CleanupCandidate) async throws
}

struct CleanupService: CleanupServicing {
    func delete(candidate: CleanupCandidate) async throws {
        switch candidate.source {
        case .photos:
            guard let localIdentifier = candidate.photoAssetLocalIdentifier else {
                throw CleanupError.missingIdentifier
            }

            let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            guard let asset = result.firstObject else {
                throw CleanupError.assetNotFound
            }

            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }
        case .files:
            guard let fileURL = candidate.fileURL else {
                throw CleanupError.missingIdentifier
            }
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

enum CleanupError: LocalizedError {
    case missingIdentifier
    case assetNotFound

    var errorDescription: String? {
        switch self {
        case .missingIdentifier:
            return "Item identifier is missing."
        case .assetNotFound:
            return "Item no longer exists."
        }
    }
}
