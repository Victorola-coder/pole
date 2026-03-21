import Foundation
import Photos
import UIKit

struct PhotoLibraryScanner {
    func scanInsights() async throws -> [StorageInsight] {
        try await Task.detached(priority: .utility) {
            let imageAssets = PHAsset.fetchAssets(with: .image, options: nil)
            let videoAssets: PHFetchResult<PHAsset>
            if AppPreferences.includeVideosInScan {
                videoAssets = PHAsset.fetchAssets(with: .video, options: nil)
            } else {
                let options = PHFetchOptions()
                options.predicate = NSPredicate(value: false)
                videoAssets = PHAsset.fetchAssets(with: options)
            }

            let imageBytes = try await totalBytes(for: imageAssets)
            let videoBytes = try await totalBytes(for: videoAssets)

            return [
                StorageInsight(
                    category: "Photos",
                    usedGigabytes: bytesToGigabytes(imageBytes),
                    suggestedSavingsGigabytes: bytesToGigabytes(Int64(Double(imageBytes) * 0.15))
                ),
                StorageInsight(
                    category: "Videos",
                    usedGigabytes: bytesToGigabytes(videoBytes),
                    suggestedSavingsGigabytes: bytesToGigabytes(Int64(Double(videoBytes) * 0.2))
                )
            ]
        }.value
    }

    func scanCandidates(limit: Int = 50) async throws -> [CleanupCandidate] {
        try await Task.detached(priority: .utility) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            let assets = PHAsset.fetchAssets(with: options)
            let allAssets = allAssets(from: assets)

            var allCandidates: [CleanupCandidate] = []
            let minimumBytes = Int64(AppPreferences.minimumCandidateSizeMB * 1_024 * 1_024)

            for (index, asset) in allAssets.enumerated() {
                if index.isMultiple(of: 25) {
                    try Task.checkCancellation()
                    await Task.yield()
                }
                if asset.mediaType == .video && !AppPreferences.includeVideosInScan {
                    continue
                }
                guard let bytes = try await estimatedSizeBytes(for: asset), bytes >= minimumBytes else {
                    continue
                }

                allCandidates.append(
                    CleanupCandidate(
                        source: .photos,
                        displayName: asset.mediaType == .video ? "Video asset" : "Photo asset",
                        sizeBytes: bytes,
                        createdAt: asset.creationDate,
                        detailText: asset.mediaType == .video ? "Video from photo library" : "Photo from photo library",
                        photoAssetLocalIdentifier: asset.localIdentifier,
                        fileURL: nil
                    )
                )
            }

            return allCandidates
                .sorted { $0.sizeBytes > $1.sizeBytes }
                .prefix(limit)
                .map { $0 }
        }.value
    }

    private func totalBytes(for assets: PHFetchResult<PHAsset>) async throws -> Int64 {
        let collectedAssets = allAssets(from: assets)
        var total: Int64 = 0
        for (index, asset) in collectedAssets.enumerated() {
            if index.isMultiple(of: 25) {
                try Task.checkCancellation()
                await Task.yield()
            }
            total += (try await estimatedSizeBytes(for: asset)) ?? 0
        }
        return total
    }

    private func estimatedSizeBytes(for asset: PHAsset) async throws -> Int64? {
        try Task.checkCancellation()
        if let cached = await PhotoAssetSizeCache.shared.value(for: asset.localIdentifier) {
            return cached
        }

        let value: Int64?
        switch asset.mediaType {
        case .image:
            value = try await imageSizeBytes(for: asset)
        case .video:
            value = try await videoSizeBytes(for: asset)
        default:
            value = nil
        }

        if let value {
            await PhotoAssetSizeCache.shared.set(value, for: asset.localIdentifier)
        }
        return value
    }

    private func imageSizeBytes(for asset: PHAsset) async throws -> Int64? {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            var requestID: PHImageRequestID = PHInvalidImageRequestID
            requestID = PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: data.map { Int64($0.count) })
            }

            Task {
                if Task.isCancelled {
                    PHImageManager.default().cancelImageRequest(requestID)
                }
            }
        }
    }

    private func videoSizeBytes(for asset: PHAsset) async throws -> Int64? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        _ = options

        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            var totalBytes: Int64 = 0
            let requestOptions = PHAssetResourceRequestOptions()
            requestOptions.isNetworkAccessAllowed = true
            let timeoutSeconds: DispatchTimeInterval = .seconds(20)

            let requestID = PHAssetResourceManager.default().requestData(
                for: resource,
                options: requestOptions,
                dataReceivedHandler: { data in
                    totalBytes += Int64(data.count)
                },
                completionHandler: { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: totalBytes > 0 ? totalBytes : nil)
                    }
                }
            )

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeoutSeconds) {
                PHAssetResourceManager.default().cancelDataRequest(requestID)
            }

            Task {
                if Task.isCancelled {
                    PHAssetResourceManager.default().cancelDataRequest(requestID)
                }
            }
        }
    }

    private func allAssets(from fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func bytesToGigabytes(_ bytes: Int64) -> Double {
        Double(bytes) / 1_073_741_824.0
    }
}

actor PhotoAssetSizeCache {
    static let shared = PhotoAssetSizeCache()
    private var map: [String: Int64] = [:]

    func value(for key: String) -> Int64? {
        map[key]
    }

    func set(_ value: Int64, for key: String) {
        map[key] = value
    }
}
