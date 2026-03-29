import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var insights: [StorageInsight] = []
    @Published private(set) var candidates: [CleanupCandidate] = []
    @Published private(set) var isLoading = false
    @Published private(set) var scanProgress: Double = 0
    @Published private(set) var scanStatusText = "Idle"
    @Published private(set) var errorMessage: String?
    @Published private(set) var canScanPhotos = false
    /// Full security-scoped URLs — used as `ForEach` identity (last path alone can duplicate, e.g. two `Documents` folders).
    @Published private(set) var scopedFolders: [URL] = []
    @Published private(set) var protectedFolders: [URL] = []
    @Published private(set) var folderAnalysis: [FolderAnalysisNode] = []

    private let scanner: StorageScanning
    private let cleanupService: CleanupServicing
    private let permissionService: PermissionServicing
    private let scopedFolderStore: ScopedFolderStoring
    private var currentScanTask: Task<Void, Never>?
    /// Set when a scan fails mid-way so Retry can skip finished steps (see `ScanFailure`).
    private var pendingResumeSnapshot: ScanResumeSnapshot?
    @Published private(set) var canResumeInterruptedScan = false

    init(
        scanner: StorageScanning,
        cleanupService: CleanupServicing,
        permissionService: PermissionServicing,
        scopedFolderStore: ScopedFolderStoring
    ) {
        self.scanner = scanner
        self.cleanupService = cleanupService
        self.permissionService = permissionService
        self.scopedFolderStore = scopedFolderStore
        self.canScanPhotos = permissionService.canScanPhotos
        self.scopedFolders = scopedFolderStore.scopedFolders()
        self.protectedFolders = scopedFolderStore.protectedFolders()
    }

    var totalUsed: Double {
        insights.reduce(0) { $0 + $1.usedGigabytes }
    }

    var totalRecoverable: Double {
        insights.reduce(0) { $0 + $1.suggestedSavingsGigabytes }
    }

    func requestPhotoAccess() async {
        canScanPhotos = await permissionService.requestPhotoAccess()
    }

    func syncScopedFolders() {
        scopedFolders = scopedFolderStore.scopedFolders()
        protectedFolders = scopedFolderStore.protectedFolders()
    }

    /// - Parameter resumeFromFailure: When true (after a mid-scan error), continues from the last completed step instead of restarting at 0%.
    func load(resumeFromFailure: Bool = false) async {
        currentScanTask?.cancel()

        if !resumeFromFailure {
            pendingResumeSnapshot = nil
            canResumeInterruptedScan = false
        }

        let task = Task { @MainActor in
            isLoading = true
            if !resumeFromFailure {
                scanProgress = 0
            }
            scanStatusText = resumeFromFailure ? "Resuming scan…" : "Starting scan..."
            errorMessage = nil
            var didFail = false
            defer {
                isLoading = false
                if didFail {
                    scanProgress = 0
                    scanStatusText = "Scan failed"
                } else if scanStatusText == "Scan cancelled" {
                    scanProgress = 0
                } else {
                    scanProgress = 1
                    scanStatusText = "Completed"
                }
            }

            do {
                if let compositeScanner = scanner as? CompositeStorageScanner {
                    let resume = resumeFromFailure ? self.pendingResumeSnapshot : nil
                    let result = try await compositeScanner.scanAll(
                        { value, status in
                            await MainActor.run {
                                self.scanProgress = value
                                self.scanStatusText = status
                            }
                        },
                        resume: resume
                    )
                    insights = result.insights
                    candidates = result.candidates
                    folderAnalysis = result.folderAnalysis
                    pendingResumeSnapshot = nil
                    canResumeInterruptedScan = false
                } else {
                    scanStatusText = "Scanning storage categories (1/3)..."
                    insights = try await scanner.scan()
                    try Task.checkCancellation()
                    scanProgress = 0.34

                    scanStatusText = "Collecting cleanup candidates (2/3)..."
                    candidates = try await scanner.scanCandidates()
                    try Task.checkCancellation()
                    scanProgress = 0.67

                    scanStatusText = "Building folder analysis (3/3)..."
                    folderAnalysis = try await scanner.scanFolderAnalysis()
                }
            } catch let scanFail as ScanFailure {
                didFail = true
                pendingResumeSnapshot = scanFail.snapshot
                canResumeInterruptedScan = true
                errorMessage = humanReadableScanError(scanFail.underlying)
            } catch is CancellationError {
                scanStatusText = "Scan cancelled"
            } catch {
                didFail = true
                pendingResumeSnapshot = nil
                canResumeInterruptedScan = false
                errorMessage = humanReadableScanError(error)
            }
        }
        currentScanTask = task
        await task.value
    }

    func cancelScan() {
        scanStatusText = "Cancelling..."
        currentScanTask?.cancel()
    }

    private func humanReadableScanError(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription, !description.isEmpty {
            return description
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return "Network unavailable. For iCloud Photos, use Wi‑Fi or try again when online."
            case NSURLErrorTimedOut:
                return "The request timed out. Try again on a stable connection."
            default:
                break
            }
        }
        let text = ns.localizedDescription
        if !text.isEmpty, text != "(null)" {
            return text
        }
        return "Scan failed. Please try again."
    }

    func setError(_ message: String) {
        errorMessage = message
    }

    func clearError() {
        errorMessage = nil
        pendingResumeSnapshot = nil
        canResumeInterruptedScan = false
    }

    func importFolderFailed() {
        errorMessage = "Could not import folder. Please try again."
    }

    func refreshFromSettings() async {
        syncScopedFolders()
        await load()
    }

    func delete(candidate: CleanupCandidate, options: DeletionOptions) async {
        isLoading = true
        do {
            try await cleanupService.delete(candidate: candidate, options: options)
            await load()
            if options.dryRun {
                errorMessage = "Dry run completed. No data was deleted."
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Delete failed. Please try again."
        }
        isLoading = false
    }

    func addScopedFolder(url: URL) async {
        do {
            try scopedFolderStore.addFolder(url)
            syncScopedFolders()
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not add folder access."
        }
    }

    func addProtectedFolder(url: URL) async {
        do {
            try scopedFolderStore.addProtectedFolder(url)
            syncScopedFolders()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not add protected folder."
        }
    }

    func removeProtectedFolder(at url: URL) {
        scopedFolderStore.removeProtectedFolder(url)
        syncScopedFolders()
    }
}
