import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var insights: [StorageInsight] = []
    @Published private(set) var candidates: [CleanupCandidate] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canScanPhotos = false
    @Published private(set) var scopedFolderNames: [String] = []

    private let scanner: StorageScanning
    private let cleanupService: CleanupServicing
    private let permissionService: PermissionServicing
    private let scopedFolderStore: ScopedFolderStoring

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

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            insights = try await scanner.scan()
            candidates = try await scanner.scanCandidates()
        } catch {
            errorMessage = "Scan failed. Please try again."
        }
    }

    func addScopedFolder(url: URL) async {
        do {
            try scopedFolderStore.addFolder(url)
            scopedFolderNames = scopedFolderStore.scopedFolders().map(\.lastPathComponent)
            await load()
        } catch {
            errorMessage = "Could not add folder access."
        }
    }

    func delete(candidate: CleanupCandidate) async {
        do {
            try await cleanupService.delete(candidate: candidate)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
