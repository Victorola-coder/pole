import Foundation
import Photos
import UIKit

struct PhotoLibraryScanner {
    /// Avoid measuring every asset on large libraries; insights are approximate GB totals.
    private static let maxInsightSampleCount = 160
    /// Hard cap on per-asset size lookups for candidate picking (then take top N by size).
    private static let maxCandidateAssetsToMeasure = 3_000

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

            let imageBytes = try await self.sampledTotalBytes(for: imageAssets)
            let videoBytes = try await self.sampledTotalBytes(for: videoAssets)

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
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let assets = PHAsset.fetchAssets(with: options)
            let collected = allAssets(from: assets)
            let toMeasure = self.assetsSubsetForCandidateScan(collected)

            var allCandidates: [CleanupCandidate] = []
            let minimumBytes = Int64(AppPreferences.minimumCandidateSizeMB * 1_024 * 1_024)

            for (index, asset) in toMeasure.enumerated() {
                if index.isMultiple(of: 40) {
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

    /// For very large libraries, measure a bounded random subset so candidate discovery stays responsive.
    private func assetsSubsetForCandidateScan(_ assets: [PHAsset]) -> [PHAsset] {
        guard assets.count > Self.maxCandidateAssetsToMeasure else {
            return assets
        }
        return Array(assets.shuffled().prefix(Self.maxCandidateAssetsToMeasure))
    }

    private func sampledTotalBytes(for fetchResult: PHFetchResult<PHAsset>) async throws -> Int64 {
        let collected = allAssets(from: fetchResult)
        let count = collected.count
        guard count > 0 else { return 0 }

        if count <= Self.maxInsightSampleCount {
            return try await sumBytesSequential(assets: collected)
        }

        var sample: [PHAsset] = []
        sample.reserveCapacity(Self.maxInsightSampleCount)
        var used = Set<Int>()
        while sample.count < Self.maxInsightSampleCount {
            let i = Int.random(in: 0..<count)
            if used.insert(i).inserted {
                sample.append(collected[i])
            }
        }

        let sampleSum = try await sumBytesSequential(assets: sample)
        let avg = Double(sampleSum) / Double(sample.count)
        return Int64(avg * Double(count))
    }

    private func sumBytesSequential(assets: [PHAsset]) async throws -> Int64 {
        var total: Int64 = 0
        for (index, asset) in assets.enumerated() {
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

        let value = try await byteSizeUsingAssetResources(for: asset)

        if let value {
            await PhotoAssetSizeCache.shared.set(value, for: asset.localIdentifier)
        }
        return value
    }

    /// Streams one primary resource’s byte length (avoids double-counting when an asset has several resources).
    private func byteSizeUsingAssetResources(for asset: PHAsset) async throws -> Int64? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else { return nil }

        let primary: PHAssetResource?
        switch asset.mediaType {
        case .image:
            primary = resources.first(where: { $0.type == .fullSizePhoto || $0.type == .photo })
        case .video:
            primary = resources.first(where: { $0.type == .fullSizeVideo || $0.type == .video })
        default:
            primary = nil
        }

        guard let resource = primary ?? resources.first else { return nil }
        let bytes = try await resourceStreamedByteCount(resource: resource)
        return bytes > 0 ? bytes : nil
    }

    private func resourceStreamedByteCount(resource: PHAssetResource) async throws -> Int64 {
        try await withCheckedThrowingContinuation { continuation in
            var totalBytes: Int64 = 0
            let requestOptions = PHAssetResourceRequestOptions()
            requestOptions.isNetworkAccessAllowed = true

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
                        continuation.resume(returning: totalBytes)
                    }
                }
            )

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
