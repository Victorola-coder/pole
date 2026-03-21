import XCTest
@testable import Pole

final class CleanupCandidateTests: XCTestCase {
    func testSizeLabelContainsMBAndGB() {
        let candidate = CleanupCandidate(
            source: .files,
            displayName: "sample.bin",
            sizeBytes: 120 * 1_024 * 1_024,
            createdAt: nil,
            detailText: nil,
            photoAssetLocalIdentifier: nil,
            fileURL: nil
        )

        XCTAssertTrue(candidate.sizeLabel.contains("MB"))
        XCTAssertTrue(candidate.sizeLabel.contains("GB"))
        XCTAssertEqual(Int(candidate.sizeMegabytes.rounded()), 120)
    }
}
