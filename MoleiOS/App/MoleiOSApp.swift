import SwiftUI

@main
struct PoleApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var dashboardViewModel = DashboardViewModel(
        scanner: CompositeStorageScanner(),
        cleanupService: CleanupService(),
        permissionService: PermissionService()
    )

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView(viewModel: dashboardViewModel)
                    .tabItem {
                        Label("Dashboard", systemImage: "gauge.with.dots.needle")
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
            .tint(.green)
        }
    }
}
