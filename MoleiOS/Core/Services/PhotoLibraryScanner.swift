import Foundation
import Photos
import UIKit

struct PhotoLibraryScanner {
    func scanInsights() async -> [StorageInsight] {
        let imageAssets = PHAsset.fetchAssets(with: .image, options: nil)
        let videoAssets = PHAsset.fetchAssets(with: .video, options: nil)

        let imageBytes = totalBytes(for: imageAssets)
        let videoBytes = totalBytes(for: videoAssets)

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
    }

    func scanCandidates(limit: Int = 50) async -> [CleanupCandidate] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let assets = PHAsset.fetchAssets(with: options)

        var allCandidates: [CleanupCandidate] = []
        assets.enumerateObjects { asset, _, _ in
            guard let bytes = estimatedSizeBytes(for: asset), bytes > 20 * 1_024 * 1_024 else {
                return
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
    }

    private func totalBytes(for assets: PHFetchResult<PHAsset>) -> Int64 {
        var total: Int64 = 0
        assets.enumerateObjects { asset, _, _ in
            total += estimatedSizeBytes(for: asset) ?? 0
        }
        return total
    }

    private func estimatedSizeBytes(for asset: PHAsset) -> Int64? {
        switch asset.mediaType {
        case .image:
            return imageSizeBytes(for: asset)
        case .video:
            return videoSizeBytes(for: asset)
        default:
            return nil
        }
    }

    private func imageSizeBytes(for asset: PHAsset) -> Int64? {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        var byteCount: Int64?
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            if let data {
                byteCount = Int64(data.count)
            }
        }
        return byteCount
    }

    private func videoSizeBytes(for asset: PHAsset) -> Int64? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) else {
            return nil
        }

        var totalBytes: Int64 = 0
        let semaphore = DispatchSemaphore(value: 0)
        PHAssetResourceManager.default().requestData(
            for: resource,
            options: nil,
            dataReceivedHandler: { data in
                totalBytes += Int64(data.count)
            },
            completionHandler: { _ in
                semaphore.signal()
            }
        )
        semaphore.wait()

        return totalBytes > 0 ? totalBytes : nil
    }

    private func bytesToGigabytes(_ bytes: Int64) -> Double {
        Double(bytes) / 1_073_741_824.0
    }
}
