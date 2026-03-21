import Foundation

protocol ScopedFolderStoring {
    func scopedFolders() -> [URL]
    func protectedFolders() -> [URL]
    func addFolder(_ url: URL) throws
    func addProtectedFolder(_ url: URL) throws
    func removeProtectedFolder(_ url: URL)
    func clearFolders()
    func clearProtectedFolders()
}

enum ScopedFolderStoreError: LocalizedError {
    case duplicateFolder

    var errorDescription: String? {
        switch self {
        case .duplicateFolder:
            return "That folder has already been added."
        }
    }
}

final class ScopedFolderStore: ScopedFolderStoring {
    private let userDefaults: UserDefaults
    private let bookmarkKey = "scoped_folder_bookmarks"
    private let protectedBookmarkKey = "protected_folder_bookmarks"
    private var cachedURLs: [URL] = []
    private var cachedProtectedURLs: [URL] = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.cachedURLs = resolveBookmarks(forKey: bookmarkKey)
        self.cachedProtectedURLs = resolveBookmarks(forKey: protectedBookmarkKey)
    }

    func scopedFolders() -> [URL] {
        cachedURLs
    }

    func protectedFolders() -> [URL] {
        cachedProtectedURLs
    }

    func addFolder(_ url: URL) throws {
        if containsURL(url, in: cachedURLs) {
            throw ScopedFolderStoreError.duplicateFolder
        }

        let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        var allBookmarks = userDefaults.array(forKey: bookmarkKey) as? [Data] ?? []
        allBookmarks.append(bookmarkData)
        userDefaults.set(allBookmarks, forKey: bookmarkKey)
        cachedURLs = resolveBookmarks(forKey: bookmarkKey)
    }

    func addProtectedFolder(_ url: URL) throws {
        if containsURL(url, in: cachedProtectedURLs) {
            throw ScopedFolderStoreError.duplicateFolder
        }

        let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        var allBookmarks = userDefaults.array(forKey: protectedBookmarkKey) as? [Data] ?? []
        allBookmarks.append(bookmarkData)
        userDefaults.set(allBookmarks, forKey: protectedBookmarkKey)
        cachedProtectedURLs = resolveBookmarks(forKey: protectedBookmarkKey)
    }

    func removeProtectedFolder(_ url: URL) {
        var allBookmarks = userDefaults.array(forKey: protectedBookmarkKey) as? [Data] ?? []
        allBookmarks.removeAll { bookmark in
            var isStale = false
            guard let resolved = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                return true
            }
            return containsURL(url, in: [resolved])
        }
        userDefaults.set(allBookmarks, forKey: protectedBookmarkKey)
        cachedProtectedURLs = resolveBookmarks(forKey: protectedBookmarkKey)
    }

    func clearFolders() {
        for url in cachedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        userDefaults.removeObject(forKey: bookmarkKey)
        cachedURLs = []
    }

    func clearProtectedFolders() {
        for url in cachedProtectedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        userDefaults.removeObject(forKey: protectedBookmarkKey)
        cachedProtectedURLs = []
    }

    private func resolveBookmarks(forKey key: String) -> [URL] {
        let allBookmarks = userDefaults.array(forKey: key) as? [Data] ?? []
        var urls: [URL] = []
        var refreshedBookmarks: [Data] = []

        for bookmark in allBookmarks {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            else {
                continue
            }

            _ = url.startAccessingSecurityScopedResource()
            urls.append(url)

            if isStale {
                if let freshBookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    refreshedBookmarks.append(freshBookmark)
                }
            } else {
                refreshedBookmarks.append(bookmark)
            }
        }

        if refreshedBookmarks.count != allBookmarks.count || refreshedBookmarks != allBookmarks {
            userDefaults.set(refreshedBookmarks, forKey: key)
        }
        return urls
    }

    private func containsURL(_ url: URL, in list: [URL]) -> Bool {
        list.contains(where: { $0.standardizedFileURL.path == url.standardizedFileURL.path })
    }
}
