import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var insights: [StorageInsight] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let scanner: StorageScanning

    init(scanner: StorageScanning) {
        self.scanner = scanner
    }

    var totalUsed: Double {
        insights.reduce(0) { $0 + $1.usedGigabytes }
    }

    var totalRecoverable: Double {
        insights.reduce(0) { $0 + $1.suggestedSavingsGigabytes }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            insights = try await scanner.scan()
        } catch {
            errorMessage = "Scan failed. Please try again."
        }
    }
}
