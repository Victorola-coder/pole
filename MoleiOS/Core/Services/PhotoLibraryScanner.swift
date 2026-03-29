import Foundation
import Photos

struct PhotoLibraryScanner {
    /// Avoid measuring every asset on large libraries; insights are approximate GB totals.
    private static let maxInsightSampleCount = 160
    /// Hard cap on per-asset size lookups for candidate picking (then take top N by size).
    private static let maxCandidateAssetsToMeasure = 3_000

    /// `progress` receives `(0...1, status)` for the photo-insights sub-phase only (caller maps to global bar).
    func scanInsights(
        progress: (@Sendable (Double, String) async -> Void)? = nil
    ) async throws -> [StorageInsight] {
        await progress?(0, "Preparing photo library totals…")

        let imageAssets = PHAsset.fetchAssets(with: .image, options: nil)

        await progress?(0.15, "Measuring photos…")
        let imageBytes = try await sampledTotalBytes(for: imageAssets, progress: progress, progressRange: 0.15 ... 0.55)

        let videoBytes: Int64
        if AppPreferences.includeVideosInScan {
            await progress?(0.58, "Measuring videos…")
            let videoAssets = PHAsset.fetchAssets(with: .video, options: nil)
            videoBytes = try await sampledTotalBytes(for: videoAssets, progress: progress, progressRange: 0.58 ... 0.98)
        } else {
            videoBytes = 0
        }

        await progress?(1, "Photo insights ready")

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

    /// `progress` receives `(0...1, status)` for the photo-candidates sub-phase only.
    func scanCandidates(
        limit: Int = 50,
        progress: (@Sendable (Double, String) async -> Void)? = nil
    ) async throws -> [CleanupCandidate] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: options)
        let collected = allAssets(from: assets)
        let toMeasure = assetsSubsetForCandidateScan(collected)
        let total = max(toMeasure.count, 1)

        var allCandidates: [CleanupCandidate] = []
        let minimumBytes = Int64(AppPreferences.minimumCandidateSizeMB * 1_024 * 1_024)

        for (index, asset) in toMeasure.enumerated() {
            if index.isMultiple(of: 20) {
                try Task.checkCancellation()
                let fraction = Double(index) / Double(total)
                await progress?(fraction, "Sizing photos \(index + 1) / \(toMeasure.count)…")
            }
            if index.isMultiple(of: 40) {
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
    }

    private func assetsSubsetForCandidateScan(_ assets: [PHAsset]) -> [PHAsset] {
        guard assets.count > Self.maxCandidateAssetsToMeasure else {
            return assets
        }
        return Array(assets.shuffled().prefix(Self.maxCandidateAssetsToMeasure))
    }

    private func sampledTotalBytes(
        for fetchResult: PHFetchResult<PHAsset>,
        progress: (@Sendable (Double, String) async -> Void)?,
        progressRange: ClosedRange<Double>
    ) async throws -> Int64 {
        let collected = allAssets(from: fetchResult)
        let count = collected.count
        guard count > 0 else { return 0 }

        if count <= Self.maxInsightSampleCount {
            return try await sumBytesSequential(
                assets: collected,
                progress: progress,
                progressRange: progressRange
            )
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

        let sampleSum = try await sumBytesSequential(
            assets: sample,
            progress: progress,
            progressRange: progressRange
        )
        let avg = Double(sampleSum) / Double(sample.count)
        return Int64(avg * Double(count))
    }

    private func sumBytesSequential(
        assets: [PHAsset],
        progress: (@Sendable (Double, String) async -> Void)?,
        progressRange: ClosedRange<Double>
    ) async throws -> Int64 {
        var total: Int64 = 0
        let n = assets.count
        for (index, asset) in assets.enumerated() {
            if index.isMultiple(of: 12) {
                try Task.checkCancellation()
                let t = Double(index) / Double(max(n, 1))
                let mapped = progressRange.lowerBound + t * (progressRange.upperBound - progressRange.lowerBound)
                await progress?(mapped, "Measuring library items…")
            }
            if index.isMultiple(of: 25) {
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
        final class RequestState: @unchecked Sendable {
            /// `PHAssetResourceManager.requestData` request handle (SDK uses an integer ID).
            var requestID: Int32 = 0
            var finished = false
        }
        let state = RequestState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int64, Error>) in
                var totalBytes: Int64 = 0
                let requestOptions = PHAssetResourceRequestOptions()
                requestOptions.isNetworkAccessAllowed = true

                state.requestID = PHAssetResourceManager.default().requestData(
                    for: resource,
                    options: requestOptions,
                    dataReceivedHandler: { data in
                        totalBytes += Int64(data.count)
                    },
                    completionHandler: { error in
                        if state.finished { return }
                        state.finished = true
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: totalBytes)
                        }
                    }
                )
            }
        } onCancel: {
            PHAssetResourceManager.default().cancelDataRequest(state.requestID)
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
