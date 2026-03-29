import Foundation

/// Logical scan steps (ordered). Used to skip finished work when retrying after `ScanFailure`.
enum ScanResumePhase: Int, Comparable, Equatable, Sendable {
    case photoLibraryInsights = 0
    case localFileInsights = 1
    case localFileCandidates = 2
    case photoLibraryCandidates = 3
    case folderStructureAnalysis = 4

    static func < (lhs: ScanResumePhase, rhs: ScanResumePhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Partial results plus the phase that failed (retry starts here).
struct ScanResumeSnapshot: Sendable {
    var insights: [StorageInsight]
    var candidates: [CleanupCandidate]
    var resumePhase: ScanResumePhase
}

/// Thrown from `CompositeStorageScanner.scanAll` so the UI can offer a resumable retry.
struct ScanFailure: Error {
    let snapshot: ScanResumeSnapshot
    let underlying: Error
}
