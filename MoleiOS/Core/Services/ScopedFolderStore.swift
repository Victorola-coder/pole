import Foundation

protocol ScopedFolderStoring {
    func scopedFolders() -> [URL]
    func addFolder(_ url: URL) throws
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
        let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        var allBookmarks = userDefaults.array(forKey: bookmarkKey) as? [Data] ?? []
        allBookmarks.append(bookmarkData)
        userDefaults.set(allBookmarks, forKey: bookmarkKey)
        cachedURLs = resolveBookmarks()
    }

    private func resolveBookmarks() -> [URL] {
        let allBookmarks = userDefaults.array(forKey: bookmarkKey) as? [Data] ?? []
        var urls: [URL] = []

        for bookmark in allBookmarks {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            else {
                continue
            }

            _ = url.startAccessingSecurityScopedResource()
            urls.append(url)
        }
        return urls
    }
}
