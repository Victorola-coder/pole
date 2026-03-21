import SwiftUI

@main
struct PoleApp: App {
    @StateObject private var appState: AppState
    @StateObject private var dashboardViewModel: DashboardViewModel

    init() {
        let folderStore = ScopedFolderStore()
        _appState = StateObject(
            wrappedValue: AppState(folderStore: folderStore)
        )
        _dashboardViewModel = StateObject(
            wrappedValue: DashboardViewModel(
                scanner: CompositeStorageScanner(folderStore: folderStore),
                cleanupService: CleanupService(),
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

                SettingsView(appState: appState)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            .tint(appState.tintColor)
            .preferredColorScheme(appState.preferredColorScheme)
        }
    }
}
