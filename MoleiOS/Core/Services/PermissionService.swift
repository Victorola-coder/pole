import Foundation
import Photos

protocol PermissionServicing {
    var canScanPhotos: Bool { get }
    func requestPhotoAccess() async -> Bool
}

struct PermissionService: PermissionServicing {
    var canScanPhotos: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    func requestPhotoAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }
}
