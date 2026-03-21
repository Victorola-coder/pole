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
    @Published private(set) var scopedFolderNames: [String] = []
    @Published private(set) var protectedFolderNames: [String] = []
    @Published private(set) var folderAnalysis: [FolderAnalysisNode] = []

    private let scanner: StorageScanning
    private let cleanupService: CleanupServicing
    private let permissionService: PermissionServicing
    private let scopedFolderStore: ScopedFolderStoring
    private var currentScanTask: Task<Void, Never>?

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
        self.scopedFolderNames = scopedFolderStore.scopedFolders().map(\.lastPathComponent)
        self.protectedFolderNames = scopedFolderStore.protectedFolders().map(\.lastPathComponent)
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
        scopedFolderNames = scopedFolderStore.scopedFolders().map(\.lastPathComponent)
        protectedFolderNames = scopedFolderStore.protectedFolders().map(\.lastPathComponent)
    }

    func load() async {
        currentScanTask?.cancel()

        let task = Task { @MainActor in
            isLoading = true
            scanProgress = 0
            scanStatusText = "Starting scan..."
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
                    let result = try await compositeScanner.scanAll { value, status in
                        await MainActor.run {
                            self.scanProgress = value
                            self.scanStatusText = status
                        }
                    }
                    insights = result.insights
                    candidates = result.candidates
                    folderAnalysis = result.folderAnalysis
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
            } catch is CancellationError {
                scanStatusText = "Scan cancelled"
            } catch {
                didFail = true
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
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        return "Scan failed. Please try again."
    }

    func setError(_ message: String) {
        errorMessage = message
    }

    func clearError() {
        errorMessage = nil
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

    func removeProtectedFolder(named folderName: String) {
        guard let url = scopedFolderStore.protectedFolders().first(where: { $0.lastPathComponent == folderName }) else {
            return
        }
        scopedFolderStore.removeProtectedFolder(url)
        syncScopedFolders()
    }
}
