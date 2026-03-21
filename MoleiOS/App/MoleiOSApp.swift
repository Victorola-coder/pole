import SwiftUI

@main
struct MoleiOSApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView(viewModel: DashboardViewModel(scanner: MockStorageScanner()))
                    .tabItem {
                        Label("Dashboard", systemImage: "gauge.with.dots.needle")
                    }

                StorageBreakdownView()
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
