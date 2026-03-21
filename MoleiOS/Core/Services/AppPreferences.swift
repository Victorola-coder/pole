import Foundation

enum AppPreferences {
    private static let defaults = UserDefaults.standard

    static var minimumCandidateSizeMB: Double {
        max(1, defaults.double(forKey: "settings.minimumCandidateSizeMB"))
    }

    static var includeVideosInScan: Bool {
        defaults.object(forKey: "settings.includeVideosInScan") as? Bool ?? true
    }
}
