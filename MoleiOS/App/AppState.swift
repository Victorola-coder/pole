import Foundation

final class AppState: ObservableObject {
    @Published var isOnboardingComplete = false
    @Published var shouldUseBiometricLock = false
}
