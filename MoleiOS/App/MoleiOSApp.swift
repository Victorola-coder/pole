import SwiftUI

@main
struct PoleApp: App {
    @StateObject private var appState: AppState
    @StateObject private var dashboardViewModel: DashboardViewModel
    @State private var showLaunchOverlay = true
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
            ZStack {
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

                if showLaunchOverlay {
                    LaunchIconOverlay()
                        .transition(.opacity.combined(with: .scale(scale: 1.03)))
                        .zIndex(10)
                }
            }
            .tint(appState.tintColor)
            .preferredColorScheme(appState.preferredColorScheme)
            .fullScreenCover(isPresented: onboardingBinding) {
                OnboardingView(appState: appState) {}
            }
            .task {
                try? await Task.sleep(nanoseconds: 850_000_000)
                withAnimation(.easeOut(duration: 0.35)) {
                    showLaunchOverlay = false
                }
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

private struct LaunchIconOverlay: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.green, Color.teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 136, height: 136)

            Image(systemName: "shield.fill")
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))

            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 30, y: -24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .ignoresSafeArea()
    }
}
