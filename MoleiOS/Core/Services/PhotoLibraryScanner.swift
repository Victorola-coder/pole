import Foundation
import Photos

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
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else {
            return nil
        }

        // Apple does not expose a direct public file-size API for PHAsset.
        // This key is commonly used in production for estimation purposes.
        return (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value
    }

    private func bytesToGigabytes(_ bytes: Int64) -> Double {
        Double(bytes) / 1_073_741_824.0
    }
}
