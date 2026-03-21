import SwiftUI

@main
struct PoleApp: App {
    @StateObject private var appState: AppState
    @StateObject private var dashboardViewModel: DashboardViewModel
    private let auditLogger: LocalDeletionAuditLogger

    init() {
        let folderStore = ScopedFolderStore()
        let auditLogger = LocalDeletionAuditLogger()
        self.auditLogger = auditLogger
        _appState = StateObject(
            wrappedValue: AppState(folderStore: folderStore)
        )
        _dashboardViewModel = StateObject(
            wrappedValue: DashboardViewModel(
                scanner: CompositeStorageScanner(folderStore: folderStore),
                cleanupService: CleanupService(folderStore: folderStore, auditLogger: auditLogger),
                permissionService: PermissionService(),
                scopedFolderStore: folderStore
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView(viewModel: dashboardViewModel, appState: appState)
                    .tabItem {
                        Label("Dashboard", systemImage: "rectangle.grid.1x2.fill")
                    }

                StorageBreakdownView(viewModel: dashboardViewModel)
                    .tabItem {
                        Label("Storage", systemImage: "internaldrive")
                    }

                SettingsView(appState: appState, auditLogger: auditLogger)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            .tint(appState.tintColor)
            .preferredColorScheme(appState.preferredColorScheme)
            .fullScreenCover(isPresented: onboardingBinding) {
                OnboardingView(appState: appState) {}
            }
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !appState.isOnboardingComplete },
            set: { newValue in
                appState.isOnboardingComplete = !newValue
            }
        )
    }
}
