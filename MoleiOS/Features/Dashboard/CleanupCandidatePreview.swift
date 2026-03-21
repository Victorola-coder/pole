import Photos
import SwiftUI
import UIKit

struct CleanupCandidatePreview: View {
    let candidate: CleanupCandidate
    @State private var thumbnailImage: UIImage?

    var body: some View {
        Group {
            if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.15))
                    Image(systemName: candidate.sourceSymbolName)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: candidate.id) {
            await loadThumbnailIfNeeded()
        }
    }

    private func loadThumbnailIfNeeded() async {
        guard candidate.source == .photos,
              let localIdentifier = candidate.photoAssetLocalIdentifier
        else {
            return
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: 400, height: 400)
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                self.thumbnailImage = image
                continuation.resume()
            }
        }
    }
}
