import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var isOnboardingComplete: Bool {
        didSet { defaults.set(isOnboardingComplete, forKey: Keys.isOnboardingComplete) }
    }
    @Published var shouldUseBiometricLock: Bool {
        didSet { defaults.set(shouldUseBiometricLock, forKey: Keys.shouldUseBiometricLock) }
    }
    @Published var autoScanOnLaunch: Bool {
        didSet { defaults.set(autoScanOnLaunch, forKey: Keys.autoScanOnLaunch) }
    }
    @Published var minimumCandidateSizeMB: Double {
        didSet { defaults.set(minimumCandidateSizeMB, forKey: Keys.minimumCandidateSizeMB) }
    }
    @Published var includeVideosInScan: Bool {
        didSet { defaults.set(includeVideosInScan, forKey: Keys.includeVideosInScan) }
    }
    @Published var strictDeleteConfirmation: Bool {
        didSet { defaults.set(strictDeleteConfirmation, forKey: Keys.strictDeleteConfirmation) }
    }
    @Published var dryRunDeletionEnabled: Bool {
        didSet { defaults.set(dryRunDeletionEnabled, forKey: Keys.dryRunDeletionEnabled) }
    }
    @Published var appearance: AppearanceOption {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    @Published var accent: AccentOption {
        didSet { defaults.set(accent.rawValue, forKey: Keys.accent) }
    }

    private let defaults: UserDefaults
    private let folderStore: ScopedFolderStoring

    init(defaults: UserDefaults = .standard, folderStore: ScopedFolderStoring = ScopedFolderStore()) {
        self.defaults = defaults
        self.folderStore = folderStore

        self.isOnboardingComplete = defaults.bool(forKey: Keys.isOnboardingComplete)
        self.shouldUseBiometricLock = defaults.bool(forKey: Keys.shouldUseBiometricLock)
        self.autoScanOnLaunch = defaults.object(forKey: Keys.autoScanOnLaunch) as? Bool ?? true
        self.minimumCandidateSizeMB = max(1, defaults.double(forKey: Keys.minimumCandidateSizeMB))
        self.includeVideosInScan = defaults.object(forKey: Keys.includeVideosInScan) as? Bool ?? true
        self.strictDeleteConfirmation = defaults.object(forKey: Keys.strictDeleteConfirmation) as? Bool ?? false
        self.dryRunDeletionEnabled = defaults.object(forKey: Keys.dryRunDeletionEnabled) as? Bool ?? false
        self.appearance = AppearanceOption(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        self.accent = AccentOption(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .green
    }

    var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var tintColor: Color {
        switch accent {
        case .green: return .green
        case .blue: return .blue
        case .orange: return .orange
        case .purple: return .purple
        }
    }

    func clearSavedFolders() {
        folderStore.clearFolders()
    }
}

private enum Keys {
    static let isOnboardingComplete = "settings.isOnboardingComplete"
    static let shouldUseBiometricLock = "settings.shouldUseBiometricLock"
    static let autoScanOnLaunch = "settings.autoScanOnLaunch"
    static let minimumCandidateSizeMB = "settings.minimumCandidateSizeMB"
    static let includeVideosInScan = "settings.includeVideosInScan"
    static let strictDeleteConfirmation = "settings.strictDeleteConfirmation"
    static let dryRunDeletionEnabled = "settings.dryRunDeletionEnabled"
    static let appearance = "settings.appearance"
    static let accent = "settings.accent"
}

enum AppearanceOption: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum AccentOption: String, CaseIterable, Identifiable {
    case green
    case blue
    case orange
    case purple

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}
