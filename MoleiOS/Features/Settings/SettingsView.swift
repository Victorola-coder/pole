import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        NavigationStack {
            Form {
                Section("Security") {
                    Toggle("Use Face ID / Touch ID", isOn: $appState.shouldUseBiometricLock)
                }

                Section("Onboarding") {
                    Toggle("Completed", isOn: $appState.isOnboardingComplete)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
