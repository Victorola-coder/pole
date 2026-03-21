import Foundation

protocol ScopedFolderStoring {
    func scopedFolders() -> [URL]
    func addFolder(_ url: URL) throws
    func clearFolders()
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
    private var cachedURLs: [URL] = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.cachedURLs = resolveBookmarks()
    }

    func scopedFolders() -> [URL] {
        cachedURLs
    }

    func addFolder(_ url: URL) throws {
        if cachedURLs.contains(where: { $0.standardizedFileURL.path == url.standardizedFileURL.path }) {
            throw ScopedFolderStoreError.duplicateFolder
        }

        let bookmarkData = try url.bookmarkData()
        var allBookmarks = userDefaults.array(forKey: bookmarkKey) as? [Data] ?? []
        allBookmarks.append(bookmarkData)
        userDefaults.set(allBookmarks, forKey: bookmarkKey)
        cachedURLs = resolveBookmarks()
    }

    func clearFolders() {
        for url in cachedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        userDefaults.removeObject(forKey: bookmarkKey)
        cachedURLs = []
    }

    private func resolveBookmarks() -> [URL] {
        let allBookmarks = userDefaults.array(forKey: bookmarkKey) as? [Data] ?? []
        var urls: [URL] = []
        var refreshedBookmarks: [Data] = []

        for bookmark in allBookmarks {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            else {
                continue
            }

            _ = url.startAccessingSecurityScopedResource()
            urls.append(url)

            if isStale {
                if let freshBookmark = try? url.bookmarkData() {
                    refreshedBookmarks.append(freshBookmark)
                }
            } else {
                refreshedBookmarks.append(bookmark)
            }
        }

        if refreshedBookmarks.count != allBookmarks.count || refreshedBookmarks != allBookmarks {
            userDefaults.set(refreshedBookmarks, forKey: bookmarkKey)
        }
        return urls
    }
}
