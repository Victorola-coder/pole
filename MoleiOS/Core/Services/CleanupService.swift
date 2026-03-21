import Foundation
import Photos

protocol CleanupServicing {
    func delete(candidate: CleanupCandidate, options: DeletionOptions) async throws
}

struct CleanupService: CleanupServicing {
    private let folderStore: ScopedFolderStoring
    private let protectedFolderPolicy: ProtectedFolderChecking
    private let auditLogger: DeletionAuditLogging

    init(
        folderStore: ScopedFolderStoring,
        protectedFolderPolicy: ProtectedFolderChecking = ProtectedFolderPolicy(),
        auditLogger: DeletionAuditLogging = LocalDeletionAuditLogger()
    ) {
        self.folderStore = folderStore
        self.protectedFolderPolicy = protectedFolderPolicy
        self.auditLogger = auditLogger
    }

    func delete(candidate: CleanupCandidate, options: DeletionOptions) async throws {
        switch candidate.source {
        case .photos:
            guard let localIdentifier = candidate.photoAssetLocalIdentifier else {
                record(result: .failed, candidate: candidate, message: CleanupError.missingIdentifier.errorDescription)
                throw CleanupError.missingIdentifier
            }

            let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            guard let asset = result.firstObject else {
                record(result: .failed, candidate: candidate, message: CleanupError.assetNotFound.errorDescription)
                throw CleanupError.assetNotFound
            }

            if options.dryRun {
                record(result: .dryRun, candidate: candidate, message: "Dry run enabled, no changes applied.")
                return
            }

            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }
            record(result: .deleted, candidate: candidate, message: nil)
        case .files:
            guard let fileURL = candidate.fileURL else {
                record(result: .failed, candidate: candidate, message: CleanupError.missingIdentifier.errorDescription)
                throw CleanupError.missingIdentifier
            }
            if protectedFolderPolicy.isProtected(url: fileURL, protectedFolders: folderStore.protectedFolders()) {
                record(result: .blocked, candidate: candidate, message: CleanupError.protectedPath.errorDescription)
                throw CleanupError.protectedPath
            }
            if options.dryRun {
                record(result: .dryRun, candidate: candidate, message: "Dry run enabled, no changes applied.")
                return
            }
            try FileManager.default.removeItem(at: fileURL)
            record(result: .deleted, candidate: candidate, message: nil)
        }
    }

    private func record(result: DeletionAuditResult, candidate: CleanupCandidate, message: String?) {
        auditLogger.record(
            DeletionAuditEntry(
                candidateName: candidate.displayName,
                source: candidate.source,
                sizeBytes: candidate.sizeBytes,
                result: result,
                message: message
            )
        )
    }
}

enum CleanupError: LocalizedError {
    case missingIdentifier
    case assetNotFound
    case protectedPath

    var errorDescription: String? {
        switch self {
        case .missingIdentifier:
            return "Item identifier is missing."
        case .assetNotFound:
            return "Item no longer exists."
        case .protectedPath:
            return "This item is inside a protected folder and cannot be deleted."
        }
    }
}
